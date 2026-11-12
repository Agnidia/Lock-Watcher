//
//  APNsCredentialStore.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import Foundation
import KeychainAccess

/// The one iPhone this Mac sends alerts to.
struct PairedDevice: Codable, Sendable, Equatable {
    let token: String
    let environment: APNsEnvironment
    let topic: String
    let pairedAt: Date
}

/// An owner-supplied APNs key; it works only with a companion the owner built under their own team.
struct BYOKCredentials: Codable, Sendable, Equatable {
    let keyID: String
    let teamID: String
    let topic: String
    let privateKeyPEM: String
}

enum PairingStatus: Sendable, Equatable {
    case unpaired
    case paired(PairedDevice)
    /// APNs reported the token dead (400 BadDeviceToken / 410 Unregistered); the owner must scan a fresh code.
    case needsRepair
}

/// The single source of truth for pairing state; every mutation posts `.pushPairingDidChange`.
protocol APNsCredentialStoring: Sendable {
    func pairedDevice() -> PairedDevice?
    func savePairedDevice(_ device: PairedDevice) throws
    func markNeedsRepair()
    func clearPairing()
    func pairingStatus() -> PairingStatus
    func byokCredentials() -> BYOKCredentials?
    func saveBYOK(_ credentials: BYOKCredentials) throws
    func clearBYOK()
}

extension Notification.Name {
    static let pushPairingDidChange = Notification.Name("PushPairingDidChange")
}

/// Keychain-backed pairing and own-key storage.
///
/// - Note: `@unchecked Sendable` because KeychainAccess's `Keychain` is not annotated; it is immutable here and the
///   Keychain Services calls behind it are thread-safe, the same reasoning as `SecurityUtil`.
final class APNsCredentialStore: APNsCredentialStoring, @unchecked Sendable {
    private enum Key {
        static let pairedDevice = "apns.pairedDevice"
        static let needsRepair = "apns.needsRepair"
        static let byok = "apns.byok"
    }

    private let keychain: Keychain
    private let notificationCenter: NotificationCenter

    /// Items stay readable after the first unlock because triggers fire while the Mac is locked; they never sync to iCloud.
    init(service: String = "\(Secrets.keychainId).apns", notificationCenter: NotificationCenter = .default) {
        keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
            .synchronizable(false)
        self.notificationCenter = notificationCenter
    }

    func pairedDevice() -> PairedDevice? {
        decode(PairedDevice.self, key: Key.pairedDevice)
    }

    func savePairedDevice(_ device: PairedDevice) throws {
        try keychain.set(JSONEncoder().encode(device), key: Key.pairedDevice)
        try? keychain.remove(Key.needsRepair)
        notifyChange()
    }

    func markNeedsRepair() {
        try? keychain.remove(Key.pairedDevice)
        try? keychain.set("1", key: Key.needsRepair)
        notifyChange()
    }

    func clearPairing() {
        try? keychain.remove(Key.pairedDevice)
        try? keychain.remove(Key.needsRepair)
        notifyChange()
    }

    func pairingStatus() -> PairingStatus {
        if let device = pairedDevice() {
            return .paired(device)
        }
        return (try? keychain.getString(Key.needsRepair)) == "1" ? .needsRepair : .unpaired
    }

    func byokCredentials() -> BYOKCredentials? {
        decode(BYOKCredentials.self, key: Key.byok)
    }

    func saveBYOK(_ credentials: BYOKCredentials) throws {
        try keychain.set(JSONEncoder().encode(credentials), key: Key.byok)
        notifyChange()
    }

