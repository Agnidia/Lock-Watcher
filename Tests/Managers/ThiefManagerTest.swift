//
//  ThiefManagerTest.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CameraSnap
import XCTest
@testable import Lock_Watcher

@MainActor
final class ThiefManagerTests: XCTestCase {
    private var settings: MockAppSettings!
    private var camera: FakeCamera!
    private var notificationManager: MockNotificationManager!
    private var database: MockDatabaseManager!
    private var fileSystem: TemporaryFileSystemUtil!
    private var retention: RetentionManagerSpy!
    private var logger: LogMock!
    private var posterSucceeds = true
    private var cameraNotice: CameraAccessNoticeSpy!

    override func setUp() async throws {
        try await super.setUp()
        settings = MockAppSettings()
        camera = FakeCamera()
        notificationManager = MockNotificationManager()
        database = MockDatabaseManager()
        fileSystem = TemporaryFileSystemUtil()
        retention = RetentionManagerSpy()
        logger = LogMock()
        posterSucceeds = true
        cameraNotice = CameraAccessNoticeSpy()
    }

    override func tearDown() async throws {
        fileSystem.removeDirectory()
        settings = nil
        camera = nil
        notificationManager = nil
        database = nil
        fileSystem = nil
        retention = nil
        logger = nil
        try await super.tearDown()
    }

    private func makeSUT(isImageCaptureDebug: Bool = false) -> ThiefManager {
        let dependencies = ThiefManagerDependencies(camera: camera,
                                                    notificationManager: notificationManager,
                                                    databaseManager: database,
                                                    fileSystemUtil: fileSystem,
                                                    networkUtil: StubNetworkUtil(),
                                                    posterExtractor: StubPosterExtractor(succeeds: posterSucceeds),
                                                    retention: retention,
                                                    isImageCaptureDebug: isImageCaptureDebug,
                                                    installsNotificationDelegate: false,
                                                    debugCaptureDelay: .zero,
                                                    cameraAccessNotice: cameraNotice)
        return ThiefManager(settings: settings, dependencies: dependencies, triggerManager: StubTriggerManager(), logger: logger)
    }

    // MARK: - Settings

    func testFreshInstallDefaults() {
        let fresh = MockAppSettings()

        XCTAssertEqual(fresh.snapshot.outputType, .photo)
        XCTAssertEqual(fresh.snapshot.videoDuration, 3)
        XCTAssertEqual(fresh.snapshot.outputSize, .original)
        XCTAssertEqual(fresh.snapshot.quality, .high)
        XCTAssertEqual(fresh.retention.keepFiles, .oneWeek)
    }

    func testSnapshotSettingsRoundTripPerOutputSize() throws {
        let expectedRawValues = ["Original", "1/2", "1/4"]
        for (size, expected) in zip(CameraSnapConfiguration.OutputSize.allCases, expectedRawValues) {
            var original = SnapshotSettings()
            original.outputSize = size

            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(SnapshotSettings.self, from: data)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

            XCTAssertEqual(decoded, original)
            XCTAssertEqual(json["outputSize"] as? String, expected)
        }
    }

