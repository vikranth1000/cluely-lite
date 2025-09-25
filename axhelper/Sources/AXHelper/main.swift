import Foundation
import Cocoa
import ApplicationServices

// Minimal reuse of the snapshotter/performer logic

struct SnapshotNode: Codable {
    let id: String
    let role: String
    let title: String
    let enabled: Bool
    let frame: Rect
    struct Rect: Codable { let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat }
}

enum SnapError: Error { case notTrusted, noFocusedApp, noWindow }

func isTrusted() -> Bool { AXIsProcessTrustedWithOptions(nil) }

func focusedWindow() throws -> AXUIElement {
    let systemWide = AXUIElementCreateSystemWide()
    var appRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
          let appValue = appRef, CFGetTypeID(appValue) == AXUIElementGetTypeID() else { throw SnapError.noFocusedApp }
    let app = unsafeBitCast(appValue, to: AXUIElement.self)
    var winRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
          let winValue = winRef, CFGetTypeID(winValue) == AXUIElementGetTypeID() else { throw SnapError.noWindow }
    return unsafeBitCast(winValue, to: AXUIElement.self)
}

func axValue<T>(_ element: AXUIElement, _ attr: CFString, as type: AXValueType, into value: inout T) -> Bool {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr, &ref) == .success, let any = ref else { return false }
    // Ensure the returned CFType is an AXValue before bridging
    guard CFGetTypeID(any) == AXValueGetTypeID() else { return false }
    let val = unsafeBitCast(any, to: AXValue.self)
    return AXValueGetType(val) == type && AXValueGetValue(val, type, &value)
}

func stringAttr(_ element: AXUIElement, _ attr: CFString) -> String? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr, &ref) == .success else { return nil }
    return ref as? String
}

func anyAttr(_ element: AXUIElement, _ attr: CFString) -> Any? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr, &ref) == .success else { return nil }
    return ref
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref) == .success else { return [] }
    if let arr = ref as? [AXUIElement] { return arr }
    if let cf = ref, CFGetTypeID(cf) == CFArrayGetTypeID() {
        let arr = cf as! CFArray
        return (0..<CFArrayGetCount(arr)).compactMap { i in
            let v = CFArrayGetValueAtIndex(arr, i)
            return unsafeBitCast(v, to: AXUIElement.self)
        }
    }
    return []
}

func bestTitle(_ e: AXUIElement) -> String {
    for key in [kAXTitleAttribute, kAXLabelValueAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] as [CFString] {
        if let v = anyAttr(e, key) as? String, !v.isEmpty { return v }
        if let n = anyAttr(e, key) as? NSNumber { return n.stringValue }
    }
    return ""
}

func elementFrame(_ e: AXUIElement) -> CGRect {
    var rect = CGRect.zero
    _ = axValue(e, "AXFrame" as CFString, as: .cgRect, into: &rect)
    return rect
}

func snapshot(limit: Int = 120, maxDepth: Int = 3) throws -> [SnapshotNode] {
    guard isTrusted() else { throw SnapError.notTrusted }
    let root = try focusedWindow()
    var q: [(AXUIElement, Int)] = [(root, 0)]
    var seen = Set<CFHashCode>()
    var out: [SnapshotNode] = []
    let allowed: Set<String> = [kAXButtonRole as String, kAXStaticTextRole as String, kAXTextFieldRole as String, kAXCheckBoxRole as String, kAXMenuItemRole as String, "AXTab"]
    while !q.isEmpty && out.count < limit {
        let (e, d) = q.removeFirst()
        let h = CFHash(e)
        if seen.contains(h) { continue }
        seen.insert(h)
        if d > maxDepth { continue }
        let role = stringAttr(e, kAXRoleAttribute as CFString) ?? ""
        let title = bestTitle(e)
        let enabledAny = anyAttr(e, kAXEnabledAttribute as CFString)
        let enabled = (enabledAny as? Bool) ?? (enabledAny as? NSNumber)?.boolValue ?? true
        let f = elementFrame(e)
        if allowed.contains(role) {
            out.append(.init(id: String(h), role: role, title: title, enabled: enabled, frame: .init(x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height)))
        }
        if d < maxDepth { q.append(contentsOf: children(e).map { ($0, d+1) }) }
    }
    return out
}

enum ActionError: Error { case notTrusted, notFound, failed }

func locate(_ label: String, preferRoles: [String]? = nil) throws -> AXUIElement {
    guard isTrusted() else { throw ActionError.notTrusted }
    let systemWide = AXUIElementCreateSystemWide()
    var appRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
          let appValue = appRef, CFGetTypeID(appValue) == AXUIElementGetTypeID() else { throw ActionError.notFound }
    let app = unsafeBitCast(appValue, to: AXUIElement.self)
    var q: [AXUIElement] = [app]
    var seen = Set<CFHashCode>()
    let query = label.lowercased()
    while !q.isEmpty {
        let e = q.removeFirst()
        let h = CFHash(e)
        if seen.contains(h) { continue }
        seen.insert(h)
        let role = stringAttr(e, kAXRoleAttribute as CFString)
        if let prefs = preferRoles, let r = role, !prefs.contains(r) {
            // skip
        } else {
            let title = bestTitle(e).lowercased()
            if !title.isEmpty && (title.contains(query) || query.contains(title)) { return e }
        }
        q.append(contentsOf: children(e))
    }
    throw ActionError.notFound
}

func click(_ label: String) throws {
    let e = try locate(label)
    if AXUIElementPerformAction(e, kAXPressAction as CFString) == .success { return }
    throw ActionError.failed
}

func focus(_ label: String) throws {
    let e = try locate(label)
    if AXUIElementSetAttributeValue(e, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success { return }
    throw ActionError.failed
}

func type(_ text: String, into label: String) throws {
    let e = try locate(label, preferRoles: [kAXTextFieldRole as String, "AXTextArea"])
    _ = AXUIElementSetAttributeValue(e, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    if AXUIElementSetAttributeValue(e, kAXValueAttribute as CFString, text as CFTypeRef) == .success { return }
    throw ActionError.failed
}

func printJSON<T: Encodable>(_ value: T) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? enc.encode(value) { FileHandle.standardOutput.write(data) }
}

func main() {
    let args = CommandLine.arguments.dropFirst().map { $0 }
    guard let cmd = args.first else {
        fputs("Usage: axhelper <snapshot|click|type|focus> [...]\n", stderr)
        exit(2)
    }
    do {
        switch cmd {
        case "snapshot":
            let snap = try snapshot()
            printJSON(snap)
        case "click":
            guard args.count >= 2 else { throw ActionError.notFound }
            try click(args[1])
        case "focus":
            guard args.count >= 2 else { throw ActionError.notFound }
            try focus(args[1])
        case "type":
            guard args.count >= 3 else { throw ActionError.failed }
            try type(args[1], into: args[2])
        default:
            fputs("Unknown command\n", stderr)
            exit(2)
        }
    } catch {
        fputs("\(error)\n", stderr)
        exit(1)
    }
}

main()
