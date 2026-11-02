//
//  LastThiefDetectionViewModel.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import Observation
import SwiftUI

/// A view model that manages the data related to the last detected thief and associated images.
@Observable
@MainActor
final class LastThiefDetectionViewModel {
    // MARK: - Dependency Injection

    /// An object that conforms to `DatabaseManagerProtocol`, responsible for database interactions.
    var databaseManager: any DatabaseManagerProtocol

    // MARK: - Variables

    /// The selected item from the list of latest images.
    var selectedItem: DatabaseDto?

    /// A list of the latest images related to the last detected thief.
    var latestImages: [DatabaseDto] = .init()

    // MARK: - Combine

    /// A collection of Combine cancellables for managing subscriptions.
    /// Ignored by observation as it's internal infrastructure.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    /// Initializes the view model with a given database manager.
    ///
    /// - Parameter databaseManager: The database manager object.
    init(databaseManager: any DatabaseManagerProtocol) {
        self.databaseManager = databaseManager
        setupPublishers()
    }
    
    // MARK: Public Methods
    
    /// Handles the action of pressing the close button on a cell in the list.
    ///
    /// - Parameter dto: The `DatabaseDto` object associated with the cell.
    func remove(_ dto: DatabaseDto) {
        update(list: databaseManager.remove(dto).dtos)
    }
    
    // MARK: Private Methods
    
    /// Sets up Combine publishers to listen to changes in the database.
    private func setupPublishers() {
        // Subscribes to changes when a new image is added to the database.
        databaseManager.latestImagesPublisher.sink { [weak self] dtos in
            self?.update(list: dtos)
        }
        .store(in: &cancellables)
    }
    
    /// Updates the list of latest images. Cleans the old list and appends sorted items by date.
    ///
    /// - Parameter list: A list of `DatabaseDto` items to update.
    private func update(list: [DatabaseDto]) {
        latestImages.removeAll()
        latestImages.append(contentsOf: list.sorted { $0.date > $1.date })
        selectedItem = latestImages.first
    }
}
