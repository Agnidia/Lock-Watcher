//
//  NotificationManagerTest.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class DeliveryReportTests: XCTestCase {
    func testRemoteUploadConfirmationRules() {
        let cases: [([NotifierChannel: DeliveryOutcome], Bool)] = [
            ([:], false),
            ([.iCloud: .confirmed], true),
            ([.dropbox: .confirmed], true),
            ([.iCloud: .confirmed, .dropbox: .confirmed], true),
            ([.iCloud: .confirmed, .dropbox: .failed], false),
            ([.iCloud: .confirmed, .mail: .unconfirmed], false),
            ([.iCloud: .confirmed, .mail: .failed], false),
            ([.notification: .confirmed], false),
            ([.dropbox: .confirmed, .notification: .failed], true)
        ]

        for (outcomes, expected) in cases {
            XCTAssertEqual(DeliveryReport(outcomes: outcomes).isRemoteUploadConfirmed, expected, "\(outcomes)")
        }
    }
}

final class NotificationManagerTests: XCTestCase {
    private func makeSettings(iCloud: Bool, dropbox: Bool, notification: Bool = false) -> MockAppSettings {
        var sync = SyncSettings()
        sync.isICloudSyncEnable = iCloud
        sync.isDropboxEnable = dropbox
        sync.isUseSnapshotLocalNotification = notification
        return MockAppSettings(sync: sync)
    }

    func testReportsEachEnabledChannel() async {
        let iCloud = MockNotifier()
        let dropbox = MockNotifier()
        let notification = MockNotifier()
        let sut = NotificationManager(settings: makeSettings(iCloud: true, dropbox: true, notification: true),
                                      mail: MockNotifier(), iCloud: iCloud, dropbox: dropbox, notification: notification, logger: LogMock())

        let report = await sut.send(ThiefDto(triggerType: .onWakeUp))

        XCTAssertEqual(report.outcomes, [.iCloud: .confirmed, .dropbox: .confirmed, .notification: .confirmed])
        XCTAssertTrue(report.isRemoteUploadConfirmed)
        XCTAssertEqual([iCloud.sentCount, dropbox.sentCount, notification.sentCount], [1, 1, 1])
    }

    func testFailedUploadIsReportedAndLoggedByChannelOnly() async {
        let iCloud = MockNotifier()
        iCloud.error = NotifierError.uploadFailed(CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: "/Users/someone/secret.mov"]))
        let logger = LogMock()
        let sut = NotificationManager(settings: makeSettings(iCloud: true, dropbox: false),
                                      mail: MockNotifier(), iCloud: iCloud, dropbox: MockNotifier(), notification: MockNotifier(), logger: logger)

        let report = await sut.send(ThiefDto(triggerType: .onWakeUp))

        XCTAssertEqual(report.outcomes, [.iCloud: .failed])
        XCTAssertFalse(report.isRemoteUploadConfirmed)
        XCTAssertEqual(logger.errorMessage, "iCloud delivery failed: uploadFailed")
    }

    func testDisabledChannelsAreNotReported() async {
        let sut = NotificationManager(settings: makeSettings(iCloud: false, dropbox: false),
                                      mail: MockNotifier(), iCloud: MockNotifier(), dropbox: MockNotifier(), notification: MockNotifier(), logger: LogMock())

        let report = await sut.send(ThiefDto(triggerType: .onWakeUp))

        XCTAssertEqual(report, .empty)
    }
}

final class MediaAttachmentPolicyTests: XCTestCase {
    private let movie = URL(fileURLWithPath: "/tmp/capture.mov")
    private let poster = URL(fileURLWithPath: "/tmp/capture.jpeg")
    private let megabyte: Int64 = 1_000_000

    private func attachment(sizeMB: Int64?, limit: Int64, logger: LogMock = LogMock()) -> URL? {
        MediaAttachmentPolicy.attachment(for: .video(movie: movie, poster: poster),
                                         limitBytes: limit,
                                         fileSize: { _ in sizeMB.map { $0 * self.megabyte } },
                                         logger: logger)
    }

    func testMailLimit() {
        XCTAssertEqual(attachment(sizeMB: 19, limit: MediaAttachmentPolicy.mailLimitBytes), movie)
        XCTAssertEqual(attachment(sizeMB: 20, limit: MediaAttachmentPolicy.mailLimitBytes), movie)
        XCTAssertEqual(attachment(sizeMB: 21, limit: MediaAttachmentPolicy.mailLimitBytes), poster)
    }

    func testNotificationLimit() {
        XCTAssertEqual(attachment(sizeMB: 49, limit: MediaAttachmentPolicy.notificationLimitBytes), movie)
        XCTAssertEqual(attachment(sizeMB: 51, limit: MediaAttachmentPolicy.notificationLimitBytes), poster)
    }

    func testUnknownSizeFallsBackToStill() {
        XCTAssertEqual(attachment(sizeMB: nil, limit: MediaAttachmentPolicy.mailLimitBytes), poster)
    }

    func testFallbackLogOmitsPath() throws {
        let logger = LogMock()

        _ = attachment(sizeMB: 51, limit: MediaAttachmentPolicy.notificationLimitBytes, logger: logger)

        let message = try XCTUnwrap(logger.infoMessage)
        XCTAssertFalse(message.contains("/tmp"))
        XCTAssertFalse(message.contains("capture"))
    }

    func testPhotoAttachesStill() {
        XCTAssertEqual(MediaAttachmentPolicy.attachment(for: .photo(still: poster), limitBytes: 1, fileSize: { _ in 10 }), poster)
    }
}

final class NotificationNotifierAttachmentTests: XCTestCase {
    func testAttachmentCopyLeavesOriginalInPlace() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AttachmentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("capture.mov")
        try Data("movie".utf8).write(to: original)

        let copy = try XCTUnwrap(NotificationNotifier(logger: LogMock()).temporaryCopy(of: original))
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertNotEqual(copy.deletingLastPathComponent(), original.deletingLastPathComponent())
        XCTAssertEqual(copy.lastPathComponent, original.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: original))
    }
}

// MARK: - Source Info

// @source-file: Source/Managers/NotificationManager.swift
