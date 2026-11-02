//
//  CameraCapturing.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import AVFoundation
import CameraSnap
import UserNotifications

/// Per-capture camera settings copied into CameraSnap before each call.
struct CaptureConfiguration: Sendable, Equatable {
    var imageSize: CameraSnapConfiguration.OutputSize
    var videoSize: CameraSnapConfiguration.OutputSize
    var isSaveToFile: Bool
}

/// The camera as `ThiefManager` uses it; production wraps CameraSnap, tests inject a fake.
@MainActor
protocol CameraCapturing: AnyObject {
    var isRecording: Bool { get }

    /// True when the user denied or a profile restricted camera access; capturing then only fails.
    var isAccessDenied: Bool { get }

    /// The file name stem for a capture taken at `date`.
    func fileKey(for date: Date) -> String

    func capturePhoto(_ configuration: CaptureConfiguration) async -> NSImage?

    /// Records a silent movie to `url`, which must not exist yet.
    func recordVideo(seconds: Int, to url: URL, _ configuration: CaptureConfiguration) async -> Result<URL, CameraSnapVideoError>
}

/// Holds one `CameraSnap` for the app's lifetime so a recording blocks other captures on the same session.
@MainActor
final class CameraSnapCamera: CameraCapturing {
    private let cameraSnap = CameraSnap()

    private let photoTimeout: Duration

    private let logger: LogProtocol

    private(set) var isRecording = false

    var isAccessDenied: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: true
        case .authorized, .notDetermined: false
        @unknown default: false
        }
    }

    init(photoTimeout: Duration = .seconds(10), logger: LogProtocol = Log(category: .camera)) {
        self.photoTimeout = photoTimeout
        self.logger = logger
    }

    /// Where "Save snapshot to disk" copies land, and the name prefix they carry.
    var saveToDiskRoot: RetentionRoot {
        .captureCopies(cameraSnap.cameraSnapConfiguration.rootDir, namePrefix: cameraSnap.cameraSnapConfiguration.filePrefix)
    }

    func fileKey(for date: Date) -> String {
        cameraSnap.cameraSnapConfiguration.dateFormatter.string(from: date)
    }

    func capturePhoto(_ configuration: CaptureConfiguration) async -> NSImage? {
        apply(configuration)
        let result = OneShotResult<NSImage>()
        var watchdog: Task<Void, Never>?
        await withCheckedContinuation { continuation in
            result.install(continuation)
            watchdog = Task { [photoTimeout, logger] in
                do {
                    try await Task.sleep(for: photoTimeout)
                } catch {
                    return
                }
                if result.finish(nil) {
                    logger.error("Photo capture timed out")
                }
            }
            cameraSnap.fetchSnapshot { model in
                result.finish(model.images.last)
            }
        }
        watchdog?.cancel()
        return result.value
    }

    func recordVideo(seconds: Int, to url: URL, _ configuration: CaptureConfiguration) async -> Result<URL, CameraSnapVideoError> {
        apply(configuration)
        isRecording = true
        defer { isRecording = false }
        let result = OneShotResult<Result<URL, CameraSnapVideoError>>()
        await withCheckedContinuation { continuation in
            result.install(continuation)
            cameraSnap.recordVideo(for: TimeInterval(seconds), to: url) { outcome in
                result.finish(outcome.map(\.url))
            }
        }
        return result.value ?? .failure(.captureTimedOut)
    }

    private func apply(_ configuration: CaptureConfiguration) {
        cameraSnap.cameraSnapConfiguration.imageSize = configuration.imageSize
        cameraSnap.cameraSnapConfiguration.videoSize = configuration.videoSize
        cameraSnap.cameraSnapConfiguration.isSaveToFile = configuration.isSaveToFile
        // CameraSnap caches the first device it finds; refresh it so a camera attached later is used.
        cameraSnap.defaultDevice = cameraSnap.session.devices.first
    }
}

/// Resumes its continuation exactly once; later results (a late callback after the watchdog) are dropped.
@MainActor
private final class OneShotResult<Value> {
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var value: Value?

    func install(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    @discardableResult
    func finish(_ value: Value?) -> Bool {
        guard let continuation else { return false }
        self.continuation = nil
        self.value = value
        continuation.resume()
        return true
    }
}

/// Tells the user that a trigger could not capture because camera access is off.
@MainActor
protocol CameraAccessNoticePresenting {
    func presentCameraAccessDenied() async
}

/// A local notification only: a window could be seen by whoever triggered the capture.
@MainActor
final class CameraAccessNotificationPresenter: CameraAccessNoticePresenting {
    private let logger: LogProtocol

    init(logger: LogProtocol = Log(category: .camera)) {
        self.logger = logger
    }

    func presentCameraAccessDenied() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else {
            logger.info("Camera access notice not shown: notifications are not allowed")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("CameraAccessDeniedTitle", comment: "")
        content.body = NSLocalizedString("CameraAccessDeniedBody", comment: "")
        do {
            try await center.add(UNNotificationRequest(identifier: "CameraAccessDenied", content: content, trigger: nil))
        } catch {
            logger.error("Camera access notification failed")
        }
    }
}
