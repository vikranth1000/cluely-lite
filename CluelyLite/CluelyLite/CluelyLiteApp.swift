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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Cluely-Lite")
            button.action = #selector(toggleOverlay)
            button.target = self
        }

        overlayController = OverlayWindowController.shared

        hotkeyManager = HotkeyManager()
        hotkeyManager.registerToggleAskHotkey()

        EdgePeeker.shared.start { [weak self] in
            guard let self = self else { return }
            if self.overlayController.isHiddenFromUser == false && self.overlayController.isInteractive == false {
                self.overlayController.expandOverlay(requestingFocus: false, animated: true)
            }
        }

        NotificationCenter.default.addObserver(forName: .toggleAskBar, object: nil, queue: .main) { [weak self] _ in
            self?.overlayController.toggleVisibility()
        }
    }

    @objc func toggleOverlay() {
        overlayController.toggleVisibility()
    }
}

extension Notification.Name {
    static let toggleAskBar = Notification.Name("cluelylite.toggleAskBar")
}
