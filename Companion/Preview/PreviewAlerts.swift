//
//  PreviewAlerts.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation

/// Fixture photo names are `person-N.jpeg`, so an alert's `fileName` selects its person in the preview asset catalog.
enum PreviewPersons {
    static let count = 11
    
    static func fileName(_ index: Int) -> String {
        index < count ? "person-\(index).jpeg" : "person-\(index % count)-\(index).jpeg"
    }
    
    static func assetName(forFileName fileName: String) -> String? {
        guard fileName.hasPrefix("person-"), let index = Int(fileName.dropFirst("person-".count).prefix { $0.isNumber }), index < count else { return nil }
        return "Persons/person-\(index)"
    }
}

/// One made-up alert per trigger, so previews and screenshots can show every title, symbol and detail layout.
enum PreviewAlerts {
    static let referenceDate = Date(timeIntervalSince1970: 1_793_021_520)
    
    private struct Sample {
        let trigger: AlertTrigger
        let host: String
        let timeZoneID: String
        let place: (latitude: Double, longitude: Double)?
        let ip: String?
        let hops: Int
        let media: String?
    }
    
    private static let samples: [Sample] = [
        Sample(trigger: .usbConnected, host: "MacBook Pro", timeZoneID: "Europe/Kyiv", place: (50.4501, 30.5234), ip: "203.0.113.7", hops: 9, media: PushAlertPayload.photoMedia),
        Sample(trigger: .onWakeUp, host: "Office iMac", timeZoneID: "Europe/Berlin", place: (52.5200, 13.4050), ip: "198.51.100.23", hops: 6, media: PushAlertPayload.photoMedia),
        Sample(trigger: .locationChanged, host: "MacBook Air", timeZoneID: "America/New_York", place: (40.7128, -74.0060), ip: "192.0.2.88", hops: 11, media: PushAlertPayload.photoMedia),
        Sample(trigger: .lockedInput, host: "Mac mini", timeZoneID: "Asia/Tokyo", place: (35.6762, 139.6503), ip: "203.0.113.45", hops: 7, media: PushAlertPayload.videoMedia),
        Sample(trigger: .onWrongPassword, host: "MacBook Pro", timeZoneID: "Europe/London", place: (51.5074, -0.1278), ip: "198.51.100.9", hops: 8, media: PushAlertPayload.photoMedia),
        Sample(trigger: .logedIn, host: "Studio Mac", timeZoneID: "America/Los_Angeles", place: (34.0522, -118.2437), ip: "192.0.2.14", hops: 5, media: PushAlertPayload.photoMedia),
        Sample(trigger: .displayAttached, host: "Mac Studio", timeZoneID: "Australia/Sydney", place: (-33.8688, 151.2093), ip: "203.0.113.61", hops: 10, media: PushAlertPayload.videoMedia),
        Sample(trigger: .onBatteryPower, host: "MacBook Air", timeZoneID: "Europe/Paris", place: (48.8566, 2.3522), ip: "198.51.100.77", hops: 6, media: PushAlertPayload.photoMedia),
        Sample(trigger: .onACPower, host: "MacBook Pro", timeZoneID: "America/Chicago", place: (41.8781, -87.6298), ip: "192.0.2.201", hops: 4, media: PushAlertPayload.photoMedia),
        Sample(trigger: .setup, host: "MacBook Pro", timeZoneID: "Europe/Kyiv", place: nil, ip: nil, hops: 0, media: nil),
        Sample(trigger: .debug, host: "Dev Mac", timeZoneID: "UTC", place: nil, ip: "203.0.113.99", hops: 3, media: nil)
    ]
    
    /// Every `AlertTrigger`, newest first, each with its own person where the Mac would attach a capture.
    static func all(now: Date = referenceDate) -> [ReceivedAlert] {
        samples.enumerated().map { index, sample in
            alert(for: sample, index: index, now: now)
        }
    }
    
    /// The samples of `triggers` (all when empty), repeated with fresh identifiers until `count` alerts exist.
    static func list(triggers: Set<AlertTrigger> = [], count: Int? = nil, now: Date = referenceDate) -> [ReceivedAlert] {
        let pool = samples.enumerated().filter { triggers.isEmpty || triggers.contains($0.element.trigger) }
        guard !pool.isEmpty else { return [] }
        return (0 ..< (count ?? pool.count)).map { position in
            let base = alert(for: pool[position % pool.count].element, index: position, now: now)
            guard position >= pool.count else { return base }
            return ReceivedAlert(id: "\(base.id)-\(position)", title: base.title, body: base.body, trigger: base.trigger, date: base.date,
                                 latitude: base.latitude, longitude: base.longitude, ip: base.ip, traceRoute: base.traceRoute,
                                 fileName: base.fileName, mediaKind: base.mediaKind, host: base.host, timeZoneID: base.timeZoneID)
        }
    }
    
    static func alert(for trigger: AlertTrigger, now: Date = referenceDate) -> ReceivedAlert? {
        samples.enumerated().first { $0.element.trigger == trigger }.map { alert(for: $0.element, index: $0.offset, now: now) }
    }
    
    /// Only what a Mac with location, IP and trace turned off sends.
    static func bare(now: Date = referenceDate) -> ReceivedAlert {
        ReceivedAlert(id: "preview-bare", title: "Lock-Watcher", body: String(localized: String.LocalizationValue(AlertTrigger.onWakeUp.titleKey)), trigger: AlertTrigger.onWakeUp.rawValue,
                      date: now, latitude: nil, longitude: nil, ip: nil, host: "MacBook Pro")
    }
    
    private static func alert(for sample: Sample, index: Int, now: Date) -> ReceivedAlert {
        let date = now.addingTimeInterval(-Double(index) * 5400)
        let time = date.formatted(.dateTime.hour().minute())
        let name = String(localized: String.LocalizationValue(sample.trigger.titleKey))
        return ReceivedAlert(id: "preview-\(sample.trigger.rawValue)", title: "Lock-Watcher", body: "\(name) · \(time)", trigger: sample.trigger.rawValue,
                             date: date, latitude: sample.place?.latitude, longitude: sample.place?.longitude, ip: sample.ip,
                             traceRoute: sample.hops == 0 ? nil : (1 ... sample.hops).map { "\($0)  10.\(index).\($0).1  \($0 * 3) ms" }.joined(separator: "\n"),
                             fileName: sample.media == nil ? nil : PreviewPersons.fileName(index), mediaKind: sample.media,
                             host: sample.host, timeZoneID: sample.timeZoneID)
    }
}
#endif
