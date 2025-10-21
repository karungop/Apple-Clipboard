//
//  AppDelegate.swift
//  Apple-Clipboard
//
//  Created by Karun Gopal on 10/20/25.
//

import AppKit
import SwiftUI
import Carbon
import ApplicationServices

class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class HoverButton: NSButton {
    private var defaultColor: NSColor = .clear
    private var hoverColor: NSColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.2)
    
    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: bounds,
                                          options: [.mouseEnteredAndExited, .activeAlways],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverColor.cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = defaultColor.cgColor
    }
    
    override func awakeFromNib() {
        wantsLayer = true
        layer?.backgroundColor = defaultColor.cgColor
        layer?.cornerRadius = 4
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardWatcher: ClipboardWatcher!
    var clipboardHistory: [String] = []
    var clickMonitor: Any?
    
    var popupWindow: NSPanel?
    var prevApp: NSRunningApplication?
    
    var constantClips: [String] = ["A", "B", "C"]
    
    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandlerRef: EventHandlerRef? = nil


    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📋"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit Constant Clips…", action: #selector(editConstantClips), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "No copies yet", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        
        clipboardHistory = UserDefaults.standard.stringArray(forKey: "clipboardHistory") ?? []
        constantClips = UserDefaults.standard.stringArray(forKey: "constantClips") ?? ["", "", ""]
        updateMenu()
        
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
        
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
//            print("Got Permission")
        }
        
        showPopup()
        
        
    }
    
    func showPopup() {
        let prevApp = NSWorkspace.shared.frontmostApplication
        self.prevApp = prevApp
        // Close if already open
        if let window = popupWindow {
            window.close()
            popupWindow = nil
            return
        }
        let panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true                // keeps it above normal windows
        panel.level = .statusBar                    // appears above all normal app windows
        panel.hasShadow = true
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97)
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient] // transient and floating
        panel.becomesKeyOnlyIfNeeded = true
//        panel.wantsLayer = true
//        panel.layer?.cornerRadius = 10
//        panel.hasShadow = true
        
        let scrollView = NSScrollView(frame: panel.contentView!.bounds)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        
        for (index, item) in constantClips.enumerated() {
            let button = HoverButton(title: "★ \(item)", target: self, action: #selector(pasteConstantClip(_:)))
            button.tag = index
            button.font = NSFont.systemFont(ofSize: 13)
            button.bezelStyle = .inline
            button.isBordered = false
            button.setButtonType(.momentaryChange)
            button.alignment = .left
            button.toolTip = item
            button.contentTintColor = NSColor.labelColor
            textStack.addArrangedSubview(button)
        }
        
        let separator = NSBox()
        separator.boxType = .separator
        textStack.addArrangedSubview(separator)
        
        for (index, item) in clipboardHistory.enumerated() {
            let button = HoverButton(title: "\(item)", target: self, action: #selector(pasteClipboardItem(_:)))
            button.tag = index
            button.font = NSFont.systemFont(ofSize: 13)
            button.bezelStyle = .inline
            button.isBordered = false
            button.setButtonType(.momentaryChange)
            button.alignment = .left
            button.toolTip = item
            button.contentTintColor = NSColor.labelColor
            
            textStack.addArrangedSubview(button)
        }
        
        
        
        let footerButton = HoverButton(title: "Clear All", target: self, action: #selector(clearAll))
        footerButton.bezelStyle = .inline
        footerButton.isBordered = false
        footerButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        textStack.addArrangedSubview(footerButton)
        
        
        scrollView.documentView = textStack
        
        if let contentView = scrollView.contentView.superview {
            NSLayoutConstraint.activate([
                textStack.topAnchor.constraint(equalTo: contentView.topAnchor),
                textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        
        
        panel.contentView = scrollView
        
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let popupHeight: CGFloat = 300
        let popupWidth: CGFloat = 250
        let yPos = min(mouseLocation.y, screenFrame.height - popupHeight)
        let popupRect = NSRect(x: mouseLocation.x - popupWidth/2,
                               y: yPos - popupHeight - 10,
                               width: popupWidth,
                               height: popupHeight)

        panel.setFrame(popupRect, display: true)
        
        popupWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)            // brings it to the front
        
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let window = self?.popupWindow {
                window.close()
                self?.popupWindow = nil
                if let prevApp = prevApp {
                    prevApp.activate(options: [])
                }
            }
            if let monitor = self?.clickMonitor {
                NSEvent.removeMonitor(monitor)
                self?.clickMonitor = nil
                if let prevApp = prevApp {
                    prevApp.activate(options: [])
                }
            }
        }

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
        
        UserDefaults.standard.set(clipboardHistory, forKey: "clipboardHistory")
        
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
        UserDefaults.standard.set(clipboardHistory, forKey: "clipboardHistory")
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
    
    @objc private func pasteClipboardItem(_ sender: NSButton) {
        let index = sender.tag
        guard index < clipboardHistory.count else { return }
        let text = clipboardHistory[index]
        print("Clicked item \(index): \(text)") // TEST LOG
        
        // Copy selected text to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Accessibility enabled: \(AXIsProcessTrusted())")
        // Close popup and bring previous app forward
        popupWindow?.close()
        popupWindow = nil
        if let prevApp = prevApp {
            prevApp.activate(options: [])        }

        print("Switched back to previous app")
        
        // Simulate Command + V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            
            let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
            
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
            
            print("Simulated ⌘V paste event")
        }
    }
    
    @objc private func pasteConstantClip(_ sender: NSButton) {
//        let index = sender.tag
//        guard index < constantClips.count else { return }
//        let text = constantClips[index]
//        guard !text.isEmpty else { return }
//        
//        // Copy to system clipboard
//        let pasteboard = NSPasteboard.general
//        pasteboard.clearContents()
//        pasteboard.setString(text, forType: .string)
//        
//        // Close popup and switch back to previous app
//        popupWindow?.close()
//        popupWindow = nil
//        prevApp?.activate(options: [])
//        
//        // Optional: simulate ⌘V after delay if you want
//        simulatePaste()
        let index = sender.tag
        guard index < constantClips.count else { return }
        let text = constantClips[index]
        print("Clicked item \(index): \(text)") // TEST LOG
        
        // Copy selected text to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Accessibility enabled: \(AXIsProcessTrusted())")
        // Close popup and bring previous app forward
        popupWindow?.close()
        popupWindow = nil
        if let prevApp = prevApp {
            prevApp.activate(options: [])        }

        print("Switched back to previous app")
        
        // Simulate Command + V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            
            let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
            
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
            
            print("Simulated ⌘V paste event")
        }
    }
    
    @objc private func editConstantClips() {
        for i in 0..<constantClips.count {
            let alert = NSAlert()
            alert.messageText = "Set Constant Clip \(i+1)"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = constantClips[i]
            alert.accessoryView = input
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                constantClips[i] = input.stringValue
            }
        }
        UserDefaults.standard.set(constantClips, forKey: "constantClips")
    }

}

