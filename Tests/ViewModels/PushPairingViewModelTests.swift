//
//  PushPairingViewModelTests.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import XCTest
@testable import Lock_Watcher

@MainActor
final class PushPairingViewModelTests: XCTestCase {
    private let topic = PushPairingViewModel.previewTopic
    private let pairedAt = Date(timeIntervalSince1970: 1_793_000_000)

    private func code(topic: String? = nil) throws -> String {
        try PairingPayload(token: String(repeating: "1f", count: 32), environment: .production, topic: topic ?? self.topic).qrString
    }

    private func makeSUT(store: any APNsCredentialStoring = InMemoryAPNsCredentialStore(),
                         codes: [String] = [],
                         granted: Bool = true,
                         unavailable: Bool = false,
                         center: NotificationCenter = NotificationCenter()) -> (PushPairingViewModel, StubQRCodeScanner, StubCameraAuthorizer)
    {
        let scanner = StubQRCodeScanner(codes: codes, isUnavailable: unavailable)
        let camera = StubCameraAuthorizer(isGranted: granted)
        let pairedAt = pairedAt
        let topic = topic
        let sut = PushPairingViewModel(store: store, scanner: scanner, camera: camera, expectedTopic: { topic }, now: { pairedAt }, notificationCenter: center)
        return (sut, scanner, camera)
    }

    func testBlockPhaseProjection() {
        let paired = PushPairingState.paired(environment: .sandbox, pairedAt: pairedAt)

        XCTAssertEqual(PushBlockPhase.make(isEnabled: false, pairing: paired), .disabled)
        XCTAssertEqual(PushBlockPhase.make(isEnabled: true, pairing: .unpaired), .unpaired)
        XCTAssertEqual(PushBlockPhase.make(isEnabled: true, pairing: paired), .paired(environment: .sandbox, pairedAt: pairedAt))
        XCTAssertEqual(PushBlockPhase.make(isEnabled: true, pairing: .needsRepair), .needsRepair)
    }

    func testValidCodePairsDismissesAndStopsScanner() async throws {
        let (sut, scanner, _) = try makeSUT(codes: [code()])

        sut.startPairing()
        await sut.runScan()

        XCTAssertEqual(sut.pairing, .paired(environment: .production, pairedAt: pairedAt))
        XCTAssertFalse(sut.isPairingSheetPresented)
        XCTAssertEqual(scanner.stopCount, 1)
    }

    func testInvalidCodeShowsFeedbackThenValidCodePairs() async throws {
        let (sut, _, _) = try makeSUT(codes: ["https://example.com", "https://example.com", code()])

        sut.startPairing()
        await sut.runScan()

        XCTAssertEqual(sut.pairing, .paired(environment: .production, pairedAt: pairedAt))
    }

    func testCodeForAnotherAppIsRejected() async throws {
        let store = InMemoryAPNsCredentialStore()
        let (sut, scanner, _) = try makeSUT(store: store, codes: [code(topic: "com.example.other")])

        sut.startPairing()
        await sut.runScan()

        XCTAssertEqual(sut.scanPhase, .rejected(.wrongApp))
        XCTAssertEqual(store.pairingStatus(), .unpaired)
        XCTAssertEqual(scanner.stopCount, 1)
    }

    func testCameraDenialShowsGuidanceWithoutStartingTheCamera() async {
        let (sut, scanner, camera) = makeSUT(granted: false)

        await sut.runScan()

        XCTAssertEqual(sut.scanPhase, .cameraDenied)
        XCTAssertEqual(camera.requestCount, 1)
        XCTAssertEqual(scanner.startCount, 0)
    }

    func testBusyCameraShowsUnavailable() async {
        let (sut, _, _) = makeSUT(unavailable: true)

        await sut.runScan()

        XCTAssertEqual(sut.scanPhase, .cameraUnavailable)
    }

    func testStoreChangeRefreshesState() async throws {
        let center = NotificationCenter()
        let store = InMemoryAPNsCredentialStore(device: PairedDevice(token: String(repeating: "1f", count: 32), environment: .sandbox, topic: topic, pairedAt: pairedAt),
                                                notificationCenter: center)
        let (sut, _, _) = makeSUT(store: store, center: center)
        await sut.refresh()
        XCTAssertEqual(sut.pairing, .paired(environment: .sandbox, pairedAt: pairedAt))

        store.markNeedsRepair()
        for _ in 0 ..< 50 where sut.pairing != .needsRepair {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(sut.pairing, .needsRepair)
    }

    func testForgetClearsThePairing() throws {
        let store = InMemoryAPNsCredentialStore()
        let (sut, _, _) = makeSUT(store: store)
        XCTAssertNil(try sut.accept(code()))

        sut.forget()

        XCTAssertEqual(sut.pairing, .unpaired)
        XCTAssertNil(store.pairedDevice())
    }

    func testOwnKeyIsValidatedBeforeSaving() {
        let (sut, _, _) = makeSUT()

        XCTAssertFalse(sut.saveOwnKey(keyID: "short", teamID: "TEAM123456", topic: "dev.example.App", pem: "nope"))
        XCTAssertFalse(sut.hasOwnKey)
        XCTAssertTrue(sut.saveOwnKey(keyID: "OWNKEY1234", teamID: "TEAM123456", topic: "dev.example.App", pem: P256.Signing.PrivateKey().pemRepresentation))
        XCTAssertTrue(sut.hasOwnKey)

        sut.clearOwnKey()
        XCTAssertFalse(sut.hasOwnKey)
    }

    func testKeychainStoreIntegration() async throws {
        let center = NotificationCenter()
        let store = APNsCredentialStore(service: "\(UUID().uuidString).test.apns", notificationCenter: center)
        defer { store.clearPairing() }
        let (sut, _, _) = makeSUT(store: store, center: center)

        XCTAssertNil(try sut.accept(code()))
        XCTAssertEqual(sut.pairing, .paired(environment: .production, pairedAt: pairedAt))

        store.markNeedsRepair()
        await sut.refresh()
        XCTAssertEqual(sut.pairing, .needsRepair)
    }

    func testOwnKeyForAnotherTopicMarksPairingForRepair() async throws {
        let store = InMemoryAPNsCredentialStore()
        let topic = topic
        let sut = PushPairingViewModel(store: store, scanner: StubQRCodeScanner(codes: [], isUnavailable: false), camera: StubCameraAuthorizer(isGranted: true),
                                       expectedTopic: { store.byokCredentials()?.topic ?? topic }, notificationCenter: NotificationCenter())
        XCTAssertNil(try sut.accept(code()))
        let pem = P256.Signing.PrivateKey().pemRepresentation

        XCTAssertTrue(sut.saveOwnKey(keyID: "OWNKEY1234", teamID: "TEAM123456", topic: topic, pem: pem))
        XCTAssertNotEqual(sut.pairing, .needsRepair)

        XCTAssertTrue(sut.saveOwnKey(keyID: "OWNKEY1234", teamID: "TEAM123456", topic: "dev.example.App", pem: pem))
        XCTAssertEqual(sut.pairing, .needsRepair)
        XCTAssertEqual(store.pairingStatus(), .needsRepair)
        await sut.refresh()
        XCTAssertEqual(sut.pairing, .needsRepair)
    }
}

// MARK: - Source Info

// @source-file: Source/Views/Settings/Subviews/Push/PushPairingViewModel.swift
