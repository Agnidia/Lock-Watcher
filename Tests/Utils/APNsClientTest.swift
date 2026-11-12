//
//  APNsClientTest.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import XCTest
@testable import Lock_Watcher

final class APNsClientTest: XCTestCase {
    private let device = PairedDevice(token: String(repeating: "0a", count: 32), environment: .sandbox, topic: StubAPNsCredentialsProvider.topic, pairedAt: Date())
    private var key: P256.Signing.PrivateKey!
    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        key = P256.Signing.PrivateKey()
        clock = TestClock()
    }

    private func makeSUT(transport: MockAPNsTransport = MockAPNsTransport()) -> APNsClient {
        let clock = clock!
        return APNsClient(credentials: StubAPNsCredentialsProvider(privateKey: key), transport: transport, now: { clock.now })
    }

    private func decodeSegment(_ segment: String) throws -> Data {
        var base64 = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while !base64.count.isMultiple(of: 4) {
            base64 += "="
        }
        return try XCTUnwrap(Data(base64Encoded: base64))
    }

    func testTokenHasES256HeaderClaimsAndRawSignature() async throws {
        let token = try await makeSUT().providerToken(for: .sandbox)
        let parts = token.split(separator: ".").map(String.init)

        XCTAssertEqual(parts.count, 3)
        let header = try JSONSerialization.jsonObject(with: decodeSegment(parts[0])) as? [String: String]
        XCTAssertEqual(header, ["alg": "ES256", "kid": StubAPNsCredentialsProvider.keyID])
        let claims = try XCTUnwrap(JSONSerialization.jsonObject(with: decodeSegment(parts[1])) as? [String: Any])
        XCTAssertEqual(claims["iss"] as? String, StubAPNsCredentialsProvider.teamID)
        XCTAssertEqual(claims["iat"] as? Int, Int(clock.now.timeIntervalSince1970))
        let signatureBytes = try decodeSegment(parts[2])
        XCTAssertEqual(signatureBytes.count, 64)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureBytes)
        XCTAssertTrue(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    func testTokenIsReusedUnderFortyMinutesAndNeverPastSixty() async throws {
        let sut = makeSUT()

        let first = try await sut.providerToken(for: .sandbox)
        clock.advance(39 * 60)
        let at39 = try await sut.providerToken(for: .sandbox)
        clock.advance(60)
        let at40 = try await sut.providerToken(for: .sandbox)
        clock.advance(39 * 60)
        let at79 = try await sut.providerToken(for: .sandbox)
        clock.advance(21 * 60)
        let at100 = try await sut.providerToken(for: .sandbox)

        XCTAssertEqual(at39, first)
        XCTAssertNotEqual(at40, first)
        XCTAssertEqual(at79, at40)
        XCTAssertNotEqual(at100, at40)
    }

    func testRequestCarriesExactlyTheAPNsHeaders() async throws {
        let transport = MockAPNsTransport()
        let expiration = clock.now.addingTimeInterval(3600)

        _ = try await makeSUT(transport: transport).send(payload: Data("{}".utf8), to: device, expiration: expiration)

        let request = try XCTUnwrap(transport.requests.first)
        let headers = try XCTUnwrap(request.allHTTPHeaderFields)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.sandbox.push.apple.com/3/device/\(device.token)")
        // Foundation canonicalizes "Authorization"; HTTP/2 lowercases every name on the wire.
        XCTAssertEqual(Set(headers.keys.map { $0.lowercased() }), ["authorization", "apns-push-type", "apns-priority", "apns-topic", "apns-expiration"])
        XCTAssertEqual(headers["apns-push-type"], "alert")
        XCTAssertEqual(headers["apns-priority"], "10")
        XCTAssertEqual(headers["apns-topic"], StubAPNsCredentialsProvider.topic)
        XCTAssertEqual(headers["apns-expiration"], String(Int(expiration.timeIntervalSince1970)))
        XCTAssertEqual(request.value(forHTTPHeaderField: "authorization")?.hasPrefix("bearer "), true)
        XCTAssertNil(request.value(forHTTPHeaderField: "apns-collapse-id"))
    }

    func testProductionDeviceUsesProductionHost() async throws {
        let transport = MockAPNsTransport()
        let device = PairedDevice(token: device.token, environment: .production, topic: device.topic, pairedAt: device.pairedAt)

        _ = try await makeSUT(transport: transport).send(payload: Data(), to: device, expiration: clock.now)

        XCTAssertEqual(transport.requests.first?.url?.host, "api.push.apple.com")
    }

    func testExpiredProviderTokenReSignsAndRetriesExactlyOnce() async throws {
        let transport = MockAPNsTransport(replies: [.init(status: 403, reason: "ExpiredProviderToken"), .init(status: 403, reason: "ExpiredProviderToken")])

        let response = try await makeSUT(transport: transport).send(payload: Data(), to: device, expiration: clock.now)

        let authorizations = transport.requests.map { $0.value(forHTTPHeaderField: "authorization") }
        XCTAssertEqual(response, APNsResponse(status: 403, reason: "ExpiredProviderToken"))
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertNotEqual(authorizations[0], authorizations[1])
    }

    func testEmbeddedKeyIsReadFromBase64PEM() throws {
        let pem = key.pemRepresentation
        let provider = APNsCredentialsProvider(store: InMemoryAPNsCredentialStore(),
                                               embeddedKey: { _ in EmbeddedAPNsKey(keyID: "ABC123DEFG", teamID: "TEAM123456", privateKeyBase64: Data(pem.utf8).base64EncodedString()) },
                                               embeddedTopic: { StubAPNsCredentialsProvider.topic })

        let credentials = try provider.current(for: .production)

        XCTAssertEqual(credentials.privateKey.publicKey.rawRepresentation, key.publicKey.rawRepresentation)
        XCTAssertEqual(provider.expectedTopic(), StubAPNsCredentialsProvider.topic)
    }

    func testMissingEmbeddedKeyThrowsMissingConfiguration() {
        let provider = APNsCredentialsProvider(store: InMemoryAPNsCredentialStore(),
                                               embeddedKey: { _ in EmbeddedAPNsKey(keyID: "", teamID: "", privateKeyBase64: "") },
                                               embeddedTopic: { nil })

        XCTAssertThrowsError(try provider.current(for: .sandbox)) { error in
            guard case NotifierError.missingConfiguration("apns") = error else { return XCTFail("\(error)") }
        }
    }

    func testOwnKeyWinsAndSingleLinePEMIsAccepted() throws {
        let ownKey = P256.Signing.PrivateKey()
        let store = InMemoryAPNsCredentialStore()
        try store.saveBYOK(BYOKCredentials(keyID: "OWNKEY1234", teamID: "OWNTEAM123", topic: "dev.example.Companion",
                                           privateKeyPEM: ownKey.pemRepresentation.replacingOccurrences(of: "\n", with: "")))
        let provider = APNsCredentialsProvider(store: store, embeddedKey: { _ in EmbeddedAPNsKey(keyID: "", teamID: "", privateKeyBase64: "") }, embeddedTopic: { nil })

        let credentials = try provider.current(for: .sandbox)

        XCTAssertEqual(credentials.privateKey.publicKey.rawRepresentation, ownKey.publicKey.rawRepresentation)
        XCTAssertEqual(credentials.topic, "dev.example.Companion")
        XCTAssertEqual(provider.expectedTopic(), "dev.example.Companion")
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/APNsClient.swift
// @doc-refs: Source/Utils/APNsCredentialStore.swift
