//
//  PushRegistrationModel.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Observation

/// The APNs topic and environment this build pairs with.
struct CompanionConfiguration: Sendable, Equatable {
    let topic: String
    let environment: APNsEnvironment

    /// The environment comes from the `APS_ENVIRONMENT` build setting that also feeds the `aps-environment` entitlement, never from `#if DEBUG`.
    static func main() -> CompanionConfiguration {
        let environment = Bundle.main.object(forInfoDictionaryKey: "LWAPSEnvironment") as? String
        return CompanionConfiguration(topic: Bundle.main.bundleIdentifier ?? "", environment: environment == "production" ? .production : .sandbox)
    }
}

protocol RemoteNotificationRegistering: Sendable {
    func requestAuthorization() async -> Bool
    @MainActor
    func registerForRemoteNotifications()
}

struct StubRemoteNotificationRegistrar: RemoteNotificationRegistering {
    let isAuthorized: Bool

    func requestAuthorization() async -> Bool {
        isAuthorized
    }

    @MainActor
    func registerForRemoteNotifications() {}
}

/// Turns notification permission and the APNs device token into a pairing code; the token lives in memory only, because APNs may rotate it.
@MainActor
@Observable
final class PushRegistrationModel {
    enum State: Equatable {
        case needsAuthorization
        case denied
        case registering
        case ready(PairingPayload)
        case failed
    }

    private(set) var state: State = .needsAuthorization

    @ObservationIgnored private let registrar: any RemoteNotificationRegistering
    @ObservationIgnored private let configuration: CompanionConfiguration

    init(registrar: any RemoteNotificationRegistering, configuration: CompanionConfiguration) {
        self.registrar = registrar
        self.configuration = configuration
    }

    func start() async {
        guard await registrar.requestAuthorization() else {
            state = .denied
            return
        }
        if case .ready = state {
            registrar.registerForRemoteNotifications()
            return
        }
        state = .registering
        registrar.registerForRemoteNotifications()
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        if let payload = try? PairingPayload(token: hex, environment: configuration.environment, topic: configuration.topic) {
            state = .ready(payload)
        } else {
            state = .failed
        }
    }

    func didFailToRegister() {
        state = .failed
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
