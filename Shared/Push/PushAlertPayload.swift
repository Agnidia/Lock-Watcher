//
//  PushAlertPayload.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

enum PushAlertPayloadError: Error, Sendable, Equatable {
    case tooLarge(Int)
}

/// The APNs body both apps share: the Mac encodes it, the companion decodes it.
///
/// It carries no snapshot bytes: the photo reaches the phone through iCloud and `file` names it. `lat`, `lon`, `ip` and `trace`
/// are omitted when the owner turned them off. Every key after `date` is optional, so any Mac and companion version pair interoperates.
struct PushAlertPayload: Codable, Sendable, Equatable {
    struct Alert: Codable, Sendable, Equatable {
        let title: String
        let body: String
    }

    struct APS: Codable, Sendable, Equatable {
        let alert: Alert
        let sound: String
        let interruptionLevel: String
        let threadID: String

        enum CodingKeys: String, CodingKey {
            case alert
            case sound
            case interruptionLevel = "interruption-level"
            case threadID = "thread-id"
        }
    }

    /// APNs rejects alert payloads above 4 KB.
    static let maxBytes = 4096
    static let title = "Lock-Watcher"
    static let threadID = "lockwatcher"
    static let maxBodyLength = 178
    /// The trace route is trimmed until the whole payload fits here, which leaves headroom under `maxBytes`.
    static let targetBytes = 3800
    static let maxTraceCharacters = 3000
    static let maxHostLength = 64
    static let maxFileLength = 128

    /// `media` values.
    static let photoMedia = "photo"
    static let videoMedia = "video"

    let aps: APS
    let trigger: String
    /// Unix seconds.
    let date: Int
    let lat: Double?
    let lon: Double?
    let ip: String?
    /// The trace route text, trimmed so the payload fits `targetBytes`.
    let trace: String?
    /// The captured file's name; the iCloud copy keeps it, so the companion finds the photo by it.
    let file: String?
    let media: String?
    /// The Mac's name.
    let host: String?
    /// The Mac's time zone identifier.
    let tz: String?

    init(trigger: String, body: String, date: Date, latitude: Double?, longitude: Double?, ip: String?,
         trace: String? = nil, file: String? = nil, media: String? = nil, host: String? = nil, timeZone: String? = nil)
    {
        let base = PushAlertPayload(aps: APS(alert: Alert(title: Self.title, body: String(body.prefix(Self.maxBodyLength))),
                                             sound: "default",
                                             interruptionLevel: "time-sensitive",
                                             threadID: Self.threadID),
                                    trigger: trigger,
                                    date: Int(date.timeIntervalSince1970),
                                    lat: latitude,
                                    lon: longitude,
                                    ip: ip,
                                    trace: nil,
                                    file: file.map { String($0.prefix(Self.maxFileLength)) },
                                    media: media,
                                    host: host.map { String($0.prefix(Self.maxHostLength)) },
                                    tz: timeZone)
        self = base.with(trace: Self.fittingTrace(trace, after: base))
    }

    private init(aps: APS, trigger: String, date: Int, lat: Double?, lon: Double?, ip: String?,
                 trace: String?, file: String?, media: String?, host: String?, tz: String?)
    {
        self.aps = aps
        self.trigger = trigger
        self.date = date
        self.lat = lat
        self.lon = lon
        self.ip = ip
        self.trace = trace
        self.file = file
        self.media = media
        self.host = host
        self.tz = tz
    }

    func encoded() throws -> Data {
        let data = try Self.makeEncoder().encode(self)
        guard data.count <= Self.maxBytes else { throw PushAlertPayloadError.tooLarge(data.count) }
        return data
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private func with(trace: String?) -> PushAlertPayload {
        PushAlertPayload(aps: aps, trigger: trigger, date: date, lat: lat, lon: lon, ip: ip, trace: trace, file: file, media: media, host: host, tz: tz)
    }

    /// Keeps the longest leading part of the trace that fits `targetBytes`. JSON escaping makes the encoded size differ from the
    /// text size, so the check measures the encoded payload and shrinks by a quarter until it fits.
    private static func fittingTrace(_ trace: String?, after base: PushAlertPayload) -> String? {
        guard let trace, !trace.isEmpty else { return nil }
        let encoder = makeEncoder()
        var candidate = trace.prefix(maxTraceCharacters)
        while !candidate.isEmpty {
            if let size = try? encoder.encode(base.with(trace: String(candidate))).count, size <= targetBytes {
                return String(candidate)
            }
            candidate = candidate.prefix(candidate.count - max(1, candidate.count / 4))
        }
        return nil
    }
}

// MARK: - Test Info

// @test-file: Tests/Notifiers/PushNotifierTest.swift
// @related-tests: CompanionTests/CompanionCoreTests.swift
