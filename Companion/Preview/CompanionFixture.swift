//
//  CompanionFixture.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation
import SwiftUI
import UIKit

/// Preview and screenshot states, picked by the `LW_COMPANION_FIXTURE` launch variable (`detail.<trigger>[.bottom]` opens one trigger's detail).
enum CompanionFixture: Equatable {
    case ready
    case denied
    case pair
    case alerts
    /// Fifteen alerts on a free account: the list stops at three and offers the upgrade.
    case alertsMany
    /// The same fifteen alerts with Pro active.
    case pro
    /// One alert per trigger on a free account.
    case triggers
    /// One alert per trigger with Pro active.
    case proTriggers
    /// A free account on the Pro tab with three made-up plans, because the App Store is not reachable in screenshots.
    case proOffers
    /// Pro with one trigger's alert open and every detail field filled, scrolled to its end when `bottom` is set.
    case detail(AlertTrigger, bottom: Bool)
    /// Pro with the newest alert open and only the always-present fields, as a Mac with location, IP and trace turned off sends.
    case proDetailBare
    case photos
    case proPhotos
    case photoDetail
    case photosUnavailable
    
    init?(name: String) {
        let parts = name.split(separator: ".").map(String.init)
        if parts.first == "detail", parts.count >= 2, let trigger = AlertTrigger(rawValue: parts[1]) {
            self = .detail(trigger, bottom: parts.dropFirst(2).first == "bottom")
            return
        }
        switch name {
        case "ready": self = .ready
        case "denied": self = .denied
        case "pair": self = .pair
        case "alerts": self = .alerts
        case "alertsMany": self = .alertsMany
        case "pro": self = .pro
        case "triggers": self = .triggers
        case "proTriggers": self = .proTriggers
        case "proOffers": self = .proOffers
        case "proDetailBare": self = .proDetailBare
        case "photos": self = .photos
        case "proPhotos": self = .proPhotos
        case "photoDetail": self = .photoDetail
        case "photosUnavailable": self = .photosUnavailable
        default: return nil
        }
    }
    
    static func fromLaunchEnvironment() -> CompanionFixture? {
        ProcessInfo.processInfo.environment["LW_COMPANION_FIXTURE"].flatMap(CompanionFixture.init(name:))
    }
    
    var overrides: LaunchOverrides {
        var result = LaunchOverrides(alerts: [], photoSource: FixturePhotoSource(mode: .empty), isPro: false, plans: [],
                                     deviceToken: Data((0 ..< 32).map { UInt8($0 * 7 & 0xFF) }), isAuthorized: true, tab: .alerts)
        switch self {
        case .ready:
            break
        case .denied:
            result.deviceToken = nil
            result.isAuthorized = false
        case .pair:
            result.tab = .pair
        case .alerts:
            result.alerts = Array(PreviewAlerts.all().prefix(2))
        case .alertsMany:
            result.alerts = Self.manyWakeUps
        case .pro:
            result.alerts = Self.manyWakeUps
            result.isPro = true
        case .triggers:
            result.alerts = PreviewAlerts.all()
        case .proTriggers:
            result.alerts = PreviewAlerts.all()
            result.isPro = true
        case .proOffers:
            result.tab = .pro
            result.plans = Self.plans
        case .detail(let trigger, let bottom):
            result.alerts = PreviewAlerts.all()
            result.isPro = true
            result.photoSource = FixturePhotoSource(mode: .photos)
            result.openAlert = PreviewAlerts.alert(for: trigger)
            result.scrollsDetailToEnd = bottom
        case .proDetailBare:
            result.alerts = [PreviewAlerts.bare()]
            result.isPro = true
            result.openAlert = PreviewAlerts.bare()
        case .photos:
            result.tab = .photos
            result.photoSource = FixturePhotoSource(mode: .photos)
        case .proPhotos:
            result.tab = .photos
            result.isPro = true
            result.photoSource = FixturePhotoSource(mode: .photos)
        case .photoDetail:
            result.tab = .photos
            result.isPro = true
            result.photoSource = FixturePhotoSource(mode: .photos)
            result.openPhoto = FixturePhotoSource.photos().first
        case .photosUnavailable:
            result.tab = .photos
            result.photoSource = FixturePhotoSource(mode: .unavailable)
        }
        return result
    }
    
    private static var manyWakeUps: [ReceivedAlert] {
        (0 ..< 15).map { index in
            ReceivedAlert(id: "preview-\(index)", title: "Lock-Watcher", body: "\(String(localized: String.LocalizationValue(AlertTrigger.onWakeUp.titleKey))) · \(index + 1)",
                          trigger: AlertTrigger.onWakeUp.rawValue, date: PreviewAlerts.referenceDate.addingTimeInterval(-Double(index) * 3600),
                          latitude: nil, longitude: nil, ip: nil)
        }
    }
    
    private static let plans = [
        ProPlan(id: ProProduct.year, kind: .year, title: "Pro Yearly", price: "$7.99", monthlyEquivalent: "$0.67", savingsPercent: 33),
        ProPlan(id: ProProduct.month, kind: .month, title: "Pro Monthly", price: "$0.99", monthlyEquivalent: nil, savingsPercent: nil),
        ProPlan(id: ProProduct.lifetime, kind: .lifetime, title: "Pro Lifetime", price: "$20.99", monthlyEquivalent: nil, savingsPercent: nil)
    ]
}

