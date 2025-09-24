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

    private let expandedHeight: CGFloat = 84
    private let collapsedHeight: CGFloat = 40
    private let collapsedWidth: CGFloat = 320
    private let minimumHorizontalPadding: CGFloat = 40
    private let expandedPreferredWidth: CGFloat = 760
    private let expandedHorizontalMargin: CGFloat = 160

    private var isExpanded = false
    private var positionRatio: CGFloat?

    private override init() {
        super.init()
        configureWindow()
        collapseOverlay(animated: false)
        window.orderFrontRegardless()
    }

    private func configureWindow() {
        guard let screen = NSScreen.main else { return }
        window = OverlayPanel(
            contentRect: collapsedFrame(for: screen),
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
        overlayController.presentResponsePanel = { [weak self] text in
            self?.showResponsePanel(with: text)
        }
        overlayController.hideResponsePanel = { [weak self] in
            self?.hideResponsePanel()
        }

        responseController.onDismiss = { [weak self] in
            guard let self else { return }
            if self.overlayController.responsePanelVisible {
                self.overlayController.responsePanelVisible = false
                self.remainFocusedIfNeeded()
            }
        }
    }

    func expandOverlay(requestingFocus: Bool, animated: Bool = true) {
        guard let screen = NSScreen.main else { return }

        if !isExpanded {
            isExpanded = true
            overlayController.isExpanded = true
        }

        let targetFrame = expandedFrame(for: screen)
        updateWindowFrame(to: targetFrame, alpha: 0.98, animated: animated)
        window.orderFrontRegardless()

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

        let targetFrame = collapsedFrame(for: screen)
        updateWindowFrame(to: targetFrame, alpha: 0.88, animated: animated)
        window.orderFrontRegardless()
    }

    func toggleInteractiveMode() {
        if isExpanded {
            collapseOverlay(animated: true)
        } else {
            expandOverlay(requestingFocus: true, animated: true)
        }
    }

    var isInteractive: Bool { isExpanded }

    func windowDidMove(_ notification: Notification) {
        guard let screen = window.screen else { return }
        let visible = screen.visibleFrame
        positionRatio = (window.frame.midX - visible.minX) / visible.width
        responseController.updateAnchor(relativeTo: window.frame)
    }

    private func focusOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        DispatchQueue.main.async {
            self.overlayController.focusAsk = true
        }
    }

    private func remainFocusedIfNeeded() {
        guard isExpanded else { return }
        focusOverlay()
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
        responseController.updateAnchor(relativeTo: frame)
    }

    private func collapsedFrame(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = min(max(collapsedWidth, visible.width - minimumHorizontalPadding), visible.width - 24)
        let x = resolvedXPosition(for: width, visible: visible)
        let y = visible.maxY - collapsedHeight - 10
        return NSRect(x: x, y: y, width: width, height: collapsedHeight)
    }

    private func expandedFrame(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let maxWidth = visible.width - minimumHorizontalPadding
        let preferred = min(expandedPreferredWidth, maxWidth)
        let width = max(collapsedWidth, min(preferred, visible.width - expandedHorizontalMargin))
        let x = resolvedXPosition(for: width, visible: visible)
        let y = visible.maxY - expandedHeight - 14
        return NSRect(x: x, y: y, width: width, height: expandedHeight)
    }

    private func resolvedXPosition(for width: CGFloat, visible: NSRect) -> CGFloat {
        let margin: CGFloat = 12
        let defaultX = visible.midX - width / 2
        guard let ratio = positionRatio else {
            return clamp(defaultX, lower: visible.minX + margin, upper: visible.maxX - width - margin)
        }
        let midX = visible.minX + ratio * visible.width
        let proposed = midX - width / 2
        return clamp(proposed, lower: visible.minX + margin, upper: visible.maxX - width - margin)
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        return min(max(value, lower), upper)
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

// Reveal overlay when mouse touches the very top of the screen
final class EdgePeeker {
    static let shared = EdgePeeker()
    private var monitor: Any?
    private var onPeek: (() -> Void)?

    func start(onPeek: @escaping () -> Void) {
        stop()
        self.onPeek = onPeek
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let screen = NSScreen.main else { return }
            let loc = NSEvent.mouseLocation
            if loc.y >= screen.frame.maxY - 2 {
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

    deinit { stop() }
}

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
        size.height = min(max(size.height, 160), 360)
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
        var x = anchor.midX - size.width / 2
        var y = anchor.minY - size.height - 12
        let margin: CGFloat = 12
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assistant")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                }
                .buttonStyle(.plain)
                .background(Color.black.opacity(0.25), in: Circle())
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
        .frame(maxWidth: 440)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 18, y: 10)
        )
    }
}
//
//  OverlayWindow.swift
//  CluelyLite
//
//  Created by Vikranth Reddimasu on 9/23/25.
//
