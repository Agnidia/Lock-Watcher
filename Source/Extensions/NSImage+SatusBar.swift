//
//  NSImage+SatusBar.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit

extension NSImage {
    /// Provides an appropriate icon for the status bar based on the triggered status.
    ///
    /// This method returns one of two possible icons based on the triggered status:
    /// - If triggered, it will return an alert icon.
    /// - Otherwise, it will return a default menu icon.
    ///
    /// - Parameter triggered: A Boolean flag indicating if the status bar icon should be in the alert state. Default is `false`.
    ///
    /// - Returns: An `NSImage` instance representing the appropriate icon for the status bar. Returns `nil` if the named image resource is not found.
    static func statusBarIcon(triggered: Bool = false) -> NSImage? {
        if triggered {
            NSImage(named: "MenuIconAlert")
        } else {
            NSImage(named: "MenuIcon")
        }
    }
}
