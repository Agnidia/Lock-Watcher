//
//  APNsCredentialStoreTest.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class APNsCredentialStoreTest: XCTestCase {
    private let device = PairedDevice(token: String(repeating: "5e", count: 32), environment: .production, topic: "com.igrsoft.Lock-Watcher",
                                      pairedAt: Date(timeIntervalSince1970: 1_793_000_000))
    private var center: NotificationCenter!
    private var store: APNsCredentialStore!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        store = APNsCredentialStore(service: "\(UUID().uuidString).test.apns", notificationCenter: center)
    }

    override func tearDown() {
        store.clearPairing()
        store.clearBYOK()
        store = nil
        center = nil
        super.tearDown()
    }

    func testStoreLoadThenClear() throws {
        XCTAssertNil(store.pairedDevice())

        try store.savePairedDevice(device)
        XCTAssertEqual(store.pairedDevice(), device)
        XCTAssertEqual(store.pairingStatus(), .paired(device))

        store.clearPairing()
        XCTAssertNil(store.pairedDevice())
        XCTAssertEqual(store.pairingStatus(), .unpaired)
    }

    func testNeedsRepairDropsTokenUntilANewPairing() throws {
        try store.savePairedDevice(device)

        store.markNeedsRepair()
        XCTAssertNil(store.pairedDevice())
        XCTAssertEqual(store.pairingStatus(), .needsRepair)

        try store.savePairedDevice(device)
        XCTAssertEqual(store.pairingStatus(), .paired(device))
    }

    func testOwnKeyRoundTrip() throws {
        let credentials = BYOKCredentials(keyID: "OWNKEY1234", teamID: "OWNTEAM123", topic: "dev.example.Companion", privateKeyPEM: "pem")

        try store.saveBYOK(credentials)
        XCTAssertEqual(store.byokCredentials(), credentials)

        store.clearBYOK()
        XCTAssertNil(store.byokCredentials())
    }

    func testEveryMutationPostsPairingChange() throws {
        let changed = expectation(forNotification: .pushPairingDidChange, object: nil, notificationCenter: center)
        changed.expectedFulfillmentCount = 3

        try store.savePairedDevice(device)
        store.markNeedsRepair()
        store.clearPairing()

        wait(for: [changed], timeout: 1)
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/APNsCredentialStore.swift
