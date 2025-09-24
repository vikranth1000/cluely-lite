import Cocoa
import ApplicationServices

struct AccessibilitySnapshotter {
    struct SnapshotNode {
        let id: String
        let role: String
        let title: String
        let enabled: Bool
        let frame: CGRect

        func toDictionary() -> [String: Any] {
            [
                "id": id,
                "role": role,
                "title": title,
                "enabled": enabled,
                "frame": [
                    "x": frame.origin.x,
                    "y": frame.origin.y,
                    "w": frame.width,
                    "h": frame.height
                ]
            ]
        }
    }

    enum SnapshotError: Error {
        case accessibilityDisabled
        case focusedAppUnavailable
        case windowUnavailable
    }

    private let allowedRoles: Set<String> = [
        kAXButtonRole as String,
        kAXStaticTextRole as String,
        kAXTextFieldRole as String,
        kAXCheckBoxRole as String,
        kAXMenuItemRole as String,
        "AXTab"
    ]
    private let frameAttribute: CFString = "AXFrame" as CFString

    func captureSnapshot(limit: Int = 120, maxDepth: Int = 3) throws -> [[String: Any]] {
        guard AXIsProcessTrustedWithOptions(nil) else {
            throw SnapshotError.accessibilityDisabled
        }

        let systemWide = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appRef) != .success {
            throw SnapshotError.focusedAppUnavailable
        }
        guard let appValue = appRef,
              CFGetTypeID(appValue) == AXUIElementGetTypeID() else {
            throw SnapshotError.focusedAppUnavailable
        }
        let app = unsafeBitCast(appValue, to: AXUIElement.self)

        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) != .success {
            throw SnapshotError.windowUnavailable
        }
        guard let windowValue = windowRef,
              CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
            throw SnapshotError.windowUnavailable
        }
        let window = unsafeBitCast(windowValue, to: AXUIElement.self)

        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var results: [[String: Any]] = []
        var visited = Set<CFHashCode>()

        while !queue.isEmpty, results.count < limit {
            let (element, depth) = queue.removeFirst()
            let elementHash = CFHash(element)
            if visited.contains(elementHash) { continue }
            visited.insert(elementHash)

            if depth > maxDepth { continue }

            let role = attributeValue(element, attribute: kAXRoleAttribute as CFString) as? String ?? ""
            let title = bestTitle(for: element)
            let enabledValue = attributeValue(element, attribute: kAXEnabledAttribute as CFString)
            let enabled = (enabledValue as? Bool) ?? (enabledValue as? NSNumber)?.boolValue ?? true
            let frame = elementFrame(element)

            if allowedRoles.contains(role) {
                let node = SnapshotNode(
                    id: String(elementHash),
                    role: role,
                    title: title,
                    enabled: enabled,
                    frame: frame ?? .zero
                )
                results.append(node.toDictionary())
            }

            if depth < maxDepth {
                if let children = copyChildren(of: element) {
                    queue.append(contentsOf: children.map { ($0, depth + 1) })
                }
            }
        }

        return results
    }

    private func attributeValue(_ element: AXUIElement, attribute: CFString) -> Any? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success else { return nil }
        return ref
    }

    private func bestTitle(for element: AXUIElement) -> String {
        let keys: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXLabelValueAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXHelpAttribute as CFString
        ]
        for key in keys {
            guard let value = attributeValue(element, attribute: key) else { continue }
            if let string = value as? String, !string.isEmpty {
                return string
            }
            if let number = value as? NSNumber {
                return number.stringValue
            }
        }
        return ""
    }

    private func elementFrame(_ element: AXUIElement) -> CGRect? {
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, frameAttribute, &ref)
        guard status == .success, let value = ref else { return nil }
        let axValue = value as! AXValue
        var frame = CGRect.zero
        if AXValueGetType(axValue) == .cgRect {
            AXValueGetValue(axValue, .cgRect, &frame)
            return frame
        }
        return nil
    }

    private func copyChildren(of element: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref)
        guard status == .success else { return nil }
        if let array = ref as? [AXUIElement] {
            return array
        }
        if let cfRef = ref, CFGetTypeID(cfRef) == CFArrayGetTypeID() {
            let cfArray = cfRef as! CFArray
            return (0..<CFArrayGetCount(cfArray)).compactMap { index in
                let value = CFArrayGetValueAtIndex(cfArray, index)
                return unsafeBitCast(value, to: AXUIElement.self)
            }
        }
        return nil
    }
}

extension AccessibilitySnapshotter.SnapshotError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accessibilityDisabled:
            return "Enable accessibility permissions for Cluely-Lite."
        case .focusedAppUnavailable:
            return "Unable to determine the active app."
        case .windowUnavailable:
            return "Unable to find the focused window."
        }
    }
}
