//
//  GeofenceListenerTests.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CoreLocation
import XCTest
@testable import Lock_Watcher

/// @test-required
@MainActor
final class GeofenceListenerTests: XCTestCase {
    private var detector: MockLockDetector!
    private var monitor: MockLocationMonitor!
    private var clock: StubValue<Date>!
    private var sut: GeofenceListener!

    private let origin = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)

    override func setUp() async throws {
        try await super.setUp()
        let clock = StubValue(Date(timeIntervalSince1970: 1_000_000))
        self.clock = clock
        detector = MockLockDetector()
        monitor = MockLocationMonitor()
        sut = GeofenceListener(logger: LogMock(), lockDetector: detector, monitor: monitor, now: { clock.value })
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        monitor = nil
        detector = nil
        clock = nil
        try await super.tearDown()
    }

    /// A fix `meters` north of `origin`, taken now unless `age` says otherwise.
    private func fix(north meters: CLLocationDistance, accuracy: CLLocationAccuracy = 10, age: TimeInterval = 0) -> CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: origin.latitude + meters / 111_320, longitude: origin.longitude)
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: clock.value.addingTimeInterval(-age))
    }

    private func tick(_ locked: Bool) {
        clock.value = clock.value.addingTimeInterval(1)
        detector.tick(locked: locked)
    }

    private func finish(_ stream: AsyncStream<ListenerEvent>) async -> [TriggerType] {
        sut.stop()
        return await collectTriggers(stream)
    }

    // MARK: - Movement

    func testFix600mAwayWhileLockedYieldsOnce() async {
        let stream = sut.start()
        tick(false)
        monitor.emit(fix(north: 0))
        tick(true)
        monitor.emit(fix(north: 600))
        monitor.emit(fix(north: 1200))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.locationChanged])
    }

    func testFix400mAwayWhileLockedYieldsNothing() async {
        let stream = sut.start()
        tick(false)
        monitor.emit(fix(north: 0))
        tick(true)
        monitor.emit(fix(north: 400))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testFixesWhileUnlockedOnlyMoveTheBaseline() async {
        let stream = sut.start()
        tick(false)
        monitor.emit(fix(north: 0))
        monitor.emit(fix(north: 600))
        tick(true)
        monitor.emit(fix(north: 650))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testFixBeforeFirstTickIsDropped() async {
        let stream = sut.start()
        monitor.emit(fix(north: 0))
        tick(false)
        tick(true)
        monitor.emit(fix(north: 600))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStartedMidLockHasNoBaseline() async {
        let stream = sut.start()
        tick(true)
        monitor.emit(fix(north: 0))
        monitor.emit(fix(north: 600))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStaleFixIsNotABaseline() async {
        let stream = sut.start()
        tick(false)
        monitor.emit(fix(north: 0, age: 86_400))
        tick(true)
        monitor.emit(fix(north: 600))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testFailedUnlockFixLeavesNoBaseline() async {
        let stream = sut.start()
        tick(false)
        monitor.emit(fix(north: 0))
        tick(true)
        tick(false)
        tick(true)
        monitor.emit(fix(north: 600))

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testUnlockRequestsAFix() {
        _ = sut.start()
        tick(false)
        XCTAssertEqual(monitor.requestFixCount, 1)
        tick(false)
        XCTAssertEqual(monitor.requestFixCount, 1)
    }

    // MARK: - Authorization

    func testUnauthorizedStatusesDoNotMonitor() {
        for status: CLAuthorizationStatus in [.denied, .restricted, .notDetermined] {
            let monitor = MockLocationMonitor()
            monitor.authorizationStatus = status
            let listener = GeofenceListener(logger: LogMock(), lockDetector: detector, monitor: monitor, now: { Date() })

            _ = listener.start()

            XCTAssertFalse(listener.isRunning, "status \(status.rawValue)")
            XCTAssertEqual(monitor.startCount, 0, "status \(status.rawValue)")
            listener.stop()
        }
    }

    func testUnavailableSignificantChangesDoNotMonitor() {
        monitor.isSignificantChangeAvailable = false
        _ = sut.start()
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(monitor.startCount, 0)
    }

    func testLateGrantStartsAndRevokeStopsMonitoring() {
        monitor.authorizationStatus = .notDetermined
        _ = sut.start()
        XCTAssertFalse(sut.isRunning)

        monitor.changeAuthorization(to: .authorizedAlways)
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(monitor.startCount, 1)

        monitor.changeAuthorization(to: .denied)
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testRestrictionStopsActiveMonitoring() {
        _ = sut.start()
        XCTAssertTrue(sut.isRunning)

        monitor.changeAuthorization(to: .restricted)

        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testStartIsIdempotentAndStopEndsMonitoring() {
        _ = sut.start()
        _ = sut.start()
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(monitor.startCount - monitor.stopCount, 1)

        sut.stop()
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(monitor.startCount, monitor.stopCount)
        XCTAssertNil(monitor.onFix)
    }

    // MARK: - Rule

    func testRuleRejectsInaccurateOrStaleFixes() {
        let now = clock.value
        XCTAssertTrue(GeofenceRule.isUsable(fix(north: 0), now: now))
        XCTAssertFalse(GeofenceRule.isUsable(fix(north: 0, accuracy: -1), now: now))
        XCTAssertFalse(GeofenceRule.isUsable(fix(north: 0, accuracy: 1500), now: now))
        XCTAssertFalse(GeofenceRule.isUsable(fix(north: 0, age: 121), now: now))
    }

    func testRuleSubtractsWorstAccuracy() {
        XCTAssertTrue(GeofenceRule.hasMoved(from: fix(north: 0), to: fix(north: 600)))
        XCTAssertFalse(GeofenceRule.hasMoved(from: fix(north: 0, accuracy: 150), to: fix(north: 600)))
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/GeofenceListener.swift
