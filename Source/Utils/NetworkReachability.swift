//
//  NetworkReachability.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Network
import os

/// Reports whether a network path is usable, and when it becomes usable again.
protocol NetworkReachability: Sendable {
    var isOnline: Bool { get }

    /// Yields each time the path turns usable after being unusable.
    func onlineEvents() -> AsyncStream<Void>
}

/// `NWPathMonitor` adapter.
///
/// The monitor starts on first use, so a Mac with push turned off runs no path monitor.
///
/// - Note: `@unchecked Sendable` because `NWPathMonitor` is only started and cancelled here; the mutable state sits behind the lock.
final class NWPathMonitorReachability: NetworkReachability, @unchecked Sendable {
    private struct State: Sendable {
        /// Optimistic until the first path update; a send that fails on a dead link is queued anyway.
        var isOnline = true
        var isStarted = false
        var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    }

    private let monitor = NWPathMonitor()
    private let state = OSAllocatedUnfairLock(initialState: State())

    init() {
        monitor.pathUpdateHandler = { [state] path in
            let isOnline = path.status == .satisfied
            let waiting = state.withLock { state -> [AsyncStream<Void>.Continuation] in
                let cameOnline = isOnline && !state.isOnline
                state.isOnline = isOnline
                return cameOnline ? Array(state.continuations.values) : []
            }
            waiting.forEach { $0.yield() }
        }
    }

    deinit {
        monitor.cancel()
    }

    var isOnline: Bool {
        startIfNeeded()
        return state.withLock { $0.isOnline }
    }

    func onlineEvents() -> AsyncStream<Void> {
        startIfNeeded()
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        state.withLock { $0.continuations[id] = continuation }
        continuation.onTermination = { [state] _ in
            state.withLock { _ = $0.continuations.removeValue(forKey: id) }
        }
        return stream
    }

    private func startIfNeeded() {
        let shouldStart = state.withLock { state -> Bool in
            defer { state.isStarted = true }
            return !state.isStarted
        }
        if shouldStart {
            monitor.start(queue: DispatchQueue(label: "com.igrsoft.Lock-Watcher.reachability"))
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/Notifiers/PushNotifierTest.swift
