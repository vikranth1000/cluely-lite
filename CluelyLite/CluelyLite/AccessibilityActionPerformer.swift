import Cocoa
import ApplicationServices

final class AccessibilityActionPerformer {
    enum ActionError: LocalizedError {
        case accessibilityDisabled
        case elementNotFound(String)
        case actionFailed(String)
        case confirmationRequired(String)
        case unsupportedAction(String)

        var errorDescription: String? {
            switch self {
            case .accessibilityDisabled:
                return "Accessibility permissions are required."
            case let .elementNotFound(label):
                return "Could not find an element matching \(label)."
            case let .actionFailed(reason):
                return "Action failed: \(reason)"
            case let .confirmationRequired(message):
                return message
            case let .unsupportedAction(action):
                return "Unsupported action: \(action)"
            }
        }
    }

    var dryRunEnabled: Bool = true
    private let destructiveKeywords: Set<String> = ["delete", "remove", "erase", "destroy", "discard", "quit", "close", "kill"]
    private let frameAttribute: CFString = "AXFrame" as CFString

    func perform(tool: AgentClient.Tool, confirm: Bool = false) throws {
        switch tool.action {
        case .answer:
            return
        case .click:
            guard let target = tool.target else {
                throw ActionError.elementNotFound("(missing target)")
            }
            try click(label: target, confirm: confirm)
        case .type:
            guard let target = tool.target else {
                throw ActionError.elementNotFound("(missing target)")
            }
            try type(text: tool.text ?? "", into: target, confirm: confirm)
        case .focus:
            guard let target = tool.target else { throw ActionError.elementNotFound("(missing target)") }
            try focus(label: target, confirm: confirm)
        }
    }

    func click(label: String, confirm: Bool = false) throws {
        let query = label.lowercased()
        let element = try locateElement(matching: query)
        let frame = fetchFrame(for: element)
        let isDestructive = containsDestructiveKeyword(label: query)
        handleDryRunHighlight(actionDescription: "Click \(label)", frame: frame)
        if isDestructive && !confirm {
            throw ActionError.confirmationRequired("Confirm before clicking \(label)")
        }

        if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            return
        }

        guard let fallbackFrame = frame else {
            throw ActionError.actionFailed("AXPress failed and no frame for fallback click")
        }

