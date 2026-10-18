import AppKit
import ApplicationServices

/// Native Mission Control through the Dock's Accessibility tree.
///
/// Phase 4's test showed arrow keys don't move Mission Control's selection,
/// but its windows are AXButtons under the Dock's `#mc.windows` group, with
/// titles and frames, and pressing one brings that window forward. Mission
/// Control highlights the window under the pointer, so moving the pointer onto
/// a button gives its own selection look.
enum MissionControlUI {
    struct Window {
        let element: AXUIElement
        let title: String
        let frame: CGRect
    }

    private static let maxDepth = 7

    private static var dock: AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.5)
        return element
    }

    /// The `#mc` group exists only while Mission Control is open.
    static var isOpen: Bool {
        guard let dock else { return false }
        return children(of: dock).contains { identifier($0) == "mc" }
    }

    /// The Dock's top edge in AppKit screen coordinates (origin bottom-left).
    /// Mission Control shows the Dock even when it auto-hides, so the
    /// screen's visible frame doesn't account for it.
    static var dockTop: CGFloat? {
        guard let dock, let list = children(of: dock).first(where: { (value($0, kAXRoleAttribute) as String?) == kAXListRole }),
              let frame = frame(of: list), let primary = NSScreen.screens.first else { return nil }
        return primary.frame.maxY - frame.minY
    }

    /// Mission Control's windows in reading order: rows top to bottom, then left to right.
    static func windows() -> [Window] {
        guard let dock, let group = find("mc.windows", in: dock, depth: 0) else { return [] }
        let windows = children(of: group).compactMap { element -> Window? in
            guard let frame = frame(of: element), frame.width > 0 else { return nil }
            let title: String = value(element, kAXTitleAttribute) ?? ""
            return Window(element: element, title: title, frame: frame)
        }
        return readingOrder(windows)
    }

    /// Brings the window forward and closes Mission Control.
    @discardableResult
    static func press(_ window: Window) -> Bool {
        AXUIElementPerformAction(window.element, kAXPressAction as CFString) == .success
    }

    /// Logs the Dock's Mission Control subtree, for checking its shape after macOS updates.
    static func logTree() {
        guard let dock, let group = find("mc", in: dock, depth: 0) else {
            log("mission", "no Mission Control in the Dock's accessibility tree")
            return
        }
        var lines: [String] = []
        walk(group, depth: 0) { element, depth in
            lines.append(String(repeating: "  ", count: depth) + describe(element))
        }
        for line in lines { log("mission", line) }
    }

    // MARK: - Layout

    /// Groups windows whose vertical centres are close into rows.
    private static func readingOrder(_ windows: [Window]) -> [Window] {
        let byTop = windows.sorted { $0.frame.midY < $1.frame.midY }
        var rows: [[Window]] = []
        for window in byTop {
            if let last = rows.last?.first, abs(last.frame.midY - window.frame.midY) < min(last.frame.height, window.frame.height) / 2 {
                rows[rows.count - 1].append(window)
            } else {
                rows.append([window])
            }
        }
        return rows.flatMap { $0.sorted { $0.frame.midX < $1.frame.midX } }
    }

    // MARK: - Accessibility reads

    private static func find(_ id: String, in element: AXUIElement, depth: Int) -> AXUIElement? {
        if identifier(element) == id { return element }
        guard depth < maxDepth else { return nil }
        for child in children(of: element) {
            if let found = find(id, in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func walk(_ element: AXUIElement, depth: Int, visit: (AXUIElement, Int) -> Void) {
        visit(element, depth)
        guard depth < maxDepth else { return }
        for child in children(of: element) { walk(child, depth: depth + 1, visit: visit) }
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) ?? []
    }

    private static func identifier(_ element: AXUIElement) -> String? {
        value(element, kAXIdentifierAttribute)
    }

    /// Top-left-origin screen frame, the same space as CGEvent locations.
    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position: AXValue = value(element, kAXPositionAttribute),
              let size: AXValue = value(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    private static func describe(_ element: AXUIElement) -> String {
        let role: String = value(element, kAXRoleAttribute) ?? "?"
        var text = role
        if let id = identifier(element), !id.isEmpty { text += " #\(id)" }
        if let title: String = value(element, kAXTitleAttribute), !title.isEmpty { text += " \"\(title)\"" }
        if let frame = frame(of: element) { text += " \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))×\(Int(frame.height))" }
        return text
    }

    private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success, let raw else { return nil }
        if T.self == AXUIElement.self {
            guard CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
            return (raw as! AXUIElement) as? T
        }
        if T.self == AXValue.self {
            guard CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
            return (raw as! AXValue) as? T
        }
        return raw as? T
    }
}

/// Moves the pointer, posting a move event so hover tracking notices.
enum PointerControl {
    static var location: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    static func move(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
