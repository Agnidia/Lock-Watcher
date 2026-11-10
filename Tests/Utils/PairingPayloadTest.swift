//
//  PairingPayloadTest.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class PairingPayloadTest: XCTestCase {
    private let token = String(repeating: "a1", count: 32)
    private let topic = "com.igrsoft.Lock-Watcher"

    private func code(v: String = "1", token: String? = nil, env: String = "sandbox", topic: String? = nil) -> String {
        "lockwatcher://pair?v=\(v)&token=\(token ?? self.token)&env=\(env)&topic=\(topic ?? self.topic)"
    }

    func testRoundTripLowercasesToken() throws {
        for environment in APNsEnvironment.allCases {
            let payload = try PairingPayload(token: token.uppercased(), environment: environment, topic: topic)

            XCTAssertEqual(payload.token, token)
            XCTAssertEqual(payload.qrString, code(env: environment.rawValue))
            XCTAssertEqual(try PairingPayload.parse(payload.qrString), payload)
        }
    }

    func testRejectsHostileOrMalformedInput() {
        let cases: [(String, PairingPayloadError)] = [
            ("", .malformed),
            (code().replacingOccurrences(of: "lockwatcher://", with: "https://"), .malformed),
            (code().replacingOccurrences(of: "//pair?", with: "//other?"), .malformed),
            (code().replacingOccurrences(of: "//pair?", with: "//pair/extra?"), .malformed),
            (code().replacingOccurrences(of: "//pair?", with: "//user@pair?"), .malformed),
            (code() + "#fragment", .malformed),
            (code() + "&extra=1", .malformed),
            ("lockwatcher://pair?v=1&v=1&token=\(token)&env=sandbox", .malformed),
            (code(topic: String(repeating: "a", count: 600)), .malformed),
            (code(v: "2"), .unsupportedVersion),
            (code(token: ""), .invalidToken),
            (code(token: String(repeating: "zz", count: 32)), .invalidToken),
            (code(token: token + "a"), .invalidToken),
            (code(token: String(repeating: "ab", count: 31)), .invalidToken),
            (code(token: String(repeating: "ab", count: 101)), .invalidToken),
            (code(env: "staging"), .invalidEnvironment),
            (code(topic: ""), .invalidTopic),
            (code(topic: "com.evil%2Fpath"), .invalidTopic)
        ]

        for (text, expected) in cases {
            XCTAssertThrowsError(try PairingPayload.parse(text), text) { error in
                XCTAssertEqual(error as? PairingPayloadError, expected, text)
            }
        }
    }
}

// MARK: - Source Info

// @source-file: Shared/Pairing/PairingPayload.swift
