//
//  MockDatabaseManager.swift
//
//  Created on 27.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

final class MockDatabaseManager: DatabaseManagerProtocol {
    var invokedLatestImagesGetter = false
    var invokedLatestImagesGetterCount = 0
    @Published var stubbedLatestImages: [DatabaseDto] = []

    var latestImages: [DatabaseDto] {
        invokedLatestImagesGetter = true
        invokedLatestImagesGetterCount += 1
        return stubbedLatestImages
    }

    var invokedLatestImagesPublisherGetter = false
    var invokedLatestImagesPublisherGetterCount = 0
    var stubbedLatestImagesPublisher: Published<[DatabaseDto]>!

    var latestImagesPublisher: Published<[DatabaseDto]>.Publisher {
        invokedLatestImagesPublisherGetter = true
        invokedLatestImagesPublisherGetterCount += 1
        return $stubbedLatestImages
    }

    var invokedSend = false
    var invokedSendCount = 0
    var invokedSendParameters: (thiefDto: ThiefDto, Void)?
    var invokedSendParametersList = [(thiefDto: ThiefDto, Void)]()
    var stubbedSendResult: DatabaseDtoList = .empty

    func send(_ thiefDto: ThiefDto) -> DatabaseDtoList {
        invokedSend = true
        invokedSendCount += 1
        invokedSendParameters = (thiefDto, ())
        invokedSendParametersList.append((thiefDto, ()))
        return stubbedSendResult
    }

    var invokedRemove = false
    var invokedRemoveCount = 0
    var invokedRemoveParameters: (dto: DatabaseDto, Void)?
    var invokedRemoveParametersList = [(dto: DatabaseDto, Void)]()
    var stubbedRemoveResult: DatabaseDtoList!

    func remove(_ dto: DatabaseDto) -> DatabaseDtoList {
        invokedRemove = true
        invokedRemoveCount += 1
        invokedRemoveParameters = (dto, ())
        invokedRemoveParametersList.append((dto, ()))
        return stubbedRemoveResult
    }

    var invokedCleanAll = false
    var invokedCleanAllCount = 0

    func cleanAll() {
        invokedCleanAll = true
        invokedCleanAllCount += 1
        stubbedLatestImages = []
    }
}
