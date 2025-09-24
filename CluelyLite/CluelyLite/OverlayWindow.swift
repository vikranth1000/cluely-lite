import SwiftUI
import AppKit
import QuartzCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayWindowController: NSObject, NSWindowDelegate {
    static let shared = OverlayWindowController()

    private(set) var window: OverlayPanel!
    private var hosting: NSHostingView<OverlayView>!
    private let overlayController = OverlayController()
    private let responseController = ResponsePanelController()

    private let collapsedHeight: CGFloat = 40
    private let expandedHeight: CGFloat = 88
    private let minWidth: CGFloat = 280
    private let maxWidthPadding: CGFloat = 48

    private var manualOrigin: CGPoint?
    private var manualWidth: CGFloat?
    private var isExpanded = false
    private var resizeBaseWidth: CGFloat?

    private override init() {
        super.init()
        configureWindow()
        collapseOverlay(animated: false)
        window.orderFrontRegardless()
    }

    private func configureWindow() {
        let initialFrame = NSRect(x: 0, y: 0, width: 320, height: collapsedHeight)
        window = OverlayPanel(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.isFloatingPanel = true
        window.level = .statusBar
        window.delegate = self

        hosting = NSHostingView(rootView: OverlayView(controller: overlayController))
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        overlayController.requestCollapse = { [weak self] in
            self?.collapseOverlay(animated: true)
        }

        overlayController.requestExpand = { [weak self] focus in
            self?.expandOverlay(requestingFocus: focus, animated: true)
        }

        overlayController.adjustWidth = { [weak self] delta, finished in
            self?.adjustWidth(delta: delta, finished: finished)
        }

        overlayController.presentResponsePanel = { [weak self] text in
            self?.showResponsePanel(with: text)
        }

        overlayController.hideResponsePanel = { [weak self] in
            self?.hideResponsePanel()
        }

        responseController.onDismiss = { [weak self] in
            guard let self else { return }
            overlayController.responsePanelVisible = false
            if isExpanded {
                focusOverlay()
            }
        }
    }

    // MARK: - Expansion / Collapse

    func expandOverlay(requestingFocus: Bool, animated: Bool = true) {
        guard let screen = NSScreen.main else { return }

        let targetFrame = frame(for: expandedHeight, screen: screen)
        isExpanded = true
        overlayController.isExpanded = true
        updateWindowFrame(to: targetFrame, alpha: 0.97, animated: animated)

        if requestingFocus {
            focusOverlay()
        }

        responseController.updateAnchor(relativeTo: window.frame)
    }

    func collapseOverlay(animated: Bool = true) {
        guard let screen = NSScreen.main else { return }

        isExpanded = false
        overlayController.isExpanded = false
        overlayController.focusAsk = false
        window.makeFirstResponder(nil)
        hideResponsePanel()

        let targetFrame = frame(for: collapsedHeight, screen: screen)
        updateWindowFrame(to: targetFrame, alpha: 0.9, animated: animated)
    }

    func toggleInteractiveMode() {
        if isExpanded {
            collapseOverlay(animated: true)
        } else {
            expandOverlay(requestingFocus: true, animated: true)
        }
    }

    var isInteractive: Bool { isExpanded }

    // MARK: - Window delegate

    func windowDidMove(_ notification: Notification) {
        manualOrigin = window.frame.origin
        manualWidth = window.frame.width
        responseController.updateAnchor(relativeTo: window.frame)
    }

    // MARK: - Helpers

    private func focusOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        DispatchQueue.main.async { [weak self] in
            self?.overlayController.focusAsk = true
        }
    }

    private func updateWindowFrame(to frame: NSRect, alpha: CGFloat, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
                window.animator().alphaValue = alpha
            }
        } else {
            window.setFrame(frame, display: true)
            window.alphaValue = alpha
        }
        manualOrigin = window.frame.origin
        manualWidth = window.frame.width
        responseController.updateAnchor(relativeTo: window.frame)
    }

    private func frame(for height: CGFloat, screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = clampedWidth(for: visible)
        let origin = resolvedOrigin(for: height, width: width, visible: visible)
        return NSRect(x: origin.x, y: origin.y, width: width, height: height)
    }

    private func resolvedOrigin(for height: CGFloat, width: CGFloat, visible: NSRect) -> CGPoint {
        let margin: CGFloat = 12
        var origin = manualOrigin ?? CGPoint(
            x: visible.midX - width / 2,
            y: visible.maxY - height - 14
        )

        origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - width - margin)
        let maxY = visible.maxY - height - margin
        let minY = visible.minY + margin
        origin.y = min(max(origin.y, minY), maxY)
        return origin
    }

    private func clampedWidth(for visible: NSRect) -> CGFloat {
        let maxWidth = visible.width - maxWidthPadding
        let desired = manualWidth ?? window?.frame.width ?? 320
        return min(max(desired, minWidth), maxWidth)
    }

    private func adjustWidth(delta: CGFloat, finished: Bool) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        if resizeBaseWidth == nil { resizeBaseWidth = window.frame.width }
        guard let base = resizeBaseWidth else { return }

        let visible = screen.visibleFrame
        let maxWidth = visible.width - maxWidthPadding
        let proposed = min(max(base + delta, minWidth), maxWidth)

        var frame = window.frame
        frame.size.width = proposed
        updateWindowFrame(to: frameForResize(baseOrigin: frame.origin, size: frame.size, visible: visible), alpha: window.alphaValue, animated: false)

        if finished {
            manualWidth = proposed
            resizeBaseWidth = nil
        }
    }

    private func frameForResize(baseOrigin: CGPoint, size: CGSize, visible: NSRect) -> NSRect {
        let margin: CGFloat = 12
        var origin = baseOrigin
        if origin.x + size.width > visible.maxX - margin {
            origin.x = visible.maxX - size.width - margin
        }
        if origin.x < visible.minX + margin {
            origin.x = visible.minX + margin
        }
        return NSRect(origin: origin, size: size)
    }

    private func showResponsePanel(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            hideResponsePanel()
            return
        }
        overlayController.responsePanelVisible = true
        responseController.show(text: trimmed, anchorFrame: window.frame)
    }

    private func hideResponsePanel() {
        overlayController.responsePanelVisible = false
        responseController.hide()
    }
}

