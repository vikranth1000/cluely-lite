import AppKit
import SwiftUI

@main
struct CluelyLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() } // no settings window yet
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayController: OverlayWindowController!
    var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Cluely-Lite")
            button.action = #selector(toggleOverlay)
            button.target = self
        }

        // Overlay window
        overlayController = OverlayWindowController.shared
        overlayController.collapseOverlay(animated: false)

        // Global hotkey ⌘↩ to focus Ask
        hotkeyManager = HotkeyManager()
        hotkeyManager.registerToggleAskHotkey()

        // Reveal overlay when the mouse touches the top edge
        EdgePeeker.shared.start { [weak self] in
            self?.overlayController.expandOverlay(requestingFocus: false)
        }

        // When hotkey fires, bring up Ask
        NotificationCenter.default.addObserver(forName: .toggleAskBar, object: nil, queue: .main) { [weak self] _ in
            self?.overlayController.expandOverlay(requestingFocus: true)
        }
    }

    @objc func toggleOverlay() {
        overlayController.toggleInteractiveMode()
    }
}

extension Notification.Name {
    static let toggleAskBar = Notification.Name("cluelylite.toggleAskBar")
}
