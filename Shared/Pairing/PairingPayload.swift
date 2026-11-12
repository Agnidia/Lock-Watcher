//
//  PairingPayload.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Why a scanned string is not a usable pairing code.
enum PairingPayloadError: Error, Sendable, Equatable {
    case malformed
    case unsupportedVersion
    case invalidToken
    case invalidEnvironment
    case invalidTopic
}

/// The pairing QR contract the Mac and the companion share:
/// `lockwatcher://pair?v=1&token=<hex>&env=<sandbox|production>&topic=<bundle id>`.
///
/// Scanned text is untrusted, so parsing is strict and returns either a complete payload or a typed error, never a partial result.
/// The scheme is never registered as a URL handler.
struct PairingPayload: Sendable, Equatable {
    static let scheme = "lockwatcher"
    static let host = "pair"
    static let version = "1"
    static let maxLength = 512
    /// APNs tokens are 32 bytes today; Apple allows longer ones, so 32...100 bytes are accepted.
    static let tokenHexLength = 64 ... 200
    static let topicLength = 1 ... 155

    let token: String
    let environment: APNsEnvironment
    let topic: String

    /// Validates every field; the token is stored lowercased.
    init(token: String, environment: APNsEnvironment, topic: String) throws(PairingPayloadError) {
        let token = token.lowercased()
        guard Self.isValidToken(token) else { throw .invalidToken }
        guard Self.isValidTopic(topic) else { throw .invalidTopic }
        self.token = token
        self.environment = environment
        self.topic = topic
    }

    static func parse(_ text: String) throws(PairingPayloadError) -> PairingPayload {
        guard text.utf8.count <= maxLength,
              let components = URLComponents(string: text),
              components.scheme == scheme,
              components.host == host,
              components.path.isEmpty,
              components.user == nil, components.password == nil, components.port == nil, components.fragment == nil,
              let items = components.queryItems, items.count == 4
        else { throw .malformed }

        var values = [String: String]()
        for item in items {
            guard let value = item.value, values.updateValue(value, forKey: item.name) == nil else { throw .malformed }
        }
        guard Set(values.keys) == ["v", "token", "env", "topic"] else { throw .malformed }
        guard values["v"] == version else { throw .unsupportedVersion }
        guard let environment = values["env"].flatMap(APNsEnvironment.init(rawValue:)) else { throw .invalidEnvironment }
        return try PairingPayload(token: values["token"] ?? "", environment: environment, topic: values["topic"] ?? "")
    }

    var qrString: String {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "v", value: Self.version),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "env", value: environment.rawValue),
            URLQueryItem(name: "topic", value: topic)
        ]
        return components.string ?? ""
    }

    /// Lowercase hex of even length inside `tokenHexLength`.
    static func isValidToken(_ token: String) -> Bool {
        let bytes = token.utf8
        return tokenHexLength.contains(bytes.count) && bytes.count.isMultiple(of: 2)
            && bytes.allSatisfy { (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) || (UInt8(ascii: "a") ... UInt8(ascii: "f")).contains($0) }
    }

    /// Bundle-ID characters only: ASCII letters, numerals, dot and hyphen.
    static func isValidTopic(_ topic: String) -> Bool {
        let bytes = topic.utf8
        return topicLength.contains(bytes.count) && bytes.allSatisfy { byte in
            (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(byte) || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "-")
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/PairingPayloadTest.swift
// @related-tests: CompanionTests/CompanionCoreTests.swift
