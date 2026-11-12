//
//  CompanionPromptManagerTest.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

@MainActor
final class CompanionPromptManagerTests: XCTestCase {
    private let shownAt = Date(timeIntervalSince1970: 1_800_000_000)
    private var settings: MockAppSettings!
    private var store: StubCredentialStore!
    private var presenter: PromptSpy!

    override func setUp() async throws {
        try await super.setUp()
        settings = MockAppSettings()
        store = StubCredentialStore(status: .unpaired)
        presenter = PromptSpy()
    }

    override func tearDown() async throws {
        presenter = nil
        store = nil
        settings = nil
        try await super.tearDown()
    }

    private func makeSUT(delay: Duration = .milliseconds(20)) -> CompanionPromptManager {
        CompanionPromptManager(settings: settings, store: store, presenter: presenter, delay: delay, now: { [shownAt] in shownAt })
    }

    func testDefaultDelayIsOneMinute() {
        XCTAssertEqual(CompanionPromptManager.delay, .seconds(60))
    }

    func testShowsOnceWhenNoIPhoneIsPaired() async {
        let sut = makeSUT()

        let first = await sut.evaluate()
        let second = await sut.evaluate()

        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(presenter.count, 1)
        XCTAssertEqual(settings.ui.companionPromptShownAt, shownAt)
    }

    func testSkipsWhenAnIPhoneIsPaired() async {
        store.status = .paired(PairedDevice(token: "t", environment: .production, topic: "x", pairedAt: shownAt))

        let shown = await makeSUT().evaluate()

        XCTAssertFalse(shown)
        XCTAssertEqual(presenter.count, 0)
        XCTAssertNil(settings.ui.companionPromptShownAt)
    }

    func testSkipsWhenPairingNeedsRepair() async {
        store.status = .needsRepair

        let shown = await makeSUT().evaluate()

        XCTAssertFalse(shown)
    }

    func testSkipsWhenAlreadyShownBefore() async {
        settings.ui.companionPromptShownAt = shownAt.addingTimeInterval(-86_400)

        let shown = await makeSUT().evaluate()

        XCTAssertFalse(shown)
        XCTAssertEqual(presenter.count, 0)
    }

    func testLaunchShowsAfterTheDelay() async throws {
        let sut = makeSUT()

        sut.applicationDidLaunch()
        XCTAssertEqual(presenter.count, 0)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(presenter.count, 1)
    }

    func testCancelBeforeTheDelayShowsNothing() async throws {
        let sut = makeSUT(delay: .milliseconds(100))

        sut.applicationDidLaunch()
        sut.cancel()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(presenter.count, 0)
        XCTAssertNil(settings.ui.companionPromptShownAt)
    }

    func testLaunchWithShownFlagStartsNoWait() async throws {
        settings.ui.companionPromptShownAt = shownAt
        let sut = makeSUT()

        sut.applicationDidLaunch()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(presenter.count, 0)
    }
}

@MainActor
private final class PromptSpy: CompanionPromptPresenting {
    private(set) var count = 0

    func presentCompanionPrompt() {
        count += 1
    }
}

private final class StubCredentialStore: APNsCredentialStoring, @unchecked Sendable {
    var status: PairingStatus

    init(status: PairingStatus) {
        self.status = status
    }

    func pairedDevice() -> PairedDevice? {
        nil
    }

    func savePairedDevice(_ device: PairedDevice) throws {}

    func markNeedsRepair() {}

    func clearPairing() {}

    func pairingStatus() -> PairingStatus {
        status
    }

    func byokCredentials() -> BYOKCredentials? {
        nil
    }

    func saveBYOK(_ credentials: BYOKCredentials) throws {}

    func clearBYOK() {}
}

// MARK: - Source Info

// @source-file: Source/Managers/CompanionPromptManager.swift
