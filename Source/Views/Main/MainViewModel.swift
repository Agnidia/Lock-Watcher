//
//  MainViewModel.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Observation
import SwiftUI

/// A view model for the main screen, handling business logic and data retrieval for its corresponding view.
@Observable
@MainActor
final class MainViewModel: DomainViewConstantProtocol {
    // MARK: - DomainViewConstantProtocol

    /// Configuration settings specific to the main view.
    var viewSettings: MainDomain = .init()

    /// A typealias for easier reference.
    typealias DomainViewConstant = MainDomain

    // MARK: - Types

    /// A typealias to represent a callback block which is triggered based on some event.
    typealias SettingsTriggerWatchBlock = Commons.TriggerClosure

    // MARK: - Dependency injection

    /// The manager responsible for operations related to potential security threats.
    var thiefManager: ThiefManagerProtocol

    /// The manager responsible for database operations.
    var databaseManager: any DatabaseManagerProtocol

    // MARK: - Variables

    /// The view model responsible for displaying the last detected thief information.
    let lastThiefDetectionViewModel: LastThiefDetectionViewModel
    let infoViewModel: InfoViewModel
    
    /// A boolean that represents whether the required access permissions are granted or not.
    var isAccessGranted = true

    /// A callback block that is invoked when the required access permissions are granted.
    /// Ignored by observation as it's a callback infrastructure.
    @ObservationIgnored
    var accessGrantedBlock: Commons.EmptyClosure?
    
    // MARK: - Initializer
    
    /// Initializes a new instance of `MainViewModel`.
    /// - Parameters:
    ///   - thiefManager: An object conforming to `ThiefManagerProtocol` to manage potential security threats.
    ///   - isInfoExtended: A boolean value to indicate if the information should be extended. Default value is `true`.
    init(thiefManager: ThiefManagerProtocol, isInfoExtended: Bool = true) {
        self.thiefManager = thiefManager
        databaseManager = thiefManager.databaseManager
        lastThiefDetectionViewModel = .init(databaseManager: thiefManager.databaseManager)
        infoViewModel = .init(thiefManager: thiefManager)
    }
}

/// An extension providing a preview instance of `MainViewModel` for design and testing purposes.
extension MainViewModel {
    static var preview: MainViewModel {
        .init(thiefManager: ThiefManagerPreview())
    }
}