    func testLegacySettingsKeepQualityAndIgnoreResolution() throws {
        for resolution in ["full", "half", "quarter"] {
            let json = Data(#"{"quality":50,"resolution":"\#(resolution)"}"#.utf8)

            let decoded = try JSONDecoder().decode(SnapshotSettings.self, from: json)

            XCTAssertEqual(decoded.quality, .medium, resolution)
            XCTAssertEqual(decoded.outputSize, .original, resolution)
            XCTAssertEqual(decoded.outputType, .photo, resolution)
            XCTAssertEqual(decoded.videoDuration, 3, resolution)
        }
    }

    // MARK: - Photo path

    func testPhotoPathSendsOneStillRecord() async throws {
        settings.snapshot.quality = .low
        let sut = makeSUT()

        let captured = await sut.detectedTrigger(for: .onWakeUp)

        XCTAssertTrue(captured)
        XCTAssertEqual(notificationManager.sent.count, 1)
        let dto = try XCTUnwrap(notificationManager.sent.first)
        XCTAssertEqual(dto.triggerType, .onWakeUp)
        XCTAssertNotNil(dto.snapshot)
        XCTAssertNil(dto.videoURL)
        XCTAssertEqual(dto.compressionFactor, SnapshotQuality.low.compressionFactor)
        let filePath = try XCTUnwrap(dto.filePath)
        XCTAssertEqual(filePath.pathExtension, "jpeg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
        XCTAssertEqual(database.invokedSendCount, 1)
        XCTAssertTrue(database.invokedSendParameters?.thiefDto === dto)
        XCTAssertTrue(camera.videoRequests.isEmpty)
    }

    func testOutputSizePassesUnchangedToCamera() async {
        for size in CameraSnapConfiguration.OutputSize.allCases {
            settings.snapshot.outputSize = size
            settings.snapshot.outputType = .photo
            let sut = makeSUT()
            _ = await sut.detectedTrigger(for: .onWakeUp)
            settings.snapshot.outputType = .video
            _ = await sut.detectedTrigger(for: .onWakeUp)

            XCTAssertEqual(camera.photoConfigurations.last?.imageSize, size)
            XCTAssertEqual(camera.photoConfigurations.last?.videoSize, size)
            XCTAssertEqual(camera.videoRequests.last?.configuration.imageSize, size)
            XCTAssertEqual(camera.videoRequests.last?.configuration.videoSize, size)
        }
    }

    func testSaveToDiskSettingReachesCamera() async {
        settings.sync.isSaveSnapshotToDisk = true
        let sut = makeSUT()

        _ = await sut.detectedTrigger(for: .onWakeUp)

        XCTAssertEqual(camera.photoConfigurations.last?.isSaveToFile, true)
    }

    // MARK: - Video path

    func testVideoPathRecordsRequestedDuration() async throws {
        settings.snapshot.outputType = .video
        settings.snapshot.videoDuration = 3
        let sut = makeSUT()

        let captured = await sut.detectedTrigger(for: .logedIn)

        XCTAssertTrue(captured)
        XCTAssertEqual(camera.videoRequests.count, 1)
        XCTAssertEqual(camera.videoRequests.first?.seconds, 3)
        let dto = try XCTUnwrap(notificationManager.sent.first)
        XCTAssertEqual(dto.videoURL, camera.videoRequests.first?.url)
        XCTAssertEqual(dto.videoURL?.pathExtension, "mov")
        XCTAssertNotNil(dto.snapshot)
        let poster = try XCTUnwrap(dto.filePath)
        XCTAssertEqual(poster.deletingPathExtension().lastPathComponent, dto.videoURL?.deletingPathExtension().lastPathComponent)
        XCTAssertEqual(poster.deletingLastPathComponent(), fileSystem.directory)
        XCTAssertTrue(camera.photoConfigurations.isEmpty)
    }

    func testPosterFailureUsesPhotoAsRecordStill() async throws {
        settings.snapshot.outputType = .video
        posterSucceeds = false
        let sut = makeSUT()

        _ = await sut.detectedTrigger(for: .logedIn)

        let dto = try XCTUnwrap(notificationManager.sent.first)
        XCTAssertNotNil(dto.videoURL)
        XCTAssertNotNil(dto.snapshot)
        XCTAssertEqual(camera.photoConfigurations.count, 1)
    }

    func testVideoDurationBounds() async {
        XCTAssertTrue(SnapshotSettings.videoDurationRange.contains(1))
        XCTAssertTrue(SnapshotSettings.videoDurationRange.contains(5))
        XCTAssertFalse(SnapshotSettings.videoDurationRange.contains(0))
        XCTAssertFalse(SnapshotSettings.videoDurationRange.contains(6))

        settings.snapshot.outputType = .video
        for seconds in [0, 6] {
            settings.snapshot.videoDuration = seconds
            let sut = makeSUT()
            _ = await sut.detectedTrigger(for: .onWakeUp)
        }
        XCTAssertTrue(camera.videoRequests.isEmpty)
        XCTAssertEqual(camera.photoConfigurations.count, 2)

        for seconds in [1, 5] {
            settings.snapshot.videoDuration = seconds
            let sut = makeSUT()
            _ = await sut.detectedTrigger(for: .onWakeUp)
        }
        XCTAssertEqual(camera.videoRequests.map(\.seconds), [1, 5])
    }

    func testEveryVideoErrorFallsBackToPhoto() async throws {
        let cases: [(CameraSnapVideoError, String)] = [
            (.invalidDuration, "invalidDuration"),
            (.deviceUnavailable, "deviceUnavailable"),
            (.sessionSetupFailed, "sessionSetupFailed"),
            (.recordingInProgress, "recordingInProgress"),
            (.destinationUnavailable, "destinationUnavailable"),
            (.writerFailed, "writerFailed"),
            (.captureTimedOut, "captureTimedOut"),
            (.finalizationFailed, "finalizationFailed")
        ]
        settings.snapshot.outputType = .video
        for (error, name) in cases {
            camera = FakeCamera()
            camera.videoResult = .failure(error)
            notificationManager = MockNotificationManager()
            let sut = makeSUT()

            let captured = await sut.detectedTrigger(for: .onWakeUp)

            XCTAssertTrue(captured, name)
            XCTAssertEqual(camera.photoConfigurations.count, 1, name)
            let dto = try XCTUnwrap(notificationManager.sent.first, name)
            XCTAssertNil(dto.videoURL, name)
            XCTAssertNotNil(dto.snapshot, name)
            XCTAssertTrue(logger.messages.contains { $0.contains("Video recording failed: \(name)") }, name)
        }
    }

    func testTriggerDuringRecordingQueuesOneStillAfterIt() async throws {
        settings.snapshot.outputType = .video
        camera.holdsRecording = true
        let sut = makeSUT()

        let first = Task { await sut.detectedTrigger(for: .onWakeUp) }
        await waitUntil { self.camera.isHoldingRecording }
        let second = Task { await sut.detectedTrigger(for: .logedIn) }
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        let coalesced = await sut.detectedTrigger(for: .usbConnected)
        XCTAssertFalse(coalesced)
        XCTAssertTrue(camera.photoConfigurations.isEmpty, "no capture may start during the recording")

        camera.releaseRecording()
        let firstResult = await first.value
        let secondResult = await second.value

        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertEqual(camera.videoRequests.count, 1)
        XCTAssertEqual(camera.photoConfigurations.count, 1)
        XCTAssertEqual(notificationManager.sent.count, 2)
        let video = try XCTUnwrap(notificationManager.sent.first { $0.videoURL != nil })
        let still = try XCTUnwrap(notificationManager.sent.first { $0.videoURL == nil })
        XCTAssertEqual(video.triggerType, .onWakeUp)
        XCTAssertEqual(still.triggerType, .logedIn)
        XCTAssertNotEqual(video, still)
    }

    // MARK: - Camera access

    func testDeniedCameraSkipsCaptureAndNotifiesOnce() async {
        camera.isAccessDenied = true
        let sut = makeSUT()

        let first = await sut.detectedTrigger(for: .onWakeUp)
        let second = await sut.detectedTrigger(for: .logedIn)

        XCTAssertFalse(first)
        XCTAssertFalse(second)
        XCTAssertTrue(camera.photoConfigurations.isEmpty)
        XCTAssertTrue(camera.videoRequests.isEmpty)
        XCTAssertTrue(notificationManager.sent.isEmpty)
        XCTAssertEqual(cameraNotice.count, 1)
        XCTAssertTrue(logger.messages.contains { $0.contains("Camera access is denied") })
    }

    // MARK: - Debug branch

    func testImageCaptureDebugSkipsCamera() async throws {
        let sut = makeSUT(isImageCaptureDebug: true)

        let captured = await sut.detectedTrigger(for: .onWakeUp)

        XCTAssertTrue(captured)
        XCTAssertTrue(camera.photoConfigurations.isEmpty)
        XCTAssertTrue(camera.videoRequests.isEmpty)
        let dto = try XCTUnwrap(notificationManager.sent.first)
        XCTAssertEqual(dto.triggerType, .debug)
        XCTAssertNotNil(dto.snapshot)
    }

    // MARK: - Retention call sites

    func testLaunchRunsRetention() async {
        _ = makeSUT()

        await waitUntil { self.retention.launchCount == 1 }

        XCTAssertEqual(retention.launchCount, 1)
    }

    func testIncidentPassesDeliveryReportToRetention() async throws {
        let report = DeliveryReport(outcomes: [.iCloud: .confirmed])
        notificationManager.report = report
        let sut = makeSUT()

        _ = await sut.detectedTrigger(for: .onWakeUp)

        XCTAssertEqual(retention.incidents.count, 1)
        XCTAssertEqual(retention.incidents.first?.report, report)
        XCTAssertTrue(try XCTUnwrap(retention.incidents.first?.dto) === notificationManager.sent.first)
    }

    func testApplyRetentionPolicyRunsRetention() async {
        let sut = makeSUT()

        sut.applyRetentionPolicy()

        await waitUntil { self.retention.settingChangedCount == 1 }
        XCTAssertEqual(retention.settingChangedCount, 1)
    }

    // MARK: - History

    func testShowSnapshotWithPrunedFileLogsAndDoesNotCrash() throws {
        let date = Date()
        let missing = fileSystem.directory.appendingPathComponent("pruned.jpeg")
        let record = try XCTUnwrap(DatabaseDto(with: ThiefDto(triggerType: .onWakeUp, snapshot: .testImage(), filePath: missing, date: date)))
        database.stubbedLatestImages = [record]
        let sut = makeSUT()

        sut.showSnapshot(identifier: Date.defaultFormat.string(from: date))

        XCTAssertEqual(logger.infoMessage, "The file of the selected record is no longer on disk")
    }
}

// MARK: - Source Info

// @source-file: Source/Managers/ThiefManager.swift
