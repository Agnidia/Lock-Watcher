//
//  MockAppDelegateModel.swift
//
//  Created on 27.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

/// Mock app delegate model for unit tests.
final class MockAppDelegateModel: AppDelegateModelProtocol {
    var invokedSettingsViewModelGetter = false
    var invokedSettingsViewModelGetterCount = 0
    var stubbedSettingsViewModel: SettingsViewModel!

    var settingsViewModel: SettingsViewModel {
        invokedSettingsViewModelGetter = true
        invokedSettingsViewModelGetterCount += 1
        return stubbedSettingsViewModel
    }

    var invokedSetup = false
    var invokedSetupCount = 0
    var invokedSetupParameters: (localNotification: Notification, Void)?
    var invokedSetupParametersList = [(localNotification: Notification, Void)]()

    func setup(with localNotification: Notification) {
        invokedSetup = true
        invokedSetupCount += 1
        invokedSetupParameters = (localNotification, ())
        invokedSetupParametersList.append((localNotification, ()))
    }

    var invokedCheckDropboxAuth = false
    var invokedCheckDropboxAuthCount = 0
    var invokedCheckDropboxAuthParameters: (urls: [URL], Void)?
    var invokedCheckDropboxAuthParametersList = [(urls: [URL], Void)]()
    var stubbedCheckDropboxAuthResult: Bool! = false

    func checkDropboxAuth(urls: [URL]) -> Bool {
        invokedCheckDropboxAuth = true
        invokedCheckDropboxAuthCount += 1
        invokedCheckDropboxAuthParameters = (urls, ())
        invokedCheckDropboxAuthParametersList.append((urls, ()))
        return stubbedCheckDropboxAuthResult
    }
}
