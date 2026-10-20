//
//  LocationAuthorizationService.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import AppKit
import CoreLocation

@MainActor
protocol LocationAuthorizationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var isRequestPending: Bool { get }
    func requestAuthorization(completion: @escaping @MainActor (Bool) -> Void)
    func observeAuthorization(_ handler: @escaping @MainActor (CLAuthorizationStatus) -> Void) -> LocationAuthorizationObservation
    func refreshAuthorization()
}

@MainActor
final class LocationAuthorizationObservation {
    private var handler: (@MainActor (CLAuthorizationStatus) -> Void)?

    init(handler: @escaping @MainActor (CLAuthorizationStatus) -> Void) {
        self.handler = handler
    }

    func cancel() {
        handler = nil
    }

    func notify(_ status: CLAuthorizationStatus) {
        handler?(status)
    }
}

@MainActor
final class LocationAuthorizationService: NSObject, LocationAuthorizationProviding {
    private let manager: CLLocationManager?
    private let currentStatus: @MainActor () -> CLAuthorizationStatus
    private let requestPermission: @MainActor () -> Void
    private var pendingCompletions: [@MainActor (Bool) -> Void] = []
    private var observations: [WeakObservation] = []

    var authorizationStatus: CLAuthorizationStatus {
        currentStatus()
    }

    var isRequestPending: Bool {
        !pendingCompletions.isEmpty
    }

    override convenience init() {
        let manager = CLLocationManager()
        self.init(manager: manager, status: { manager.authorizationStatus }, request: { manager.requestWhenInUseAuthorization() })
    }

    private init(manager: CLLocationManager?, status: @escaping @MainActor () -> CLAuthorizationStatus, request: @escaping @MainActor () -> Void) {
        self.manager = manager
        currentStatus = status
        requestPermission = request
        super.init()
        manager?.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    convenience init(status: @escaping @MainActor () -> CLAuthorizationStatus, request: @escaping @MainActor () -> Void) {
        self.init(manager: nil, status: status, request: request)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        switch authorizationStatus {
        case .authorizedAlways:
            completion(true)
        case .notDetermined:
            let shouldRequest = pendingCompletions.isEmpty
            pendingCompletions.append(completion)
            if shouldRequest {
                requestPermission()
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    func observeAuthorization(_ handler: @escaping @MainActor (CLAuthorizationStatus) -> Void) -> LocationAuthorizationObservation {
        let observation = LocationAuthorizationObservation(handler: handler)
        observations.removeAll { $0.value == nil }
        observations.append(WeakObservation(value: observation))
        return observation
    }

    func refreshAuthorization() {
        authorizationDidChange()
    }

    func authorizationDidChange() {
        let status = authorizationStatus
        observations.removeAll { $0.value == nil }
        for observation in observations {
            observation.value?.notify(status)
        }

        guard status != .notDetermined, !pendingCompletions.isEmpty else { return }
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        for completion in completions {
            completion(status == .authorizedAlways)
        }
    }

    @objc
    private func applicationDidBecomeActive() {
        refreshAuthorization()
    }
}

extension LocationAuthorizationService: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationDidChange()
    }
}

@MainActor
private final class WeakObservation {
    weak var value: LocationAuthorizationObservation?

    init(value: LocationAuthorizationObservation) {
        self.value = value
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/SettingsViewModelTests.swift
