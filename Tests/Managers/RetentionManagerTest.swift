//
//  RetentionManagerTest.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

@MainActor
final class RetentionManagerTests: XCTestCase {
    private let launchDate = Date(timeIntervalSince1970: 1_800_000_000)
    private var settings: MockAppSettings!
    private var pruner: PrunerSpy!
    private var clock: FixedDateProvider!
    private var notices: RetentionNoticeSpy!
    private var sut: RetentionManager!

    override func setUp() async throws {
        try await super.setUp()
        settings = MockAppSettings()
        pruner = PrunerSpy()
        clock = FixedDateProvider(now: launchDate)
        notices = RetentionNoticeSpy()
        sut = RetentionManager(settings: settings, pruner: pruner, dateProvider: clock, noticePresenter: notices, logger: LogMock())
    }

    override func tearDown() async throws {
        sut = nil
        notices = nil
        clock = nil
        pruner = nil
        settings = nil
        try await super.tearDown()
    }

    private func incident(stem: String = "capture-1", video: Bool = false) -> ThiefDto {
        let folder = URL(fileURLWithPath: "/tmp/Lock-Watcher")
        return ThiefDto(triggerType: .onWakeUp,
                        filePath: folder.appendingPathComponent("\(stem).jpeg"),
                        videoURL: video ? folder.appendingPathComponent("\(stem).mov") : nil)
    }

    // MARK: - Launch

    func testLaunchSetsStartDateOnceAndSweeps() async {
        await sut.applicationDidLaunch()
        clock.now = launchDate.addingTimeInterval(3600)
        await sut.applicationDidLaunch()

        XCTAssertEqual(settings.retention.startDate, launchDate)
        let prunes = await pruner.prunes
        XCTAssertEqual(prunes.count, 2)
        XCTAssertEqual(prunes.first?.policy, RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: launchDate))
    }

    func testUpgradeNoticeShownOnceWhenOlderFilesExist() async throws {
        await pruner.setHasOldFiles(true)

        await sut.applicationDidLaunch()
        await sut.applicationDidLaunch()

        XCTAssertEqual(notices.notices.count, 1)
        let notice = try XCTUnwrap(notices.notices.first)
        XCTAssertEqual(notice.period, .oneWeek)
        XCTAssertEqual(notice.firstDeletion, launchDate.addingTimeInterval(RetentionPeriod.oneWeek.maxAge))
        XCTAssertTrue(settings.retention.isUpgradeNoticeShown)
    }

    func testNoticeIsMarkedShownBeforeItIsPresented() async {
        await pruner.setHasOldFiles(true)
        var flagAtPresentation: Bool?
        notices.onPresent = { flagAtPresentation = self.settings.retention.isUpgradeNoticeShown }

        await sut.applicationDidLaunch()

        XCTAssertEqual(flagAtPresentation, true)
    }

    func testTestHostIsDetected() {
        XCTAssertTrue(LaunchEnvironment.isHostingTests)
    }

    func testFreshInstallGetsStartDateButNoNotice() async {
        await sut.applicationDidLaunch()

        XCTAssertTrue(notices.notices.isEmpty)
        XCTAssertEqual(settings.retention.startDate, launchDate)
        XCTAssertTrue(settings.retention.isUpgradeNoticeShown)
    }

    // MARK: - Incident

    func testAfterUploadWithConfirmedUploadRemovesRecordFiles() async {
        settings.retention.keepFiles = .afterUpload

        await sut.incidentRecorded(incident(stem: "capture-7", video: true), report: DeliveryReport(outcomes: [.iCloud: .confirmed, .dropbox: .confirmed]))

        let stems = await pruner.removedStems
        let prunes = await pruner.prunes
        XCTAssertEqual(stems, ["capture-7"])
        XCTAssertEqual(prunes.count, 1)
    }

    func testAfterUploadKeepsFilesWithoutConfirmation() async {
        settings.retention.keepFiles = .afterUpload
        let unconfirmed: [DeliveryReport] = [
            .empty,
            DeliveryReport(outcomes: [.notification: .confirmed]),
            DeliveryReport(outcomes: [.iCloud: .confirmed, .mail: .unconfirmed]),
            DeliveryReport(outcomes: [.iCloud: .confirmed, .dropbox: .failed])
        ]

        for report in unconfirmed {
            await sut.incidentRecorded(incident(), report: report)
        }

        let stems = await pruner.removedStems
        let prunes = await pruner.prunes
        XCTAssertTrue(stems.isEmpty)
        XCTAssertEqual(prunes.count, unconfirmed.count)
        XCTAssertEqual(prunes.last?.policy.maxAge, RetentionPeriod.oneWeek.maxAge)
    }

    func testTimedPeriodNeverRemovesByStem() async {
        settings.retention.keepFiles = .oneWeek

        await sut.incidentRecorded(incident(), report: DeliveryReport(outcomes: [.iCloud: .confirmed]))

        let stems = await pruner.removedStems
        XCTAssertTrue(stems.isEmpty)
    }

    // MARK: - Setting change

    func testSettingChangeSweepsWithNewPeriod() async {
        settings.retention.keepFiles = .oneYear

        await sut.retentionSettingChanged()

        let prunes = await pruner.prunes
        XCTAssertEqual(prunes.count, 1)
        XCTAssertEqual(prunes.first?.policy.maxAge, RetentionPeriod.oneYear.maxAge)
    }
}

// MARK: - Source Info

// @source-file: Source/Managers/RetentionManager.swift
