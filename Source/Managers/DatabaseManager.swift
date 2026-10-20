//
//  DatabaseManager.swift
//
//  Created on 28.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import EasyStash
import Foundation

/// Defines the contract for a database manager with observable latest images.
protocol DatabaseManagerProtocol: ObservableObject {
    func send(_ thiefDto: ThiefDto) -> DatabaseDtoList
    func remove(_ dto: DatabaseDto) -> DatabaseDtoList
    func cleanAll()
    var latestImages: [DatabaseDto] { get }
    var latestImagesPublisher: Published<[DatabaseDto]>.Publisher { get }
}

final class DatabaseManager: DatabaseManagerProtocol {
    // MARK: - Dependency injection
    
    /// Holds the application settings.
    private var settings: AppSettingsProtocol

    private let logger: LogProtocol
    
    // MARK: - Variables
    
    /// Key used for storing and retrieving images in the storage.
    private let kImagesKey = "images"
    
    /// Instance of the storage for saving and retrieving data.
    private var storage: Storage?
    
    /// Observable property that stores the latest images.
    @Published private(set) var latestImages: [DatabaseDto] = .init()
    
    // MARK: - Combine
    
    /// Publisher for `latestImages` property to allow observing its changes.
    var latestImagesPublisher: Published<[DatabaseDto]>.Publisher {
        $latestImages
    }
    
    // MARK: - initialiser
    
    /// Initializes the database manager with app settings and configures storage options.
    init(settings: AppSettingsProtocol, logger: LogProtocol = Log(category: .database)) {
        self.settings = settings
        self.logger = logger
        
        var options = Options()
        options.folder = "Thiefs"
        
        storage = try? Storage(options: options)
        
        // Load and store the initial set of images from the storage.
        latestImages.append(contentsOf: readImages().dtos)
    }
    
    // MARK: - public
    
    /// Stores the thief incident information in the storage and updates the `latestImages`.
    func send(_ thiefDto: ThiefDto) -> DatabaseDtoList {
        // Read the current images from the storage
        let images = readImages()

        guard let dto = DatabaseDto(with: thiefDto) else {
            logger.error("Record has no still image; not stored in history")
            return images
        }
        
        // Append the new data and keep only the latest specified number of incidents
        images.append(dto)
        images.dtos = images.dtos.suffix(settings.options.keepLastActionsCount)
        
        // Save the updated data to the storage
        do {
            try storage?.save(object: images, forKey: kImagesKey)
        } catch {
            print(error)
            return images
        }
        
        // Update the published images
        latestImages = images.dtos
        
        return images
    }
    
    /// Removes a specific incident from the storage and updates the `latestImages`.
    func remove(_ dto: DatabaseDto) -> DatabaseDtoList {
        let images = readImages()

        // Remove the specific incident based on the date
        images.dtos.removeAll { $0.date == dto.date }

        // Save the updated data to the storage
        do {
            try storage?.save(object: images, forKey: kImagesKey)
        } catch {
            print(error)
        }

        // Update the published images
        latestImages = images.dtos

        return images
    }

    /// Removes all incidents from the storage and updates the `latestImages`.
    func cleanAll() {
        let emptyList = DatabaseDtoList(dtos: [])

        do {
            try storage?.save(object: emptyList, forKey: kImagesKey)
        } catch {
            print(error)
        }

        latestImages = []
    }

    // MARK: - private
    
    /// Fetches and returns the images from the storage.
    private func readImages() -> DatabaseDtoList {
        var images = DatabaseDtoList(dtos: .init())
        do {
            // Try to load images from the storage
            if let imgs = try storage?.load(forKey: kImagesKey, as: DatabaseDtoList.self) {
                images = imgs
            }
        } catch {
            print("images is empty")
        }
        
        return images
    }
}

/// A mock version of `DatabaseManager` mainly for previewing or testing purposes.
final class DatabaseManagerPreview: DatabaseManagerProtocol {
    func send(_ thiefDto: ThiefDto) -> DatabaseDtoList {
        .empty
    }

    func remove(_ dto: DatabaseDto) -> DatabaseDtoList {
        .empty
    }

    func cleanAll() {}

    @Published private(set) var latestImages: [DatabaseDto] = .init()

    var latestImagesPublisher: Published<[DatabaseDto]>.Publisher {
        $latestImages
    }
}
