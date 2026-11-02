//
//  ThiefManager.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CameraSnap
import Combine
import CoreLocation
import UserNotifications

/// A protocol that outlines the responsibilities of the `ThiefManager` class.
///
/// - Important: `@MainActor` isolation is required because:
///   - Interacts with `CLLocationManager` (requires main thread)
///   - Implements `UNUserNotificationCenterDelegate` (requires main thread)
///   - Manages `TriggerManager` which is `@MainActor`
@MainActor
protocol ThiefManagerProtocol: Sendable {
    func detectedTrigger() async -> Bool

    func restartWatching()

    var databaseManager: any DatabaseManagerProtocol { get }

    func setupLocationManager(enable: Bool)

    func showSnapshot(identifier: String)

    func completeDropboxAuthWith(url: URL) async -> String

    var dropboxUserNameUpdates: AsyncStream<String> { get }

    /// Cleans all data: resets database and app settings to defaults.
    func cleanAll()

    /// Re-runs retention after the "Keep files" setting changed; returns at once.
    func applyRetentionPolicy()
}

/// Everything `ThiefManager` talks to, so tests can replace each collaborator.
struct ThiefManagerDependencies {
    var camera: any CameraCapturing
    var notificationManager: any NotificationManagerProtocol
    var databaseManager: any DatabaseManagerProtocol
    var fileSystemUtil: any FileSystemUtilProtocol
    var networkUtil: any NetworkUtilProtocol
    var posterExtractor: any PosterFrameExtracting
    var retention: any RetentionManaging
    var isImageCaptureDebug: Bool
    /// False in tests, which must not take over the app's notification delegate.
    var installsNotificationDelegate: Bool
    var debugCaptureDelay: Duration
    var cameraAccessNotice: any CameraAccessNoticePresenting

    @MainActor
    static func live(settings: AppSettingsProtocol) -> ThiefManagerDependencies {
        let camera = CameraSnapCamera()
        let fileSystemUtil = FileSystemUtil()
        let retention: any RetentionManaging = if LaunchEnvironment.isHostingTests {
            DisabledRetentionManager()
        } else {
            RetentionManager(settings: settings,
                             pruner: RetentionPruner.live(incidentDirectory: fileSystemUtil.incidentDirectory, cameraSnapCopies: camera.saveToDiskRoot),
                             noticePresenter: RetentionNoticePresenter())
        }
        return ThiefManagerDependencies(camera: camera,
                                        notificationManager: NotificationManager(settings: settings),
                                        databaseManager: DatabaseManager(settings: settings),
                                        fileSystemUtil: fileSystemUtil,
                                        networkUtil: NetworkUtil(),
                                        posterExtractor: AVPosterFrameExtractor(),
                                        retention: retention,
                                        isImageCaptureDebug: AppSettings.isImageCaptureDebug,
                                        installsNotificationDelegate: true,
                                        debugCaptureDelay: .seconds(1),
                                        cameraAccessNotice: CameraAccessNotificationPresenter())
    }
}

/// The main class responsible for managing and responding to various triggers indicating potential unauthorized access.
///
/// This class is `@MainActor` isolated because:
/// - It implements `CLLocationManagerDelegate` which must be called on main thread
/// - It implements `UNUserNotificationCenterDelegate` which must be called on main thread
/// - It manages `TriggerManager` which is `@MainActor` isolated
@MainActor
final class ThiefManager: NSObject, ThiefManagerProtocol {
    // MARK: - Typealiases
    
    typealias WatchBlock = Commons.ThiefClosure

    /// What the camera produced for one trigger, before it is stored.
    private enum CapturedMedia {
        case photo(NSImage)
        case video(movie: URL, poster: NSImage?)
    }

    // MARK: - Dependency injection
    
    private var triggerManager: TriggerManagerProtocol
    
    private let notificationManager: any NotificationManagerProtocol
    
    private var watchBlock: WatchBlock = { _ in }
    
    private(set) var settings: AppSettingsProtocol
    
    private var logger: LogProtocol

    private let camera: any CameraCapturing

    private let posterExtractor: any PosterFrameExtracting

    private let retention: any RetentionManaging

    private let isImageCaptureDebug: Bool

    private let debugCaptureDelay: Duration

    private let cameraAccessNotice: any CameraAccessNoticePresenting

