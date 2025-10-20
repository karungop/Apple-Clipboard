//
//  ClipboardWatcher.swift
//  Apple-Clipboard
//
//  Created by Karun Gopal on 10/20/25.
//
import AppKit
//import MASShortcut

class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    var onNewCopy: ((String) -> Void)?
    
    init() {
        self.changeCount = pasteboard.changeCount
    }
    
    func startWatching() {
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(checkForChanges), userInfo: nil, repeats: true)
    }
    
    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func checkForChanges() {
        if pasteboard.changeCount != changeCount {
            changeCount = pasteboard.changeCount
            if let copiedText = pasteboard.string(forType: .string) {
                onNewCopy?(copiedText)
            }
        }
    }
}

