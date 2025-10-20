//
//  AppDelegate.swift
//  Apple-Clipboard
//
//  Created by Karun Gopal on 10/20/25.
//

import AppKit
import SwiftUI


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardWatcher: ClipboardWatcher!
    var clipboardHistory: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📋"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "No copies yet", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher.onNewCopy = { [weak self] text in
            self?.addToHistory(text)
        }
        clipboardWatcher.startWatching()
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
        NSApp.terminate(nil)
    }
}