    /// The denial notice is posted once per launch, not on every trigger.
    private var hasReportedCameraAccessDenied = false

    // MARK: - Variables
    
    private var lastThiefDetection: TriggerType = .setup

    /// True while a trigger owns the camera; covers taking the photo or recording plus its poster, not sending.
    private var isCameraBusy = false

    /// Triggers waiting for the camera, resumed one at a time as it is handed over.
    private var cameraWaiters: [CheckedContinuation<Void, Never>] = []

    /// One still is queued per busy period; further triggers in that period are coalesced.
    private var isStillQueued = false
    
    /// store ThiefDto in database
    ///
    var databaseManager: any DatabaseManagerProtocol
    
    /// fetch ip address and trace route
    ///
    private let networkUtil: any NetworkUtilProtocol
    
    private let fileSystemUtil: any FileSystemUtilProtocol
    
    /// fetch current location
    ///
    private(set) var locationManager = CLLocationManager()
    private var coordinate: CLLocationCoordinate2D?

    /// AsyncStream for Dropbox username updates
    private var dropboxUserNameContinuation: AsyncStream<String>.Continuation?

    /// Provides an AsyncStream of Dropbox username updates
    var dropboxUserNameUpdates: AsyncStream<String> {
        AsyncStream { continuation in
            self.dropboxUserNameContinuation = continuation
        }
    }
    
    // MARK: - initialiser
    
    init(settings: AppSettingsProtocol,
         dependencies: ThiefManagerDependencies? = nil,
         triggerManager: TriggerManagerProtocol = TriggerManager(),
         logger: LogProtocol = Log(category: .thiefManager),
         watchBlock: @escaping WatchBlock = { _ in })
    {
        let dependencies = dependencies ?? .live(settings: settings)
        self.settings = settings
        self.triggerManager = triggerManager
        self.watchBlock = watchBlock
        self.logger = logger
        camera = dependencies.camera
        notificationManager = dependencies.notificationManager
        databaseManager = dependencies.databaseManager
        fileSystemUtil = dependencies.fileSystemUtil
        networkUtil = dependencies.networkUtil
        posterExtractor = dependencies.posterExtractor
        retention = dependencies.retention
        isImageCaptureDebug = dependencies.isImageCaptureDebug
        debugCaptureDelay = dependencies.debugCaptureDelay
        cameraAccessNotice = dependencies.cameraAccessNotice
        
        super.init()
        
        if settings.options.addLocationToSnapshot {
            setupLocationManager(enable: true)
        }
        
        startWatching(watchBlock)
        
        if dependencies.installsNotificationDelegate {
            UNUserNotificationCenter.current().delegate = self
        }

        let retention = retention
        Task {
            await retention.applicationDidLaunch()
        }
    }
    
    // MARK: - public
    
    /// These methods define how the manager should behave when various events occur.
    /// Sets up the location manager, either enabling or disabling location updates.
    func setupLocationManager(enable: Bool) {
        if enable {
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
        } else {
            locationManager.delegate = nil
            locationManager.stopUpdatingLocation()
        }
    }
    
    /// Stops watching for triggers.
    func stopWatching() {
        logger.debug("Stop Watching")
        triggerManager.stop()
    }
    
    /// Restarts the trigger watching mechanism
    func restartWatching() {
        startWatching(watchBlock)
    }

    /// Detects and processes any triggers.
    func detectedTrigger() async -> Bool {
        await detectedTrigger(for: lastThiefDetection)
    }

    /// Captures and processes one incident; returns false when nothing was captured or the trigger was coalesced.
    func detectedTrigger(for type: TriggerType) async -> Bool {
        logger.debug("Detected triggered action: \(type.rawValue)")

        if isImageCaptureDebug {
            guard let image = NSImage(systemSymbolName: "swift", accessibilityDescription: nil) else { return false }
            await processCapture(.photo(image), triggerType: .debug, date: Date())
            try? await Task.sleep(for: debugCaptureDelay)
            return true
        }

        guard !camera.isAccessDenied else {
            logger.error("Camera access is denied; trigger \(type.rawValue) captured nothing")
            if !hasReportedCameraAccessDenied {
                hasReportedCameraAccessDenied = true
                await cameraAccessNotice.presentCameraAccessDenied()
            }
            return false
        }

        let stillOnly: Bool
        if isCameraBusy {
            guard !isStillQueued else {
                logger.info("Trigger \(type.rawValue) coalesced into the still queued after the current capture")
                return false
            }
            isStillQueued = true
            await waitForCamera()
            isStillQueued = false
            stillOnly = true
        } else {
            isCameraBusy = true
            stillOnly = false
        }

        let captured: CapturedMedia? = if stillOnly || settings.snapshot.outputType == .photo {
            await capturePhoto()
        } else {
            await captureVideo()
        }
        releaseCamera()

        guard let captured else {
            logger.error("Camera returned nothing for trigger \(type.rawValue)")
            return false
        }

        // Taken after the camera is released, so a queued still never shares a date (ThiefDto equality) with the record before it.
        await processCapture(captured, triggerType: type, date: Date())
        return true
    }
    
