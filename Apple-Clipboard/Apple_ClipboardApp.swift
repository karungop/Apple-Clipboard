//
//  Apple_ClipboardApp.swift
//  Apple-Clipboard
//
//  Created by Karun Gopal on 10/19/25.
//

import SwiftUI

@main
struct Apple_ClipboardApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
           Settings {
               EmptyView() // No visible window
           }
    }
}
