//
//  PushPairingViewModel.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AVFoundation
import Foundation
import Observation

/// What the Settings block may show; it never holds the device token.
enum PushPairingState: Equatable, Sendable {
    case unpaired
    case paired(environment: APNsEnvironment, pairedAt: Date)
    case needsRepair
}

/// The four visual states of the push block.
enum PushBlockPhase: Equatable {
    case disabled
    case unpaired
    case paired(environment: APNsEnvironment, pairedAt: Date)
    case needsRepair

    static func make(isEnabled: Bool, pairing: PushPairingState) -> PushBlockPhase {
        guard isEnabled else { return .disabled }
        return switch pairing {
        case .unpaired: .unpaired
        case .paired(let environment, let pairedAt): .paired(environment: environment, pairedAt: pairedAt)
        case .needsRepair: .needsRepair
        }
    }
}

enum PairingCodeIssue: Equatable, Sendable {
    case notAPairingCode
    case wrongApp
    case saveFailed

    var messageKey: String {
        switch self {
        case .notAPairingCode: "PushInvalidCode"
        case .wrongApp: "PushWrongApp"
        case .saveFailed: "PushSaveFailed"
        }
    }
}

enum ScanPhase: Equatable {
    case idle
    case requestingAccess
    case scanning
    case rejected(PairingCodeIssue)
    case cameraDenied
    case cameraUnavailable
}

@MainActor
protocol CameraAuthorizing {
    func requestAccess() async -> Bool
}

struct LiveCameraAuthorizer: CameraAuthorizing {
    func requestAccess() async -> Bool {
        await Self.request()
    }

    /// Nonisolated so the completion, which AVFoundation calls on its own queue, is not compiled as main-actor code.
    private nonisolated static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            PermissionsUtils.updateCameraPermissions { continuation.resume(returning: $0) }
        }
    }
}

/// Removes its observer on deinit, so the view model needs no isolated deinit.
final class PairingChangeObservation: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    init(center: NotificationCenter, handler: @escaping @MainActor () -> Void) {
        self.center = center
        token = center.addObserver(forName: .pushPairingDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    deinit {
        center.removeObserver(token)
    }
}

/// Drives the push block in Settings: pairing state from the store, the QR scan flow, and the optional own key.
@Observable
@MainActor
final class PushPairingViewModel {
    private(set) var pairing: PushPairingState = .unpaired
    private(set) var scanPhase: ScanPhase
    private(set) var hasOwnKey = false
    var isPairingSheetPresented = false

    @ObservationIgnored let scanner: any QRCodeScanning
    @ObservationIgnored private let store: any APNsCredentialStoring
    @ObservationIgnored private let camera: any CameraAuthorizing
    @ObservationIgnored private let expectedTopic: () -> String?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var observation: PairingChangeObservation?
    /// Bumped by every read start and every write; `applied` holds the newest one shown, so a slow read cannot overwrite newer state.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var applied = 0

    init(store: any APNsCredentialStoring,
         scanner: any QRCodeScanning,
         camera: any CameraAuthorizing,
         expectedTopic: @escaping () -> String?,
         now: @escaping () -> Date = Date.init,
         notificationCenter: NotificationCenter = .default,
         scanPhase: ScanPhase = .idle)
    {
        self.store = store
        self.scanner = scanner
        self.camera = camera
        self.expectedTopic = expectedTopic
        self.now = now
        self.scanPhase = scanPhase
        observation = PairingChangeObservation(center: notificationCenter) { [weak self] in
            Task { await self?.refresh() }
        }
        Task { [weak self] in await self?.refresh() }
    }

    /// Reads the Keychain off the main actor, because Security blocks the calling thread on every item lookup.
    func refresh() async {
        generation += 1
        let started = generation
        let snapshot = await Self.snapshot(of: store)
        guard started > applied else { return }
        applied = started
        pairing = snapshot.pairing
        hasOwnKey = snapshot.hasOwnKey
    }