    /// Opens a snapshot based on the given identifier.
    func showSnapshot(identifier: String) {
        guard let filePath = databaseManager.latestImages.first(where: { Date.defaultFormat.string(from: $0.date) == identifier })?.path else {
            return
        }

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            logger.info("The file of the selected record is no longer on disk")
            return
        }

        NSWorkspace.shared.open(filePath)
    }

    /// Cleans all data: resets database and app settings to defaults.
    func cleanAll() {
        databaseManager.cleanAll()
        settings.resetToDefaults()
        restartWatching()
    }

    func applyRetentionPolicy() {
        let retention = retention
        Task {
            await retention.retentionSettingChanged()
        }
    }

    // MARK: - private

    private var captureConfiguration: CaptureConfiguration {
        CaptureConfiguration(imageSize: settings.snapshot.outputSize,
                             videoSize: settings.snapshot.outputSize,
                             isSaveToFile: settings.sync.isSaveSnapshotToDisk)
    }

    private func waitForCamera() async {
        await withCheckedContinuation { continuation in
            cameraWaiters.append(continuation)
        }
    }

    /// Hands the camera to the next waiter instead of freeing it, so a new trigger cannot overtake a queued one.
    private func releaseCamera() {
        if cameraWaiters.isEmpty {
            isCameraBusy = false
        } else {
            cameraWaiters.removeFirst().resume()
        }
    }

    private func capturePhoto() async -> CapturedMedia? {
        await camera.capturePhoto(captureConfiguration).map { .photo($0) }
    }

    private func captureVideo() async -> CapturedMedia? {
        let seconds = settings.snapshot.videoDuration
        guard SnapshotSettings.videoDurationRange.contains(seconds) else {
            logger.error("Video duration \(seconds) s is outside \(SnapshotSettings.videoDurationRange); taking a photo instead")
            return await capturePhoto()
        }

        guard let movieURL = fileSystemUtil.movieURL(forKey: camera.fileKey(for: Date())) else {
            logger.error("Incident folder unavailable for the video; taking a photo instead")
            return await capturePhoto()
        }

        switch await camera.recordVideo(seconds: seconds, to: movieURL, captureConfiguration) {
        case .success(let movie):
            if let poster = await posterExtractor.posterImage(from: movie) {
                return .video(movie: movie, poster: poster)
            }
            logger.error("Poster frame unavailable; taking a photo as the record still")
            return await .video(movie: movie, poster: camera.capturePhoto(captureConfiguration))
        case .failure(let error):
            await recover(from: error)
            return await capturePhoto()
        }
    }

    /// Every case falls back to a photo; no `default:`, so a new CameraSnap case fails the build.
    private func recover(from error: CameraSnapVideoError) async {
        switch error {
        case .invalidDuration: logVideoFailure("invalidDuration")
        case .deviceUnavailable: logVideoFailure("deviceUnavailable")
        case .sessionSetupFailed: logVideoFailure("sessionSetupFailed")
        case .recordingInProgress:
            logVideoFailure("recordingInProgress")
            await waitUntilCameraStopsRecording()
        case .destinationUnavailable: logVideoFailure("destinationUnavailable")
        case .writerFailed: logVideoFailure("writerFailed")
        case .captureTimedOut: logVideoFailure("captureTimedOut")
        case .finalizationFailed: logVideoFailure("finalizationFailed")
        }
    }

    private func logVideoFailure(_ reason: String) {
        logger.error("Video recording failed: \(reason); taking a photo instead")
    }

    /// Bounded by CameraSnap's own worst case for a 5 s clip (3 × duration + 2 s, plus warm-up).
    private func waitUntilCameraStopsRecording() async {
        let deadline = ContinuousClock.now + .seconds(20)
        while camera.isRecording, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Stores the capture, sends it, records it, and runs retention.
    private func processCapture(_ captured: CapturedMedia, triggerType: TriggerType, date: Date) async {
        let snapshot: NSImage?
        let filePath: URL?
        let videoURL: URL?
        let quality: CGFloat
        switch captured {
        case .photo(let image):
            quality = settings.snapshot.quality.compressionFactor
            guard let path = fileSystemUtil.store(image: image, forKey: camera.fileKey(for: date), quality: quality) else {
                logger.error("wrong file path")
                return
            }
            snapshot = image
            filePath = path
            videoURL = nil
        case .video(let movie, let poster):
            quality = SnapshotQuality.high.compressionFactor
            snapshot = poster
            filePath = poster.flatMap { fileSystemUtil.store(image: $0, forKey: movie.deletingPathExtension().lastPathComponent, quality: quality) }
            videoURL = movie
        }

        let ipAddress: String? = if settings.options.addIPAddressToSnapshot {
            networkUtil.getIFAddresses()
        } else {
            nil
        }

        let traceRoute: String? = if settings.options.addTraceRouteToSnapshot {
            await withCheckedContinuation { continuation in
                networkUtil.getTraceRoute(host: settings.options.traceRouteServer) { traceRouteLog in
                    continuation.resume(returning: traceRouteLog)
                }
            }
        } else {
            nil
        }

        let dto = ThiefDto(
            triggerType: triggerType,
            coordinate: coordinate,
            ipAddress: ipAddress,
            traceRoute: traceRoute,
            snapshot: snapshot,
            filePath: filePath,
            videoURL: videoURL,
            compressionFactor: quality,
            date: date
        )

        let report = await notificationManager.send(dto)
        _ = databaseManager.send(dto)
        await retention.incidentRecorded(dto, report: report)

        watchBlock(dto)
    }
    
    /// Starts watching for triggers.
    private func startWatching(_ watchBlock: @escaping WatchBlock = { _ in }) {
        logger.debug("Start Watching")
        
        self.watchBlock = watchBlock
        triggerManager.start(settings: settings, triggerBlock: triggered)
    }
    
    private func triggered(_ type: TriggerType) {
        guard type != .setup else { return }

        lastThiefDetection = type
        Task {
            _ = await detectedTrigger(for: type)
        }
    }
    
    /// Completes Dropbox authentication.
    /// - Parameter url: The callback URL from Dropbox OAuth.
    /// - Returns: The display name of the authenticated user, or empty string on failure.
    func completeDropboxAuthWith(url: URL) async -> String {
        let name = await notificationManager.completeDropboxAuthWith(url: url)
        dropboxUserNameContinuation?.yield(name)
        return name
    }
}

