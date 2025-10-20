//
//  AppDelegate.swift
//  Apple-Clipboard
//
//  Created by Karun Gopal on 10/20/25.
//

import AppKit
import SwiftUI
import Carbon


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardWatcher: ClipboardWatcher!
    var clipboardHistory: [String] = []
    
    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandlerRef: EventHandlerRef? = nil


    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📋"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "No copies yet", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(GetApplicationEventTarget(),
                                                    hotKeyHandler,
                                                    1,
                                                    &eventType,
                                                    userData,
                                                    &eventHandlerRef)
        if installStatus != noErr {
            print("Failed to install event handler: \(installStatus)")
        }
        
        let vKeyCode: UInt32 = UInt32(kVK_ANSI_V)
        let modifiers: UInt32 = UInt32(cmdKey) | UInt32(shiftKey)
        var hotKeyID = EventHotKeyID(signature: OSType(0), id: UInt32(1))
        
        let registerStatus = RegisterEventHotKey(vKeyCode,
                                                     modifiers,
                                                     hotKeyID,
                                                     GetApplicationEventTarget(),
                                                     0,
                                                     &hotKeyRef)
        
        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
        } else {
            print("Hotkey registered: ⌘ + Shift + V")
        }

        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher.onNewCopy = { [weak self] text in
            self?.addToHistory(text)
        }
        clipboardWatcher.startWatching()
    }
    
    func handleHotkeyPressed() {
        print("Hotkey pressed")
//        showClipboard()
    }
    
    private let hotKeyHandler: EventHandlerUPP = { (nextHandlerPointer, eventRefPointer, userDataPointer) -> OSStatus in
        guard let event = eventRefPointer else { return noErr }
        
        var hotKeyID = EventHotKeyID()
            let size = UInt32(MemoryLayout<EventHotKeyID>.size)

            // Get the EventHotKeyID from the event's direct object parameter
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           Int(size),
                                           nil,
                                           &hotKeyID)
            if status != noErr {
                return status
            }

            // hotKeyID.id will be the id we used when registering (1)
            if hotKeyID.id == 1 {
                if let userData = userDataPointer {
                    // Recover the AppDelegate instance
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    // Call instance method on the main thread
                    DispatchQueue.main.async {
                        delegate.handleHotkeyPressed()
                    }
                }
            }

            return noErr
        }
    

    private func addToHistory(_ text: String) {
        if let existingIndex = clipboardHistory.firstIndex(of: text) {
            clipboardHistory.remove(at: existingIndex)
        }
            
        clipboardHistory.insert(text, at: 0)
        clipboardHistory = Array(clipboardHistory.prefix(10))
        updateMenu()
    }

    private func updateMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        if clipboardHistory.isEmpty {
            menu.addItem(NSMenuItem(title: "No copies yet", action: nil, keyEquivalent: ""))
        } else {
            for item in clipboardHistory {
                let menuItem = NSMenuItem(title: item, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Clear All", action: #selector(clearAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }

    @objc private func copyToClipboard(_ sender: NSMenuItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sender.title, forType: .string)
    }

    @objc private func clearAll() {
        clipboardHistory.removeAll()
        updateMenu()
    }

    @objc private func quitApp() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        print("Unregistered custome hotkey")
        NSApp.terminate(nil)
    }
}