    private func markWritten() {
        generation += 1
        applied = generation
    }

    @concurrent
    private nonisolated static func snapshot(of store: any APNsCredentialStoring) async -> (pairing: PushPairingState, hasOwnKey: Bool) {
        let pairing: PushPairingState = switch store.pairingStatus() {
        case .unpaired: .unpaired
        case .needsRepair: .needsRepair
        case .paired(let device): .paired(environment: device.environment, pairedAt: device.pairedAt)
        }
        return (pairing, store.byokCredentials() != nil)
    }

    func startPairing() {
        scanPhase = .idle
        isPairingSheetPresented = true
    }

    func cancelPairing() {
        isPairingSheetPresented = false
    }

    func forget() {
        store.clearPairing()
        markWritten()
        pairing = .unpaired
    }

    /// Runs in the sheet's `.task`, so dismissing the sheet cancels the scan and stops the camera.
    func runScan() async {
        scanPhase = .requestingAccess
        guard await camera.requestAccess() else {
            scanPhase = .cameraDenied
            return
        }
        guard let codes = try? await scanner.codes() else {
            scanPhase = .cameraUnavailable
            return
        }
        scanPhase = .scanning
        var lastRejected: String?
        for await code in codes where code != lastRejected {
            if let issue = accept(code) {
                lastRejected = code
                scanPhase = .rejected(issue)
            } else {
                isPairingSheetPresented = false
                scanPhase = .idle
                break
            }
        }
        await scanner.stop()
    }

    /// Returns nil when the code paired the device.
    @discardableResult
    func accept(_ code: String) -> PairingCodeIssue? {
        guard let payload = try? PairingPayload.parse(code) else { return .notAPairingCode }
        guard let topic = expectedTopic(), payload.topic == topic else { return .wrongApp }
        let device = PairedDevice(token: payload.token, environment: payload.environment, topic: payload.topic, pairedAt: now())
        do {
            try store.savePairedDevice(device)
        } catch {
            return .saveFailed
        }
        markWritten()
        pairing = .paired(environment: device.environment, pairedAt: device.pairedAt)
        return nil
    }

    /// Validates the key by parsing it before anything is stored.
    func saveOwnKey(keyID: String, teamID: String, topic: String, pem: String) -> Bool {
        let keyID = keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let teamID = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let pem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (try? APNsCredentialsProvider.make(keyID: keyID, teamID: teamID, pem: pem, topic: topic)) != nil else { return false }
        do {
            try store.saveBYOK(BYOKCredentials(keyID: keyID, teamID: teamID, topic: topic, privateKeyPEM: pem))
        } catch {
            return false
        }
        markWritten()
        hasOwnKey = true
        markRepairIfTopicChanged()
        return true
    }

    func clearOwnKey() {
        store.clearBYOK()
        markWritten()
        hasOwnKey = false
        markRepairIfTopicChanged()
    }

    /// A pairing is bound to the topic it was scanned for; after the signing topic changes APNs rejects it, so the user must pair again.
    private func markRepairIfTopicChanged() {
        guard let device = store.pairedDevice(), let topic = expectedTopic(), device.topic != topic else { return }
        store.markNeedsRepair()
        pairing = .needsRepair
    }
}

extension PushPairingViewModel {
    static func live() -> PushPairingViewModel {
        #if DEBUG
            if let fixture = ProcessInfo.processInfo.environment["LW_PUSH_FIXTURE"].flatMap(PushPairingFixture.init(rawValue:)) {
                return preview(fixture)
            }
            if PreviewMode.isEnabled {
                return preview(.paired)
            }
        #endif
        let store = APNsCredentialStore()
        let credentials = APNsCredentialsProvider.live(store: store)
        return PushPairingViewModel(store: store, scanner: AVQRCodeScanner(), camera: LiveCameraAuthorizer(), expectedTopic: credentials.expectedTopic)
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
