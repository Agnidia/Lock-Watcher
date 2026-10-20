//
//  MockListener.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

/// Mock implementation of `BaseListenerProtocol` for testing.
///
/// `@MainActor` isolation matches the protocol requirement.
@MainActor
final class MockListener: BaseListenerProtocol {
    var invokedIsRunningGetter = false
    var invokedIsRunningGetterCount = 0
    var stubbedIsRunning: Bool = false

    var isRunning: Bool {
        invokedIsRunningGetter = true
        invokedIsRunningGetterCount += 1
        return stubbedIsRunning
    }

    var invokedStart = false
    var invokedStartCount = 0
    var stubbedStartResult: ListenerEvent?
    /// `false` mimics a listener whose stream is open but not monitoring yet (unauthorized geofence).
    var stubbedIsRunningAfterStart = true
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    func start() -> AsyncStream<ListenerEvent> {
        invokedStart = true
        invokedStartCount += 1
        stubbedIsRunning = stubbedIsRunningAfterStart

        return AsyncStream { continuation in
            self.continuation = continuation
            if let result = self.stubbedStartResult {
                continuation.yield(result)
            }
        }
    }

    /// Emit an event to the stream (for testing)
    func emit(_ event: ListenerEvent) {
        continuation?.yield(event)
    }

    var invokedStop = false
    var invokedStopCount = 0

    func stop() {
        invokedStop = true
        invokedStopCount += 1
        stubbedIsRunning = false
        continuation?.finish()
        continuation = nil
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/BaseListenerProtocol.swift
