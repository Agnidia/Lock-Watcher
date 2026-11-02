//
//  NSApplication+Settings.swift
//
//  Created on 29.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import SwiftUI

extension NSApplication {
    /// Displays the application settings or preferences window.
    ///
    /// Depending on the macOS version, it either opens the 'settings' or 'preferences' window.
    /// For macOS versions 13.0 and newer, it will attempt to open the 'settings' window,
    /// while for older versions, it will attempt to open the 'preferences' window.
    static func displaySettingsWindow() {
        // If the macOS version is 13.0 or newer, trigger the 'showSettingsWindow' selector,
        // otherwise, trigger the 'showPreferencesWindow' selector.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        
        // Activate the application, bringing it to the foreground.
        NSApp.activate(ignoringOtherApps: true)
    }
}