/// Every `LW_COMPANION_*` launch variable. A preset from `LW_COMPANION_FIXTURE` is the base; each other variable changes one part of it.
enum LaunchVariable: String, CaseIterable {
    /// A preset name from `CompanionFixture`.
    case fixture = "LW_COMPANION_FIXTURE"
    /// `1` or `0`: Pro on or off.
    case pro = "LW_COMPANION_PRO"
    /// `alerts`, `photos`, `pair` or `pro`: the tab shown at launch.
    case tab = "LW_COMPANION_TAB"
    /// `all`, `none` or comma-separated trigger names: which alerts the inbox holds.
    case triggers = "LW_COMPANION_TRIGGERS"
    /// A number: how many alerts, repeating the chosen triggers when it exceeds them.
    case alertCount = "LW_COMPANION_ALERT_COUNT"
    /// A trigger name: open that alert's detail.
    case openAlert = "LW_COMPANION_OPEN_ALERT"
    /// `1`: scroll the opened detail to its last card.
    case scrollBottom = "LW_COMPANION_SCROLL_BOTTOM"
    /// `all`, `none`, `unavailable` or a number: the photo grid.
    case photos = "LW_COMPANION_PHOTOS"
    /// A photo index: open that photo.
    case openPhoto = "LW_COMPANION_OPEN_PHOTO"
    /// `ready` or `denied`: notification permission and the pairing QR code.
    case push = "LW_COMPANION_PUSH"
    /// `1`: show the three made-up Pro plans.
    case plans = "LW_COMPANION_PLANS"
    /// `1`: keep the live alerts and photos and only unlock Pro. Read by `CompanionContainer`, not layered.
    case forcePro = "LW_COMPANION_FORCE_PRO"
    /// `1`: preview data everywhere; in the companion it is Pro with one alert per trigger and the 11 persons, unless a preset is set.
    case preview = "LW_PREVIEW"
}

extension LaunchOverrides {
    private static var previewDefault: LaunchOverrides {
        var result = CompanionFixture.proTriggers.overrides
        result.photoSource = FixturePhotoSource(mode: .photos)
        return result
    }
    
    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> LaunchOverrides? {
        func value(_ variable: LaunchVariable) -> String? {
            environment[variable.rawValue].flatMap { $0.isEmpty ? nil : $0 }
        }
        let isPreview = PreviewMode.isEnabled(environment: environment)
        guard isPreview || LaunchVariable.allCases.contains(where: { $0 != .forcePro && $0 != .preview && value($0) != nil }) else { return nil }
        var result = value(.fixture).flatMap(CompanionFixture.init(name:))?.overrides ?? (isPreview ? previewDefault : CompanionFixture.ready.overrides)
        
        if let raw = value(.pro) {
            result.isPro = raw == "1"
        }
        if let raw = value(.tab) {
            result.tab = ["alerts": .alerts, "photos": .photos, "pair": .pair, "pro": .pro][raw] ?? result.tab
        }
        if value(.triggers) != nil || value(.alertCount) != nil {
            let raw = value(.triggers) ?? "all"
            let named = Set(raw.split(separator: ",").compactMap { AlertTrigger(rawValue: $0.trimmingCharacters(in: .whitespaces)) })
            result.alerts = raw == "none" ? [] : PreviewAlerts.list(triggers: named, count: value(.alertCount).flatMap(Int.init))
        }
        if let raw = value(.photos) {
            switch raw {
            case "none": result.photoSource = FixturePhotoSource(mode: .empty)
            case "unavailable": result.photoSource = FixturePhotoSource(mode: .unavailable)
            default: result.photoSource = FixturePhotoSource(mode: .photos, count: Int(raw) ?? PreviewPersons.count)
            }
        }
        if let raw = value(.openAlert), let trigger = AlertTrigger(rawValue: raw), let alert = PreviewAlerts.alert(for: trigger) {
            result.openAlert = alert
            if !result.alerts.contains(alert) {
                result.alerts.insert(alert, at: 0)
            }
            if (result.photoSource as? FixturePhotoSource)?.mode != .photos {
                result.photoSource = FixturePhotoSource(mode: .photos)
            }
        }
        if let raw = value(.openPhoto), let index = Int(raw), index >= 0 {
            let count = max(index + 1, (result.photoSource as? FixturePhotoSource)?.count ?? PreviewPersons.count)
            result.photoSource = FixturePhotoSource(mode: .photos, count: count)
            result.openPhoto = FixturePhotoSource.photos(count: count)[index]
            result.tab = .photos
        }
        if value(.scrollBottom) == "1" {
            result.scrollsDetailToEnd = true
        }
        if let raw = value(.push) {
            result.isAuthorized = raw != "denied"
            result.deviceToken = raw == "denied" ? nil : result.deviceToken
        }
        if value(.plans) == "1" {
            result.plans = CompanionFixture.proOffers.overrides.plans
        }
        return result
    }
}

private struct ScrollsDetailToEndKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by the `detail.<trigger>.bottom` fixture so a screenshot shows the lower cards.
    var scrollsDetailToEnd: Bool {
        get { self[ScrollsDetailToEndKey.self] }
        set { self[ScrollsDetailToEndKey.self] = newValue }
    }
}
#endif
