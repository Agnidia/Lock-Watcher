//
//  APNsClient.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import Foundation

/// Sends one prepared APNs request; the seam lets tests script every response row without a network.
protocol APNsTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// One connection per host keeps URLSession on a single HTTP/2 (ALPN) connection, which APNs expects providers to reuse.
final class URLSessionAPNsTransport: APNsTransport {
    private let session: URLSession

    init(timeout: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = timeout
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

/// Everything needed to sign a provider token and address one app.
struct APNsProviderCredentials: Sendable {
    let keyID: String
    let teamID: String
    let privateKey: P256.Signing.PrivateKey
    let topic: String
}

/// Resolves the signing key for the environment a device token belongs to, because APNs keys can be scoped to sandbox or production.
protocol APNsCredentialsProviding: Sendable {
    func current(for environment: APNsEnvironment) throws -> APNsProviderCredentials
}

struct APNsResponse: Sendable, Equatable {
    let status: Int
    /// The `reason` field of the JSON error body; nil on 200.
    let reason: String?
}

enum APNsError: Error, Sendable, Equatable {
    /// 429 or 5xx still failing after the last retry.
    case transient(Int)
    /// A rejection that a retry cannot fix.
    case rejected(Int, String?)
}

extension APNsEnvironment {
    var host: String {
        switch self {
        case .sandbox: "api.sandbox.push.apple.com"
        case .production: "api.push.apple.com"
        }
    }
}

/// Signs ES256 provider tokens and posts alerts to APNs.
///
/// The token cache is the only mutable state, so actor isolation replaces a lock.
actor APNsClient {
    /// APNs refuses tokens refreshed more often than every 20 minutes and expires them after 60; 40 minutes sits inside both limits.
    static let tokenReuseInterval: TimeInterval = 2400

    private struct CachedToken {
        let value: String
        let keyID: String
        let issuedAt: Date
    }

    private let credentials: any APNsCredentialsProviding
    private let transport: any APNsTransport
    private let now: @Sendable () -> Date
    private var cache: [APNsEnvironment: CachedToken] = [:]

    init(credentials: any APNsCredentialsProviding, transport: any APNsTransport, now: @escaping @Sendable () -> Date = { Date() }) {
        self.credentials = credentials
        self.transport = transport
        self.now = now
    }

    /// Posts one alert; a `403 ExpiredProviderToken` re-signs the token and retries exactly once.
    func send(payload: Data, to device: PairedDevice, expiration: Date) async throws -> APNsResponse {
        let response = try await post(payload, to: device, expiration: expiration, forceRefresh: false)
        guard response.status == 403, response.reason == "ExpiredProviderToken" else { return response }
        return try await post(payload, to: device, expiration: expiration, forceRefresh: true)
    }

    /// Reuses the cached token while it is younger than `tokenReuseInterval` and was signed by the same key.
    func providerToken(for environment: APNsEnvironment, forceRefresh: Bool = false) throws -> String {
        let credentials = try credentials.current(for: environment)
        let date = now()
        if !forceRefresh, let cached = cache[environment], cached.keyID == credentials.keyID {
            let age = date.timeIntervalSince(cached.issuedAt)
            if age >= 0, age < Self.tokenReuseInterval {
                return cached.value
            }
        }
        let token = try Self.makeToken(credentials: credentials, issuedAt: date)
        cache[environment] = CachedToken(value: token, keyID: credentials.keyID, issuedAt: date)
        return token
    }

    static func makeToken(credentials: APNsProviderCredentials, issuedAt: Date) throws -> String {
        let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": credentials.keyID], options: [.sortedKeys])
        let claims = try JSONSerialization.data(withJSONObject: ["iss": credentials.teamID, "iat": Int(issuedAt.timeIntervalSince1970)] as [String: Any],
                                                options: [.sortedKeys])
        let signingInput = header.base64URLEncodedString() + "." + claims.base64URLEncodedString()
        // APNs accepts only the raw 64-byte r||s signature; a DER signature is rejected.
        let signature = try credentials.privateKey.signature(for: Data(signingInput.utf8))
        return signingInput + "." + signature.rawRepresentation.base64URLEncodedString()
    }

    /// Carries exactly the five headers APNs needs and no collapse identifier, so no alert replaces another.
    static func makeRequest(payload: Data, device: PairedDevice, expiration: Date, providerToken: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = device.environment.host
        components.path = "/3/device/\(device.token)"
        guard let url = components.url else {
            throw NotifierError.missingConfiguration("push-token")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("bearer \(providerToken)", forHTTPHeaderField: "authorization")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue(device.topic, forHTTPHeaderField: "apns-topic")
        request.setValue(String(Int(expiration.timeIntervalSince1970)), forHTTPHeaderField: "apns-expiration")
        return request
    }

    static func reason(from body: Data) -> String? {
        struct ErrorBody: Decodable {
            let reason: String
        }
        return try? JSONDecoder().decode(ErrorBody.self, from: body).reason
    }

    private func post(_ payload: Data, to device: PairedDevice, expiration: Date, forceRefresh: Bool) async throws -> APNsResponse {
        let token = try providerToken(for: device.environment, forceRefresh: forceRefresh)
        let request = try Self.makeRequest(payload: payload, device: device, expiration: expiration, providerToken: token)
        let (body, response) = try await transport.send(request)
        return APNsResponse(status: response.statusCode, reason: response.statusCode == 200 ? nil : Self.reason(from: body))
    }
}

extension Data {
    /// RFC 7515 base64url without padding, as JWT segments require.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/APNsClientTest.swift
// @related-tests: Tests/Notifiers/PushNotifierTest.swift
