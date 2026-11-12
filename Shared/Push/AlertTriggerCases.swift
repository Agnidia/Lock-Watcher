//
//  AlertTriggerCases.swift
//
//  Created on 13.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// What fired a capture. The raw value is the `trigger` field of the push payload, so the Mac and the companion must agree on it; each app adds its own names and symbols in an extension.
public enum AlertTrigger: String, CaseIterable, Sendable {
    case setup
    case onWakeUp
    case onWrongPassword
    case onBatteryPower
    case onACPower
    case usbConnected
    case logedIn
    case displayAttached
    case locationChanged
    case lockedInput
    case debug
}
