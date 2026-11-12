//
//  PreviewMode.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
    import Foundation

    /// `LW_PREVIEW=1` in a Debug run swaps live data for preview data in the Mac app and the companion, so a screen can be inspected without real captures, iCloud or a paired device.
    enum PreviewMode {
        static let variable = "LW_PREVIEW"

        static var isEnabled: Bool {
            isEnabled(environment: ProcessInfo.processInfo.environment)
        }

        static func isEnabled(environment: [String: String]) -> Bool {
            guard let raw = environment[variable]?.lowercased() else { return false }
            return ["1", "true", "yes", "on"].contains(raw)
        }
    }
#endif
