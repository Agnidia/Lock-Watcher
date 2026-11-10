//
//  PushAlertPayload.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

enum PushAlertPayloadError: Error, Sendable, Equatable {
    case tooLarge(Int)
}

/// The APNs body both apps share: the Mac encodes it, the companion decodes it.
///
/// It carries no snapshot and no trace route; `lat`, `lon` and `ip` are omitted when the owner turned them off.
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

    let aps: APS
    let trigger: String
    /// Unix seconds.
    let date: Int
    let lat: Double?
    let lon: Double?
    let ip: String?

    init(trigger: String, body: String, date: Date, latitude: Double?, longitude: Double?, ip: String?) {
        aps = APS(alert: Alert(title: Self.title, body: String(body.prefix(Self.maxBodyLength))),
                  sound: "default",
                  interruptionLevel: "time-sensitive",
                  threadID: Self.threadID)
        self.trigger = trigger
        self.date = Int(date.timeIntervalSince1970)
        lat = latitude
        lon = longitude
        self.ip = ip
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard data.count <= Self.maxBytes else { throw PushAlertPayloadError.tooLarge(data.count) }
        return data
    }
}

// MARK: - Test Info

// @test-file: Tests/Notifiers/PushNotifierTest.swift
// @related-tests: CompanionTests/CompanionCoreTests.swift
