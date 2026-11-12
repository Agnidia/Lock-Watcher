//
//  PushPreviewSupport.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
    import AppKit
    import os
    import SwiftUI

    /// Keychain-free store for previews, DEBUG fixtures and tests.
    final class InMemoryAPNsCredentialStore: APNsCredentialStoring, @unchecked Sendable {
        private struct State: Sendable {
            var device: PairedDevice?
            var needsRepair = false
            var byok: BYOKCredentials?
        }

        private let state: OSAllocatedUnfairLock<State>
        private let notificationCenter: NotificationCenter

        init(device: PairedDevice? = nil, needsRepair: Bool = false, notificationCenter: NotificationCenter = NotificationCenter()) {
            state = OSAllocatedUnfairLock(initialState: State(device: device, needsRepair: needsRepair))
            self.notificationCenter = notificationCenter
        }

        func pairedDevice() -> PairedDevice? {
            state.withLock { $0.device }
        }

        func savePairedDevice(_ device: PairedDevice) throws {
            state.withLock {
                $0.device = device
                $0.needsRepair = false
            }
            notifyChange()
        }

        func markNeedsRepair() {
            state.withLock {
                $0.device = nil
                $0.needsRepair = true
            }
            notifyChange()
        }

        func clearPairing() {
            state.withLock {
                $0.device = nil
                $0.needsRepair = false
            }
            notifyChange()
        }

        func pairingStatus() -> PairingStatus {
            state.withLock { state in
                if let device = state.device {
                    return .paired(device)
                }
                return state.needsRepair ? .needsRepair : .unpaired
            }
        }

        func byokCredentials() -> BYOKCredentials? {
            state.withLock { $0.byok }
        }

        func saveBYOK(_ credentials: BYOKCredentials) throws {
            state.withLock { $0.byok = credentials }
            notifyChange()
        }

        func clearBYOK() {
            state.withLock { $0.byok = nil }
            notifyChange()
        }

        private func notifyChange() {
            notificationCenter.post(name: .pushPairingDidChange, object: nil)
        }
    }

    /// Emits scripted codes in place of the camera.
    final class StubQRCodeScanner: QRCodeScanning, @unchecked Sendable {
        private struct State: Sendable {
            var codes: [String]
            var isUnavailable: Bool
            var startCount = 0
            var stopCount = 0
        }

        private let state: OSAllocatedUnfairLock<State>

        init(codes: [String] = [], isUnavailable: Bool = false) {
            state = OSAllocatedUnfairLock(initialState: State(codes: codes, isUnavailable: isUnavailable))
        }

        var startCount: Int {
            state.withLock { $0.startCount }
        }

        var stopCount: Int {
            state.withLock { $0.stopCount }
        }

        func codes() async throws -> AsyncStream<String> {
            let current = state.withLock { state -> State in
                state.startCount += 1
                return state
            }
            if current.isUnavailable {
                throw QRScannerError.cameraUnavailable
            }
            return AsyncStream { continuation in
                current.codes.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        func stop() async {
            state.withLock { $0.stopCount += 1 }
        }

        @MainActor
        func makePreviewLayer() -> CALayer? {
            nil
        }
    }

    @MainActor
    final class StubCameraAuthorizer: CameraAuthorizing {
        var isGranted: Bool
        private(set) var requestCount = 0

        init(isGranted: Bool = true) {
            self.isGranted = isGranted
        }

        func requestAccess() async -> Bool {
            requestCount += 1
            return isGranted
        }
    }

    enum PushPairingFixture: String, CaseIterable {
        case unpaired
        case paired
        case needsRepair
        case cameraDenied
        case invalidCode
    }

    extension PushPairingViewModel {
        static let previewTopic = "com.igrsoft.Lock-Watcher"

        static func preview(_ fixture: PushPairingFixture = .unpaired) -> PushPairingViewModel {
            let store = switch fixture {
            case .paired:
                InMemoryAPNsCredentialStore(device: PairedDevice(token: String(repeating: "ab", count: 32),
                                                                 environment: .sandbox,
                                                                 topic: previewTopic,
                                                                 pairedAt: Date(timeIntervalSince1970: 1_793_000_000)))
            case .needsRepair:
                InMemoryAPNsCredentialStore(needsRepair: true)
            case .unpaired, .cameraDenied, .invalidCode:
                InMemoryAPNsCredentialStore()
            }
            let scanPhase: ScanPhase = switch fixture {
            case .cameraDenied: .cameraDenied
            case .invalidCode: .rejected(.notAPairingCode)
            case .unpaired, .paired, .needsRepair: .idle
            }
            return PushPairingViewModel(store: store,
                                        scanner: StubQRCodeScanner(),
                                        camera: StubCameraAuthorizer(isGranted: fixture != .cameraDenied),
                                        expectedTopic: { previewTopic },
                                        scanPhase: scanPhase)
        }
    }

    /// Every push state on one canvas, for previews and DV screenshots.
    struct PushSettingsGallery: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                ForEach([PushPairingFixture.unpaired, .paired, .needsRepair], id: \.self) { fixture in
                    PushSettingsView(isEnabled: .constant(true), model: .preview(fixture))
                    Divider()
                }
                HStack(alignment: .top, spacing: 16) {
                    PushPairingSheet(model: .preview(.cameraDenied))
                    PushPairingSheet(model: .preview(.invalidCode))
                }
            }
            .padding()
            .frame(width: 780)
        }
    }
#endif

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
