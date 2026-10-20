//
//  MockThiefManager.swift
//
//  Created on 27.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

/// Mock implementation of `ThiefManagerProtocol` for testing.
///
/// `@MainActor` isolation matches the protocol requirement.
@MainActor
final class MockThiefManager: ThiefManagerProtocol {
    var invokedDatabaseManagerSetter = false
    var invokedDatabaseManagerSetterCount = 0
    var invokedDatabaseManager: (any DatabaseManagerProtocol)?
    var invokedDatabaseManagerList = [any DatabaseManagerProtocol]()
    var invokedDatabaseManagerGetter = false
    var invokedDatabaseManagerGetterCount = 0
    var stubbedDatabaseManager: (any DatabaseManagerProtocol)?

    var databaseManager: any DatabaseManagerProtocol {
        set {
            invokedDatabaseManagerSetter = true
            invokedDatabaseManagerSetterCount += 1
            invokedDatabaseManager = newValue
            invokedDatabaseManagerList.append(newValue)
        }
        get {
            invokedDatabaseManagerGetter = true
            invokedDatabaseManagerGetterCount += 1
            return stubbedDatabaseManager!
        }
    }

    var invokedDetectedTrigger = false
    var invokedDetectedTriggerCount = 0
    var stubbedDetectedTriggerResult: Bool = true

    func detectedTrigger() async -> Bool {
        invokedDetectedTrigger = true
        invokedDetectedTriggerCount += 1
        return stubbedDetectedTriggerResult
    }

    var invokedRestartWatching = false
    var invokedRestartWatchingCount = 0

    func restartWatching() {
        invokedRestartWatching = true
        invokedRestartWatchingCount += 1
    }

    var invokedSetupLocationManager = false
    var invokedSetupLocationManagerCount = 0
    var invokedSetupLocationManagerParameters: (enable: Bool, Void)?
    var invokedSetupLocationManagerParametersList = [(enable: Bool, Void)]()

    func setupLocationManager(enable: Bool) {
        invokedSetupLocationManager = true
        invokedSetupLocationManagerCount += 1
        invokedSetupLocationManagerParameters = (enable, ())
        invokedSetupLocationManagerParametersList.append((enable, ()))
    }

    var invokedShowSnapshot = false
    var invokedShowSnapshotCount = 0
    var invokedShowSnapshotParameters: (identifier: String, Void)?
    var invokedShowSnapshotParametersList = [(identifier: String, Void)]()

    func showSnapshot(identifier: String) {
        invokedShowSnapshot = true
        invokedShowSnapshotCount += 1
        invokedShowSnapshotParameters = (identifier, ())
        invokedShowSnapshotParametersList.append((identifier, ()))
    }

    var invokedCompleteDropboxAuthWith = false
    var invokedCompleteDropboxAuthWithCount = 0
    var invokedCompleteDropboxAuthWithParameters: (url: URL, Void)?
    var invokedCompleteDropboxAuthWithParametersList = [(url: URL, Void)]()
    var stubbedCompleteDropboxAuthWithResult: String = ""

    func completeDropboxAuthWith(url: URL) async -> String {
        invokedCompleteDropboxAuthWith = true
        invokedCompleteDropboxAuthWithCount += 1
        invokedCompleteDropboxAuthWithParameters = (url, ())
        invokedCompleteDropboxAuthWithParametersList.append((url, ()))
        return stubbedCompleteDropboxAuthWithResult
    }

    private var dropboxUserNameContinuation: AsyncStream<String>.Continuation?

    var dropboxUserNameUpdates: AsyncStream<String> {
        AsyncStream { continuation in
            self.dropboxUserNameContinuation = continuation
        }
    }

    /// Emit a username update (for testing)
    func emitDropboxUserName(_ name: String) {
        dropboxUserNameContinuation?.yield(name)
    }

    var invokedCleanAll = false
    var invokedCleanAllCount = 0

    func cleanAll() {
        invokedCleanAll = true
        invokedCleanAllCount += 1
    }

    var invokedApplyRetentionPolicyCount = 0

    func applyRetentionPolicy() {
        invokedApplyRetentionPolicyCount += 1
    }
}
