//
//  MockAPNsTransport.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import Foundation
import os
@testable import Lock_Watcher

/// Records every request and answers from a script; the last scripted reply repeats.
final class MockAPNsTransport: APNsTransport, @unchecked Sendable {
    struct Reply: Sendable {
        let status: Int
        let reason: String?
    }

    private struct State: Sendable {
        var replies: [Reply]
        var requests: [URLRequest] = []
        var failuresLeft: Int
    }

    private let state: OSAllocatedUnfairLock<State>
    private let error: URLError?
    private let onSend: (@Sendable () -> Void)?

    /// `error` is thrown by the first `failures` sends; later sends answer from `replies`.
    init(replies: [Reply] = [Reply(status: 200, reason: nil)], error: URLError? = nil, failures: Int = .max, onSend: (@Sendable () -> Void)? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(replies: replies, failuresLeft: failures))
        self.error = error
        self.onSend = onSend
    }

    var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (reply, fails) = state.withLock { state -> (Reply, Bool) in
            state.requests.append(request)
            let fails = state.failuresLeft > 0
            if fails {
                state.failuresLeft -= 1
            }
            return (state.replies.count > 1 ? state.replies.removeFirst() : state.replies[0], fails)
        }
        onSend?()
        if let error, fails {
            throw error
        }
        let body = reply.reason.map { Data("{\"reason\":\"\($0)\"}".utf8) } ?? Data()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/2", headerFields: nil)!
        return (body, response)
    }
}

final class MockNetworkReachability: NetworkReachability, @unchecked Sendable {
    private struct State: Sendable {
        var isOnline: Bool
        var continuations: [AsyncStream<Void>.Continuation] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(isOnline: Bool) {
        state = OSAllocatedUnfairLock(initialState: State(isOnline: isOnline))
    }

    var isOnline: Bool {
        state.withLock { $0.isOnline }
    }

    func onlineEvents() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        state.withLock { $0.continuations.append(continuation) }
        return stream
    }

    func goOnline() {
        let waiting = state.withLock { state -> [AsyncStream<Void>.Continuation] in
            state.isOnline = true
            return state.continuations
        }
        waiting.forEach { $0.yield() }
    }
}

struct StubAPNsCredentialsProvider: APNsCredentialsProviding {
    static let keyID = "ABC123DEFG"
    static let teamID = "TEAM123456"
    static let topic = "com.igrsoft.Lock-Watcher"

    let privateKey: P256.Signing.PrivateKey

    func current(for environment: APNsEnvironment) throws -> APNsProviderCredentials {
        APNsProviderCredentials(keyID: Self.keyID, teamID: Self.teamID, privateKey: privateKey, topic: Self.topic)
    }
}

final class TestClock: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_800_000_000))

    var now: Date {
        state.withLock { $0 }
    }

    func advance(_ seconds: TimeInterval) {
        state.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

final class SleepRecorder: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [Duration]())

    var calls: [Duration] {
        state.withLock { $0 }
    }

    func sleep(_ duration: Duration) async throws {
        state.withLock { $0.append(duration) }
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/APNsClient.swift
