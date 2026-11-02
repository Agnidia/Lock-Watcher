//
//  MockLocationMonitor.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreLocation
import Foundation
@testable import Lock_Watcher

@MainActor
final class MockLocationMonitor: LocationMonitoring {
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var isSignificantChangeAvailable = true
    var onFix: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var requestFixCount = 0

    func startSignificantChanges() {
        startCount += 1
    }

    func stopSignificantChanges() {
        stopCount += 1
    }

    func requestFix() {
        requestFixCount += 1
    }

    func emit(_ fix: CLLocation) {
        onFix?(fix)
    }

    func changeAuthorization(to status: CLAuthorizationStatus) {
        authorizationStatus = status
        onAuthorizationChange?(status)
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/GeofenceListener.swift