    func clearBYOK() {
        try? keychain.remove(Key.byok)
        notifyChange()
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? keychain.getData(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func notifyChange() {
        notificationCenter.post(name: .pushPairingDidChange, object: nil)
    }
}

/// One embedded key; CI writes the values into `Secrets.swift`, and empty values mean push is not configured.
struct EmbeddedAPNsKey: Sendable {
    let keyID: String
    let teamID: String
    let privateKeyBase64: String

    /// Only development companions register for sandbox, so a Release build resolves no sandbox key and CI leaves it empty in archives.
    static func bundled(for environment: APNsEnvironment) -> EmbeddedAPNsKey {
        switch environment {
        case .sandbox:
            #if DEBUG
                EmbeddedAPNsKey(keyID: Secrets.apnsSandboxKeyId, teamID: Secrets.apnsTeamId, privateKeyBase64: Secrets.apnsSandboxKeyP8Base64)
            #else
                EmbeddedAPNsKey(keyID: "", teamID: Secrets.apnsTeamId, privateKeyBase64: "")
            #endif
        case .production:
            EmbeddedAPNsKey(keyID: Secrets.apnsProductionKeyId, teamID: Secrets.apnsTeamId, privateKeyBase64: Secrets.apnsProductionKeyP8Base64)
        }
    }
}

/// Resolution order: the owner's own key when complete, else the embedded key for the device's environment, else `missingConfiguration`.
struct APNsCredentialsProvider: APNsCredentialsProviding {
    static let missing = NotifierError.missingConfiguration("apns")

    let store: any APNsCredentialStoring
    let embeddedKey: @Sendable (APNsEnvironment) -> EmbeddedAPNsKey
    let embeddedTopic: @Sendable () -> String?

    static func live(store: any APNsCredentialStoring) -> APNsCredentialsProvider {
        APNsCredentialsProvider(store: store, embeddedKey: { EmbeddedAPNsKey.bundled(for: $0) }, embeddedTopic: { infoPlistTopic() })
    }

    func current(for environment: APNsEnvironment) throws -> APNsProviderCredentials {
        if let own = store.byokCredentials() {
            return try Self.make(keyID: own.keyID, teamID: own.teamID, pem: own.privateKeyPEM, topic: own.topic)
        }
        let key = embeddedKey(environment)
        guard let data = Data(base64Encoded: key.privateKeyBase64, options: .ignoreUnknownCharacters),
              let pem = String(data: data, encoding: .utf8),
              let topic = embeddedTopic()
        else { throw Self.missing }
        return try Self.make(keyID: key.keyID, teamID: key.teamID, pem: pem, topic: topic)
    }

    /// The topic a scanned pairing code must carry: the own-key topic when set, else the companion bundle ID from Info.plist.
    func expectedTopic() -> String? {
        store.byokCredentials()?.topic ?? embeddedTopic()
    }

    static func make(keyID: String, teamID: String, pem: String, topic: String) throws -> APNsProviderCredentials {
        guard isValidIdentifier(keyID), isValidIdentifier(teamID), PairingPayload.isValidTopic(topic),
              let privateKey = privateKey(from: pem)
        else { throw missing }
        return APNsProviderCredentials(keyID: keyID, teamID: teamID, privateKey: privateKey, topic: topic)
    }

    /// Key IDs and Team IDs are ten uppercase alphanumerics.
    static func isValidIdentifier(_ value: String) -> Bool {
        value.utf8.count == 10 && value.utf8.allSatisfy {
            (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) || (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains($0)
        }
    }

    /// Accepts the `.p8` text as is, or pasted into a single-line field that dropped its line breaks.
    static func privateKey(from text: String) -> P256.Signing.PrivateKey? {
        if let key = try? P256.Signing.PrivateKey(pemRepresentation: text) {
            return key
        }
        let body = text.replacingOccurrences(of: "-----[A-Z ]+-----", with: "", options: .regularExpression).filter { !$0.isWhitespace }
        guard let der = Data(base64Encoded: body) else { return nil }
        return try? P256.Signing.PrivateKey(derRepresentation: der)
    }

    static func infoPlistTopic() -> String? {
        guard let topic = Bundle.main.object(forInfoDictionaryKey: "LWCompanionBundleIdentifier") as? String, !topic.isEmpty else {
            return nil
        }
        return topic
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/APNsCredentialStoreTest.swift
// @related-tests: Tests/Utils/APNsClientTest.swift