// MARK: - Edge monitor

final class EdgePeeker {
    static let shared = EdgePeeker()

    private var monitor: Any?
    private var onPeek: (() -> Void)?

    func start(onPeek: @escaping () -> Void) {
        stop()
        self.onPeek = onPeek
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let screen = NSScreen.main else { return }
            let location = NSEvent.mouseLocation
            if location.y >= screen.frame.maxY - 2 {
                self?.onPeek?()
            }
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onPeek = nil
    }

    deinit {
        stop()
    }
}

// MARK: - Response panel

private final class ResponsePanelController {
    private final class ResponsePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let panel: ResponsePanel
    private var hosting: NSHostingView<ResponseView>
    var onDismiss: (() -> Void)?

    init() {
        panel = ResponsePanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        hosting = NSHostingView(rootView: ResponseView(text: "", onClose: {}))
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    func show(text: String, anchorFrame: NSRect) {
        hosting.rootView = ResponseView(text: text) { [weak self] in
            guard let self else { return }
            hide()
            onDismiss?()
        }
        hosting.layoutSubtreeIfNeeded()

        var size = hosting.fittingSize
        size.width = min(max(size.width, 260), 460)
        size.height = min(max(size.height, 180), 420)
        panel.setContentSize(size)
        position(relativeTo: anchorFrame, size: size)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func updateAnchor(relativeTo anchorFrame: NSRect) {
        guard panel.isVisible else { return }
        position(relativeTo: anchorFrame, size: panel.frame.size)
    }

    private func position(relativeTo anchor: NSRect, size: NSSize) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16

        var x = anchor.midX - size.width / 2
        var y = anchor.minY - size.height - 12

        if x < visible.minX + margin {
            x = visible.minX + margin
        }
        if x + size.width > visible.maxX - margin {
            x = visible.maxX - size.width - margin
        }
        if y < visible.minY + margin {
            y = anchor.minY - size.height - 12
        }

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

private struct ResponseView: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Assistant")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(5)
                        .background(Color.black.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.trailing, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 18, y: 10)
        )
        .frame(maxWidth: 480)
    }
}