        try performCGClick(at: fallbackFrame)
    }

    func type(text: String, into label: String, confirm: Bool = false) throws {
        let query = label.lowercased()
        let element = try locateElement(matching: query, preferredRoles: [
            kAXTextFieldRole as String,
            "AXTextArea"
        ])
        let frame = fetchFrame(for: element)
        let isDestructive = containsDestructiveKeyword(label: query)
        handleDryRunHighlight(actionDescription: "Type into \(label)", frame: frame)
        if isDestructive && !confirm {
            throw ActionError.confirmationRequired("Confirm before typing into \(label)")
        }

        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef) != .success {
            throw ActionError.actionFailed("Unable to set value on \(label)")
        }
    }

    func focus(label: String, confirm: Bool = false) throws {
        let element = try locateElement(matching: label.lowercased())
        let frame = fetchFrame(for: element)
        handleDryRunHighlight(actionDescription: "Focus \(label)", frame: frame)
        if containsDestructiveKeyword(label: label.lowercased()) && !confirm {
            throw ActionError.confirmationRequired("Confirm before focusing \(label)")
        }
        if AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) != .success {
            throw ActionError.actionFailed("Unable to focus \(label)")
        }
    }

    private func locateElement(matching query: String, preferredRoles: [String]? = nil) throws -> AXUIElement {
        guard AXIsProcessTrustedWithOptions(nil) else {
            throw ActionError.accessibilityDisabled
        }

        let systemWide = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
              let appValue = appRef,
              CFGetTypeID(appValue) == AXUIElementGetTypeID() else {
            throw ActionError.elementNotFound(query)
        }
        let app = unsafeBitCast(appValue, to: AXUIElement.self)

        if let element = breadthFirstSearch(root: app, query: query, preferredRoles: preferredRoles) {
            return element
        }

        throw ActionError.elementNotFound(query)
    }

    private func breadthFirstSearch(root: AXUIElement, query: String, preferredRoles: [String]? = nil) -> AXUIElement? {
        var queue: [AXUIElement] = [root]
        var visited = Set<CFHashCode>()

        while !queue.isEmpty {
            let element = queue.removeFirst()
            let hash = CFHash(element)
            if visited.contains(hash) { continue }
            visited.insert(hash)

            let (matches, shouldContinue) = elementMatches(element, query: query, preferredRoles: preferredRoles)
            if matches { return element }
            if !shouldContinue { continue }

            if let children = copyChildren(of: element) {
                queue.append(contentsOf: children)
            }
        }
        return nil
    }

    private func elementMatches(_ element: AXUIElement, query: String, preferredRoles: [String]?) -> (Bool, Bool) {
        let role = attributeString(for: element, attribute: kAXRoleAttribute as CFString)
        let title = bestTitle(for: element).lowercased()
        let shouldContinue = role != nil

        if let preferred = preferredRoles, let role = role, preferred.contains(role) == false {
            return (false, shouldContinue)
        }

        if title.contains(query) || query.contains(title), !title.isEmpty {
            return (true, shouldContinue)
        }

        return (false, shouldContinue)
    }

    private func bestTitle(for element: AXUIElement) -> String {
        let attributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXLabelValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXHelpAttribute as CFString
        ]
        for key in attributes {
            guard let value = attributeValue(element, attribute: key) else { continue }
            if let string = value as? String, string.isEmpty == false {
                return string
            }
            if let number = value as? NSNumber {
                return number.stringValue
            }
        }
        return ""
    }

    private func attributeString(for element: AXUIElement, attribute: CFString) -> String? {
        attributeValue(element, attribute: attribute) as? String
    }

    private func copyChildren(of element: AXUIElement) -> [AXUIElement]? {
        guard let ref = attributeValue(element, attribute: kAXChildrenAttribute as CFString) else { return nil }
        if let array = ref as? [AXUIElement] {
            return array
        }
        if CFGetTypeID(ref as CFTypeRef) == CFArrayGetTypeID() {
            let cfArray = ref as! CFArray
            return (0..<CFArrayGetCount(cfArray)).compactMap { index in
                let value = CFArrayGetValueAtIndex(cfArray, index)
                return unsafeBitCast(value, to: AXUIElement.self)
            }
        }
        return nil
    }

    private func fetchFrame(for element: AXUIElement) -> CGRect? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, frameAttribute, &ref) == .success,
              let value = ref else { return nil }
        let axValue = value as! AXValue
        var frame = CGRect.zero
        if AXValueGetType(axValue) == .cgRect {
            AXValueGetValue(axValue, .cgRect, &frame)
            return frame
        }
        return nil
    }

    private func attributeValue(_ element: AXUIElement, attribute: CFString) -> Any? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success else { return nil }
        return ref
    }

    private func handleDryRunHighlight(actionDescription: String, frame: CGRect?) {
        guard dryRunEnabled else { return }
        HighlightWindow.show(frame: frame, message: actionDescription)
    }

    private func containsDestructiveKeyword(label: String) -> Bool {
        destructiveKeywords.contains { keyword in
            label.contains(keyword)
        }
    }

    private func performCGClick(at frame: CGRect) throws {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            throw ActionError.actionFailed("Unable to create mouse events")
        }
        move.post(tap: .cghidEventTap)
        usleep(10_000)
        down.post(tap: .cghidEventTap)
        usleep(10_000)
        up.post(tap: .cghidEventTap)
    }
}

private final class HighlightWindow: NSWindow {
    private static var activeWindow: HighlightWindow?

    static func show(frame: CGRect?, message: String) {
        DispatchQueue.main.async {
            activeWindow?.orderOut(nil)
            guard let frame = frame else { return }
            let window = HighlightWindow(contentRect: frame)
            window.makeKeyAndOrderFront(nil)
            activeWindow = window

            if let view = window.contentView as? HighlightView {
                view.message = message
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if activeWindow === window {
                    window.orderOut(nil)
                    activeWindow = nil
                }
            }
        }
    }

    private convenience init(contentRect: CGRect) {
        self.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.ignoresMouseEvents = true
        self.level = .statusBar
        self.hasShadow = false
        self.contentView = HighlightView(frame: NSRect(origin: .zero, size: contentRect.size))
    }
}

private final class HighlightView: NSView {
    var message: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        NSColor.systemYellow.withAlphaComponent(0.4).setFill()
        path.fill()

        NSColor.systemYellow.setStroke()
        path.lineWidth = 3
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: message, attributes: attrs)
        let size = attributed.size()
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.minY + 8,
            width: size.width,
            height: size.height
        )
        attributed.draw(in: rect)
    }
}
