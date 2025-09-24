import Cocoa
import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func registerToggleAskHotkey() {
        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x434C4C59)), id: 1) // 'CLLY'
        let keyCode: UInt32 = UInt32(kVK_ANSI_Backslash)
        let modifiers: UInt32 = UInt32(cmdKey)    // ⌘

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            NSLog("Failed to register Command+\\ hotkey (status %d)", status)
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1 {
                NotificationCenter.default.post(name: .toggleAskBar, object: nil)
            }
            return noErr
        }, 1, &eventSpec, nil, &eventHandler)

        guard handlerStatus == noErr else {
            NSLog("Failed to install hotkey handler (status %d)", handlerStatus)
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
                self.hotKeyRef = nil
            }
            return
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
