//
//  DisplayListenerTests.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreGraphics
import XCTest
@testable import Lock_Watcher

/// @test-required
@MainActor
final class DisplayListenerTests: XCTestCase {
    private var detector: MockLockDetector!
    private var displays: StubValue<Set<CGDirectDisplayID>?>!
    private var clock: StubValue<Date>!
    private var sut: DisplayListener!

    override func setUp() async throws {
        try await super.setUp()
        let displays = StubValue<Set<CGDirectDisplayID>?>([1])
        let clock = StubValue(Date(timeIntervalSince1970: 1_000_000))
        detector = MockLockDetector()
        self.displays = displays
        self.clock = clock
        sut = DisplayListener(logger: LogMock(),
                              lockDetector: detector,
                              onlineDisplayIDs: { displays.value },
                              now: { clock.value },
                              grace: 10)
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        detector = nil
        displays = nil
        clock = nil
        try await super.tearDown()
    }

    private func tick(_ locked: Bool, after seconds: TimeInterval = 1) {
        clock.value = clock.value.addingTimeInterval(seconds)
        detector.tick(locked: locked)
    }

    private func finish(_ stream: AsyncStream<ListenerEvent>) async -> [TriggerType] {
        sut.stop()
        return await collectTriggers(stream)
    }

    func testNewDisplayWhileLockedFiresAfterGrace() async {
        let stream = sut.start()
        tick(false)
        tick(true)
        displays.value = [1, 2]
        tick(true)
        for _ in 0 ..< 9 {
            tick(true)
        }
        tick(true)
        tick(true)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.displayAttached])
    }

    func testNewDisplayWhileUnlockedYieldsNothing() async {
        let stream = sut.start()
        tick(false)
        displays.value = [1, 2]
        for _ in 0 ..< 15 {
            tick(false)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testDisplayPresentAtLockYieldsNothing() async {
        displays.value = [1, 2]
        let stream = sut.start()
        tick(false)
        tick(true)
        for _ in 0 ..< 15 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testUnlockInsideGraceYieldsNothing() async {
        let stream = sut.start()
        tick(false)
        tick(true)
        displays.value = [1, 2]
        tick(true)
        tick(true, after: 5)
        tick(false)
        tick(false, after: 20)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStartedMidLockStaysSilent() async {
        let stream = sut.start()
        tick(true)
        displays.value = [1, 2]
        for _ in 0 ..< 15 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testFiresOncePerLockPeriod() async {
        let stream = sut.start()
        tick(false)
        tick(true)
        displays.value = [1, 2]
        tick(true)
        tick(true, after: 11)
        displays.value = [1, 2, 3]
        tick(true)
        tick(true, after: 11)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.displayAttached])
    }

    func testUnreadableDisplayListAtLockYieldsNothing() async {
        displays.value = nil
        let stream = sut.start()
        tick(false)
        tick(true)
        displays.value = [1, 2]
        tick(true)
        tick(true, after: 11)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStartIsIdempotentAndStopEndsRunning() {
        _ = sut.start()
        _ = sut.start()
        XCTAssertTrue(sut.isRunning)
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/DisplayListener.swift
