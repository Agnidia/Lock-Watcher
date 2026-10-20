//
//  MockLocationAuthorizationService.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CoreLocation
@testable import Lock_Watcher

@MainActor
final class MockLocationAuthorizationService: LocationAuthorizationProviding {
    var authorizationStatus: CLAuthorizationStatus
    var requestCount = 0
    var refreshCount = 0
    var isRequestPending: Bool {
        !completions.isEmpty
    }

    private var completions: [@MainActor (Bool) -> Void] = []
    private var observations: [LocationAuthorizationObservation] = []

    init(status: CLAuthorizationStatus = .authorizedAlways) {
        authorizationStatus = status
    }

    func requestAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        requestCount += 1
        if authorizationStatus == .notDetermined {
            completions.append(completion)
        } else {
            completion(authorizationStatus == .authorizedAlways)
        }
    }

    func observeAuthorization(_ handler: @escaping @MainActor (CLAuthorizationStatus) -> Void) -> LocationAuthorizationObservation {
        let observation = LocationAuthorizationObservation(handler: handler)
        observations.append(observation)
        return observation
    }

    func refreshAuthorization() {
        refreshCount += 1
        send(authorizationStatus)
    }

    func send(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        for observation in observations {
            observation.notify(status)
        }
        guard status != .notDetermined else { return }
        let pending = completions
        completions.removeAll()
        for completion in pending {
            completion(status == .authorizedAlways)
        }
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/LocationAuthorizationService.swift
