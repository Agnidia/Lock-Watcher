//
//  AlertTrigger.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The cases are shared with the Mac in `Shared/Push/AlertTriggerCases.swift`; a value from a newer Mac is not listed and falls back to the alert text.
extension AlertTrigger {
    static let fallbackSymbol = "bell"

    /// The string-catalog key of the localized name.
    var titleKey: String {
        "AlertTrigger_\(rawValue)"
    }

    var symbol: String {
        switch self {
        case .setup: "gearshape"
        case .onWakeUp: "sun.max"
        case .onWrongPassword: "lock.trianglebadge.exclamationmark"
        case .onBatteryPower: "battery.50"
        case .onACPower: "powerplug"
        case .usbConnected: "cable.connector"
        case .logedIn: "person.crop.circle.badge.checkmark"
        case .displayAttached: "display"
        case .locationChanged: "location"
        case .lockedInput: "keyboard"
        case .debug: "ladybug"
        }
    }

    init?(alert: ReceivedAlert) {
        guard let raw = alert.trigger, let known = AlertTrigger(rawValue: raw) else { return nil }
        self = known
    }
}

enum AlertFormat {
    /// Four decimals is about eleven metres, the precision the list already showed.
    static func coordinates(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    /// An Apple Maps link that opens on any device, including ones without the Maps app handler for a bare coordinate.
    static func mapsURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: String(format: "https://maps.apple.com/?ll=%.6f,%.6f", latitude, longitude))
    }

    /// The event time on the Mac's clock, or nil when the Mac's zone is unknown or already equals the phone's at that moment.
    static func macLocalTime(of alert: ReceivedAlert, phoneZone: TimeZone = .current) -> String? {
        guard let identifier = alert.timeZoneID, let zone = TimeZone(identifier: identifier),
              zone.secondsFromGMT(for: alert.date) != phoneZone.secondsFromGMT(for: alert.date)
        else { return nil }
        return alert.date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, timeZone: zone).timeZone(.specificName(.short)))
    }

    /// A plain-text summary for the share sheet; the optional lines appear only when the alert carries them.
    static func shareText(for alert: ReceivedAlert) -> String {
        var lines = [alert.body]
        if let host = alert.host {
            lines.append(host)
        }
        lines.append(alert.date.formatted(date: .long, time: .standard))
        if let latitude = alert.latitude, let longitude = alert.longitude {
            lines.append(String(localized: "ShareLocation") + ": " + coordinates(latitude: latitude, longitude: longitude))
            if let url = mapsURL(latitude: latitude, longitude: longitude) {
                lines.append(url.absoluteString)
            }
        }
        if let ip = alert.ip {
            lines.append("IP: " + ip)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
