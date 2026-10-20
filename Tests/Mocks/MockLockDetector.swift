//
//  MockLockDetector.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import Foundation
@testable import Lock_Watcher

/// Lock detector whose ticks the test sends by hand.
final class MockLockDetector: MacOSLockDetectorProtocol, @unchecked Sendable {
    let isLockedPublisher = PassthroughSubject<Bool, Never>()

    func tick(locked: Bool) {
        isLockedPublisher.send(locked)
    }
}

/// A mutable value that `@MainActor` source closures read, since they cannot capture a local `var`.
@MainActor
final class StubValue<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// Collects the trigger types a listener yielded once its stream finishes.
@MainActor
func collectTriggers(_ stream: AsyncStream<ListenerEvent>) async -> [TriggerType] {
    var triggers: [TriggerType] = []
    for await (_, trigger) in stream {
        triggers.append(trigger)
    }
    return triggers
}

// MARK: - Source Info

// @source-file: Source/Managers/MacOSLockDetectManager.swift
