//
//  PushSettingsView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import SwiftUI

/// The push channel block in the Sync section.
struct PushSettingsView: View {
    @Binding var isEnabled: Bool
    @Bindable var model: PushPairingViewModel

    /// The toggle, the pairing status row and the advanced key row. The task and the sheet sit on the toggle so they run once.
    var body: some View {
        Toggle(isOn: $isEnabled) {
            Text("PushToiPhone")
        }
        .help("PushToiPhoneHelp")
        .accessibilityIdentifier(AccessibilityID.Settings.pushToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.pushToiPhone)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
        .task { await model.refresh() }
        .sheet(isPresented: $model.isPairingSheetPresented) {
            PushPairingSheet(model: model)
        }

        PushPairingStatusView(phase: PushBlockPhase.make(isEnabled: isEnabled, pairing: model.pairing), model: model)

        if isEnabled, !AppSettings.isMASBuild {
            OwnAPNsKeyView(model: model)
        }
    }
}

/// What the iPhone companion is and where to get it. The companion shares the Mac app's App Store record (universal purchase), so one link serves both.
struct CompanionDownloadView: View {
    static let storeURL = URL(string: "https://apps.apple.com/app/lock-watcher/id1583462846")!

    @Environment(\.openURL) private var openURL

    var body: some View {
        LabeledContent {
            Button {
                openURL(Self.storeURL)
            } label: {
                Label("CompanionDownload", systemImage: "arrow.down.app")
            }
            .accessibilityIdentifier(AccessibilityID.Settings.companionDownloadButton)
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("CompanionInfoTitle")
                Text("CompanionInfoMessage")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PushPairingStatusView: View {
    let phase: PushBlockPhase
    let model: PushPairingViewModel

    var body: some View {
        switch phase {
        case .disabled:
            EmptyView()
        case .unpaired:
            LabeledContent {
                Button("PushPairIPhone", action: model.startPairing)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushPairButton)
            } label: {
                Text("PushNotPaired")
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        case .paired(_, let pairedAt):
            LabeledContent {
                Button("PushForgetIPhone", role: .destructive, action: model.forget)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushForgetButton)
            } label: {
                Label(String(format: NSLocalizedString("PushPairedOn %@", comment: ""), pairedAt.formatted(date: .abbreviated, time: .shortened)),
                      systemImage: "iphone")
            }
        case .needsRepair:
            LabeledContent {
                Button("PushRepairIPhone", action: model.startPairing)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushRepairButton)
            } label: {
                Label("PushNeedsRepair", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct PushPairingSheet: View {
    let model: PushPairingViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("PushPairTitle")
                .font(.headline)
            Text("PushPairInstructions")
                .font(DesignSystem.Typography.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            scannerArea
                .frame(width: 320, height: 240)
                .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if case .rejected(let issue) = model.scanPhase {
                Text(LocalizedStringKey(issue.messageKey))
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(.red)
            }
            Button("ButtonCancel", role: .cancel, action: model.cancelPairing)
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 360)
        .accessibilityIdentifier(AccessibilityID.Settings.pushPairingSheet)
        .task {
            await model.runScan()
        }
    }

    @ViewBuilder
    private var scannerArea: some View {
        switch model.scanPhase {
        case .cameraDenied:
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("PushCameraDenied")
                    .multilineTextAlignment(.center)
                Button("PushOpenCameraSettings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding()
        case .cameraUnavailable:
            Text("PushCameraUnavailable")
                .multilineTextAlignment(.center)
                .padding()
        case .idle, .requestingAccess:
            ProgressView()
        case .scanning, .rejected:
            QRScannerPreview(scanner: model.scanner)
                .overlay(alignment: .bottom) {
                    Text("PushScanning")
                        .font(DesignSystem.Typography.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                }
        }
    }
}

/// Advanced: the owner's own APNs key, for a companion built under the owner's team.
struct OwnAPNsKeyView: View {
    let model: PushPairingViewModel

    @State private var keyID = ""
    @State private var teamID = ""
    @State private var topic = ""
    @State private var pem = ""
    @State private var isInvalid = false

    var body: some View {
        DisclosureGroup("PushOwnKeyTitle") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if model.hasOwnKey {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("PushOwnKeyInUse")
                            .font(DesignSystem.Typography.footnote)
                        Button("PushOwnKeyClear", role: .destructive, action: model.clearOwnKey)
                    }
                } else {
                    TextField("PushOwnKeyID", text: $keyID)
                    TextField("PushOwnTeamID", text: $teamID)
                    TextField("PushOwnTopic", text: $topic)
                    SecureField("PushOwnKeyPEM", text: $pem)
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("PushOwnKeySave", action: save)
                            .disabled(keyID.isEmpty || teamID.isEmpty || topic.isEmpty || pem.isEmpty)
                        if isInvalid {
                            Text("PushOwnKeyInvalid")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Text("PushOwnKeyFootnote")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() {
        isInvalid = !model.saveOwnKey(keyID: keyID, teamID: teamID, topic: topic, pem: pem)
        pem = ""
        if !isInvalid {
            keyID = ""
            teamID = ""
            topic = ""
        }
    }
}

#if DEBUG
    #Preview("Push block") {
        PushSettingsGallery()
    }

    #Preview("Companion download") {
        Form {
            CompanionDownloadView()
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }

    #Preview("Pairing status") {
        let model = PushPairingViewModel.preview()
        let phases: [PushBlockPhase] = [
            .disabled,
            .unpaired,
            .paired(environment: .sandbox, pairedAt: Date(timeIntervalSince1970: 1_793_000_000)),
            .needsRepair,
        ]

        Form {
            ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                PushPairingStatusView(phase: phase, model: model)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }

    #Preview("Pairing sheet") {
        PushPairingSheet(model: .preview(.unpaired))
    }

    #Preview("Own APNs key") {
        Form {
            OwnAPNsKeyView(model: .preview())
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
#endif

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
