import Cocoa
import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func registerToggleAskHotkey() {
        var hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x434C4C59)), id: 1) // 'CLLY'
        let keyCode: UInt32 = UInt32(kVK_Return) // Return key
        let modifiers: UInt32 = UInt32(cmdKey)    // ⌘

        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registerStatus == noErr else {
            NSLog("Failed to register Command+Return hotkey (status %d)", registerStatus)
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
            if let hotKeyRef = hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
                self.hotKeyRef = nil
            }
            return
        }
    }

    deinit {
        if let hotKeyRef = hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }
}
//
//  HotkeyManager.swift
//  CluelyLite
//
//  Created by Vikranth Reddimasu on 9/23/25.
//
