//
//  GeofenceListener.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import CoreLocation
import Foundation

/// A source of significant location changes and authorization updates.
@MainActor
protocol LocationMonitoring: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var isSignificantChangeAvailable: Bool { get }
    var onFix: ((CLLocation) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }

    func startSignificantChanges()
    func stopSignificantChanges()

    /// Asks for one fresh fix; the result arrives through `onFix`.
    func requestFix()
}

/// `LocationMonitoring` over a private `CLLocationManager`, so the geofence never shares the
/// snapshot location manager's delegate or monitoring state.
@MainActor
final class SignificantLocationMonitor: NSObject, LocationMonitoring {
    private let manager = CLLocationManager()
    private let logger: LogProtocol

    var onFix: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    init(logger: LogProtocol = Log(category: .geofenceListener)) {
        self.logger = logger
        super.init()
        manager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isSignificantChangeAvailable: Bool {
        CLLocationManager.significantLocationChangeMonitoringAvailable()
    }

    func startSignificantChanges() {
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopSignificantChanges() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    func requestFix() {
        manager.requestLocation()
    }
}

extension SignificantLocationMonitor: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        onFix?(fix)
    }

    /// Required by `requestLocation()`; only the error code is logged.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Geofence location request failed: code \((error as NSError).code)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }
}

/// Fix quality and distance rules for the geofence trigger.
enum GeofenceRule {
    static let threshold: CLLocationDistance = 500
    static let maxHorizontalAccuracy: CLLocationAccuracy = 1000

    /// Keeps a cached fix from an earlier day from becoming the baseline.
    static let maxFixAge: TimeInterval = 120

    static func isUsable(_ fix: CLLocation, now: Date) -> Bool {
        fix.horizontalAccuracy >= 0
            && fix.horizontalAccuracy <= maxHorizontalAccuracy
            && abs(fix.timestamp.timeIntervalSince(now)) <= maxFixAge
    }

    /// Subtracts the worse accuracy so Wi-Fi positioning jitter cannot reach the threshold.
    static func hasMoved(from baseline: CLLocation, to fix: CLLocation) -> Bool {
        let margin = max(baseline.horizontalAccuracy, fix.horizontalAccuracy)
        return fix.distance(from: baseline) - margin >= threshold
    }
}

/// Emits `.locationChanged` once per lock period when a fix received while locked is at least
/// `GeofenceRule.threshold` from the last fix received while unlocked.
///
/// `isRunning` is `true` only while significant-change monitoring is active: without location
/// authorization the stream stays open and monitoring starts when authorization arrives.
final class GeofenceListener: BaseListenerProtocol {
    // MARK: - Dependency injection

    private let logger: LogProtocol
    private let lockDetector: MacOSLockDetectorProtocol
    private let monitor: LocationMonitoring
    private let now: @MainActor () -> Date

    // MARK: - Variables

    private(set) var isRunning: Bool = false

    private var continuation: AsyncStream<ListenerEvent>.Continuation?
    private var cancellables: Set<AnyCancellable> = .init()
    private var gate = LockGraceGate(grace: 0)
    private var baseline: CLLocation?

    /// Lets a late `onTermination` from a replaced stream skip the newer stream's state.
    private var generation = 0

    // MARK: - Initializer

    init(logger: LogProtocol = Log(category: .geofenceListener),
         lockDetector: MacOSLockDetectorProtocol,
         monitor: LocationMonitoring = SignificantLocationMonitor(),
         now: @escaping @MainActor () -> Date = Date.init)
    {
        self.logger = logger
        self.lockDetector = lockDetector
        self.monitor = monitor
        self.now = now
    }

    // MARK: - Public Methods

    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("GeofenceListener Started")
        teardown()
        generation += 1
        let streamGeneration = generation

        return AsyncStream { continuation in
            self.continuation = continuation

            self.monitor.onFix = { [weak self] fix in
                self?.handleFix(fix)
            }
            self.monitor.onAuthorizationChange = { [weak self] status in
                self?.applyAuthorization(status)
            }
            self.lockDetector.isLockedPublisher
                .sink { [weak self] isLocked in
                    self?.handleTick(isLocked: isLocked)
                }
                .store(in: &self.cancellables)

            self.applyAuthorization(self.monitor.authorizationStatus)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup(generation: streamGeneration)
                }
            }
        }
    }

    func stop() {
        logger.debug("GeofenceListener Stopped")
        teardown()
    }

    // MARK: - Private Methods

    private func teardown() {
        let open = continuation
        continuation = nil
        open?.finish()
        reset()
    }

    private func cleanup(generation streamGeneration: Int) {
        guard streamGeneration == generation else { return }
        continuation = nil
        reset()
    }

    private func reset() {
        if isRunning {
            monitor.stopSignificantChanges()
        }
        isRunning = false
        monitor.onFix = nil
        monitor.onAuthorizationChange = nil
        cancellables.removeAll()
        gate = LockGraceGate(grace: 0)
        baseline = nil
    }

    /// `.authorizedAlways` is the only granted state on macOS; `.authorizedWhenInUse` is unavailable there.
    private func applyAuthorization(_ status: CLAuthorizationStatus) {
        guard continuation != nil else { return }

        guard status == .authorizedAlways, monitor.isSignificantChangeAvailable else {
            if isRunning {
                monitor.stopSignificantChanges()
                isRunning = false
            }
            logger.info("Geofence monitoring off: \(Self.reason(for: status, available: monitor.isSignificantChangeAvailable))")
            return
        }

        guard !isRunning else { return }
        monitor.startSignificantChanges()
        isRunning = true
        logger.info("Geofence monitoring on")

        if gate.lockState == .unlocked {
            monitor.requestFix()
        }
    }

    private func handleTick(isLocked: Bool) {
        guard gate.tick(isLocked: isLocked, now: now()) == .didUnlock else { return }

        // A failed post-unlock fix must leave no baseline from an earlier place.
        baseline = nil
        if isRunning {
            monitor.requestFix()
        }
    }

    private func handleFix(_ fix: CLLocation) {
        guard isRunning, GeofenceRule.isUsable(fix, now: now()) else { return }

        switch gate.lockState {
        case .unknown:
            return
        case .unlocked:
            baseline = fix
        case .locked:
            guard let baseline, GeofenceRule.hasMoved(from: baseline, to: fix), gate.fireNow() else { return }
            logger.info("Location changed while locked")
            continuation?.yield((.onGeofenceListener, .locationChanged))
        }
    }

    private static func reason(for status: CLAuthorizationStatus, available: Bool) -> String {
        guard available else { return "significant-change monitoring unavailable" }

        switch status {
        case .notDetermined: return "authorization not determined"
        case .restricted: return "authorization restricted"
        case .denied: return "authorization denied"
        case .authorizedAlways: return "authorized"
        @unknown default: return "authorization status \(status.rawValue)"
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/GeofenceListenerTests.swift