/// Location Manager Delegate Methods
extension ThiefManager: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.debug("\(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var statusName = "Unknown"
        switch status {
        case .restricted:
            statusName = "restricted"
        case .denied:
            statusName = "denied"
        case .authorized:
            statusName = "authorised"
        case .notDetermined:
            statusName = "not yet determined"
        default:
            break
        }
        
        logger.debug("location manager auth status changed to: \(statusName)")
    }
}

/// User Notification Center Delegate Methods:
extension ThiefManager: @MainActor UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ centre: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        showSnapshot(identifier: identifier)
    }
}

/// Preview implementation of `ThiefManagerProtocol` for SwiftUI previews.
@MainActor
final class ThiefManagerPreview: ThiefManagerProtocol {
    var dropboxUserNameUpdates: AsyncStream<String> {
        AsyncStream { continuation in
            continuation.yield("")
            continuation.finish()
        }
    }

    func completeDropboxAuthWith(url: URL) async -> String {
        ""
    }

    func showSnapshot(identifier: String) {}

    func setupLocationManager(enable: Bool) {}

    func detectedTrigger() async -> Bool {
        true
    }

    func restartWatching() {}

    func cleanAll() {}

    func applyRetentionPolicy() {}

    var databaseManager: any DatabaseManagerProtocol = DatabaseManager(settings: AppSettingsPreview())
}
