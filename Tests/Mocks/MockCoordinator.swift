//
//  MockCoordinator.swift
//
//  Created on 27.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

final class MockCoordinator: BaseCoordinatorProtocol {
    var invokedDisplayMainWindow = false
    var invokedDisplayMainWindowCount = 0

    func displayMainWindow() {
        invokedDisplayMainWindow = true
        invokedDisplayMainWindowCount += 1
    }

    var invokedCloseMainWindow = false
    var invokedCloseMainWindowCount = 0

    func closeMainWindow() {
        invokedCloseMainWindow = true
        invokedCloseMainWindowCount += 1
    }

    var invokedToggleMainWindow = false
    var invokedToggleMainWindowCount = 0

    func toggleMainWindow() {
        invokedToggleMainWindow = true
        invokedToggleMainWindowCount += 1
    }

    var invokedDisplayFirstLaunchWindowIfNeed = false
    var invokedDisplayFirstLaunchWindowIfNeedCount = 0
    var invokedDisplayFirstLaunchWindowIfNeedParameters: (closeClosure: Commons.EmptyClosure, Void)?
    var invokedDisplayFirstLaunchWindowIfNeedParametersList = [(closeClosure: Commons.EmptyClosure, Void)]()

    func displayFirstLaunchWindowIfNeed(closeClosure: @escaping Commons.EmptyClosure) {
        invokedDisplayFirstLaunchWindowIfNeed = true
        invokedDisplayFirstLaunchWindowIfNeedCount += 1
        invokedDisplayFirstLaunchWindowIfNeedParameters = (closeClosure, ())
        invokedDisplayFirstLaunchWindowIfNeedParametersList.append((closeClosure, ()))
    }

    var invokedDisplaySettingsWindow = false
    var invokedDisplaySettingsWindowCount = 0

    func displaySettingsWindow() {
        invokedDisplaySettingsWindow = true
        invokedDisplaySettingsWindowCount += 1
    }
}
