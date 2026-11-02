//
//  MockCaptureDependencies.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CameraSnap
@testable import Lock_Watcher

extension NSImage {
    /// An image with real pixels; `NSImage(size:)` alone encodes to empty JPEG data.
    static func testImage(size: NSSize = NSSize(width: 8, height: 8)) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
            return true
        }
    }
}

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// Scripted camera: records every request; a recording can be held open until `releaseRecording()`.
@MainActor
final class FakeCamera: CameraCapturing {
    var photo: NSImage? = .testImage()
    var videoResult: Result<Void, CameraSnapVideoError> = .success(())
    var holdsRecording = false
    var isAccessDenied = false

    private(set) var isRecording = false
    private(set) var photoConfigurations: [CaptureConfiguration] = []
    private(set) var videoRequests: [(seconds: Int, url: URL, configuration: CaptureConfiguration)] = []
    private var heldRecording: CheckedContinuation<Void, Never>?
    private var keyCounter = 0

    var isHoldingRecording: Bool {
        heldRecording != nil
    }

    func fileKey(for date: Date) -> String {
        keyCounter += 1
        return "capture-\(keyCounter)"
    }

    func capturePhoto(_ configuration: CaptureConfiguration) async -> NSImage? {
        photoConfigurations.append(configuration)
        return photo
    }

    func recordVideo(seconds: Int, to url: URL, _ configuration: CaptureConfiguration) async -> Result<URL, CameraSnapVideoError> {
        videoRequests.append((seconds, url, configuration))
        isRecording = true
        defer { isRecording = false }
        if holdsRecording {
            await withCheckedContinuation { heldRecording = $0 }
        }
        switch videoResult {
        case .success:
            try? Data("movie".utf8).write(to: url)
            return .success(url)
        case .failure(let error):
            return .failure(error)
        }
    }

    func releaseRecording() {
        heldRecording?.resume()
        heldRecording = nil
    }
}

struct StubPosterExtractor: PosterFrameExtracting {
    var succeeds = true

    func posterImage(from movie: URL) async -> sending NSImage? {
        succeeds ? .testImage() : nil
    }
}

/// Writes into a private temporary folder instead of ~/Documents.
final class TemporaryFileSystemUtil: FileSystemUtilProtocol {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LockWatcherTests-\(UUID().uuidString)", isDirectory: true)

    init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var incidentDirectory: URL? {
        directory
    }

    func store(image: NSImage, forKey key: String, quality: CGFloat) -> URL? {
        let url = directory.appendingPathComponent(key).appendingPathExtension("jpeg")
        let data = image.jpegData(quality: quality)
        guard !data.isEmpty, (try? data.write(to: url)) != nil else { return nil }
        return url
    }

    func movieURL(forKey key: String) -> URL? {
        directory.appendingPathComponent(key).appendingPathExtension("mov")
    }

    func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }
}

struct StubNetworkUtil: NetworkUtilProtocol {
    func getIFAddresses() -> String {
        "192.0.2.1"
    }

    func getTraceRoute(host: String, complete: @escaping Commons.StringClosure) {
        complete("trace")
    }
}

final class StubTriggerManager: TriggerManagerProtocol, @unchecked Sendable {
    func start(settings: AppSettingsProtocol?, triggerBlock: @escaping MainActorTriggerClosure) {}

    func stop() {}
}

/// Records every sent record and answers with `report`.
final class MockNotificationManager: NotificationManagerProtocol, @unchecked Sendable {
    var report = DeliveryReport.empty
    private(set) var sent: [ThiefDto] = []

    func send(_ thiefDto: ThiefDto) async -> DeliveryReport {
        sent.append(thiefDto)
        return report
    }

    func completeDropboxAuthWith(url: URL) async -> String {
        ""
    }
}

@MainActor
final class RetentionManagerSpy: RetentionManaging {
    private(set) var launchCount = 0
    private(set) var incidents: [(dto: ThiefDto, report: DeliveryReport)] = []
    private(set) var settingChangedCount = 0

    func applicationDidLaunch() async {
        launchCount += 1
    }

    func incidentRecorded(_ thiefDto: ThiefDto, report: DeliveryReport) async {
        incidents.append((thiefDto, report))
    }

    func retentionSettingChanged() async {
        settingChangedCount += 1
    }
}

actor PrunerSpy: RetentionPruning {
    private(set) var hasOldFiles = false
    private(set) var prunes: [(policy: RetentionPolicy, now: Date)] = []
    private(set) var removedStems: [String] = []

    func setHasOldFiles(_ value: Bool) {
        hasOldFiles = value
    }

    func prune(policy: RetentionPolicy, now: Date) throws -> RetentionReport {
        prunes.append((policy, now))
        return RetentionReport()
    }

    func removeRecordFiles(stem: String) -> RetentionReport {
        removedStems.append(stem)
        return RetentionReport(deleted: 2)
    }

    func hasFiles(createdBefore date: Date) -> Bool {
        hasOldFiles
    }
}

final class FixedDateProvider: DateProviding, @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
final class RetentionNoticeSpy: RetentionNoticePresenting {
    private(set) var notices: [(period: RetentionPeriod, firstDeletion: Date)] = []
    var onPresent: (() -> Void)?

    func presentUpgradeNotice(period: RetentionPeriod, firstDeletion: Date) async {
        onPresent?()
        notices.append((period, firstDeletion))
    }
}

/// A notifier that succeeds or throws `error`.
final class MockNotifier: NotifierProtocol, DropboxNotifierProtocol, @unchecked Sendable {
    var error: Error?
    private(set) var sentCount = 0

    func register(with settings: AppSettingsProtocol) {}

    func send(_ thiefDto: ThiefDto) async throws {
        sentCount += 1
        if let error {
            throw error
        }
    }

    func completeDropboxAuthWith(url: URL) async -> String {
        ""
    }
}

@MainActor
final class CameraAccessNoticeSpy: CameraAccessNoticePresenting {
    private(set) var count = 0

    func presentCameraAccessDenied() async {
        count += 1
    }
}
