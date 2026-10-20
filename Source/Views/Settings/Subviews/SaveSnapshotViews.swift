//
//  SaveSnapshotViews.swift
//
//  Created on 26.12.2021.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CameraSnap
import SwiftUI

@MainActor
struct StableCountLabel: View {
    let key: String
    let count: Int
    let range: ClosedRange<Int>
    var bundle: Bundle = .main

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(range), id: \.self) { candidate in
                Text(PluralLocalization.string(key, count: candidate, bundle: bundle))
                    .hidden()
                    .accessibilityHidden(true)
            }
            Text(PluralLocalization.string(key, count: count, bundle: bundle))
        }
    }
}

/// A view component that allows the user to determine the number of last actions to keep.
@MainActor
struct KeepLastCountView: View {
    @Binding var keepLastActionsCount: Int

    var body: some View {
        Stepper(value: $keepLastActionsCount, in: 1 ... 30) {
            StableCountLabel(key: "KeepLastN %d", count: keepLastActionsCount, range: 1 ... 30)
        }
        .accessibilityIdentifier(AccessibilityID.Settings.keepLastStepper)
        .accessibilityLabel(AccessibilityLabel.Settings.keepLast(keepLastActionsCount))
    }
}

/// A view component that allows the user to toggle whether to send notifications via email,
/// and to specify the recipient email.
struct SendNotificationToMailView: View {
    @Binding var isSendNotificationToMail: Bool
    @Binding var mailRecipient: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $isSendNotificationToMail) {
                Text("SendToMail")
            }
            .accessibilityIdentifier(AccessibilityID.Settings.emailToggle)
            .accessibilityLabel(AccessibilityLabel.Settings.sendEmail)
            .accessibilityHint(AccessibilityHint.Settings.toggleHint)

            TextField("user@example.com", text: $mailRecipient)
                .disabled(isSendNotificationToMail == false)
                .accessibilityIdentifier(AccessibilityID.Settings.emailField)
        }
    }
}

/// A view component that allows the user to toggle whether to add location information to the snapshot.
@MainActor
struct AddLocationToSnapshotView: View {
    @Binding var addLocationToSnapshot: Bool
    let requestAuthorization: @MainActor (@escaping @MainActor (Bool) -> Void) -> Void

    @State private var showingAlert = false

    var body: some View {
        Toggle(isOn: $addLocationToSnapshot) {
            Text("AddLocationToSnapshot")
        }
        .onChange(of: addLocationToSnapshot) { _, value in
            if value {
                requestAuthorization { isGranted in
                    showingAlert = !isGranted
                }
            }
        }
        .alert("OpenSettings", isPresented: $showingAlert) {
            Button("ButtonSettings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                addLocationToSnapshot = false
            }
            Button("ButtonCancel", role: .cancel) {
                addLocationToSnapshot = false
            }
        }
        .accessibilityIdentifier(AccessibilityID.Settings.locationToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.addLocation)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that allows the user to toggle whether to add IP address information to the snapshot.
struct AddIPAddressToSnapshotView: View {
    @Binding var addIPAddressToSnapshot: Bool

    var body: some View {
        Toggle(isOn: $addIPAddressToSnapshot) {
            Text("AddIPAddressToSnapshot")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.ipAddressToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.addIPAddress)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that allows the user to toggle whether to add a traceroute to the snapshot,
/// and to specify the traceroute server.
struct TraceRouteToSnapshotView: View {
    @Binding var isAddTraceRouteToSnapshot: Bool
    @Binding var traceRouteServer: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $isAddTraceRouteToSnapshot) {
                Text("AddTraceRoute")
            }
            .accessibilityIdentifier(AccessibilityID.Settings.traceRouteToggle)
            .accessibilityLabel(AccessibilityLabel.Settings.addTraceRoute)
            .accessibilityHint(AccessibilityHint.Settings.toggleHint)

            TextField("example.com", text: $traceRouteServer)
                .disabled(isAddTraceRouteToSnapshot == false)
                .accessibilityIdentifier(AccessibilityID.Settings.traceRouteServerField)
        }
    }
}

/// A view component that allows the user to toggle whether to save the snapshot to disk.
struct SaveSnapshotToDiskView: View {
    @Binding var isSaveSnapshotToDisk: Bool

    var body: some View {
        Toggle(isOn: $isSaveSnapshotToDisk) {
            Text("SaveSnapshotToDisk")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.saveToDiskToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.saveToDisk)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that allows the user to select the JPEG compression quality for snapshots.
struct SnapshotQualityView: View {
    @Binding var snapshotQuality: SnapshotQuality

    var body: some View {
        Picker(selection: $snapshotQuality) {
            Text("SnapshotQualityLow").tag(SnapshotQuality.low)
            Text("SnapshotQualityMedium").tag(SnapshotQuality.medium)
            Text("SnapshotQualityHigh").tag(SnapshotQuality.high)
            Text("SnapshotQualityOriginal").tag(SnapshotQuality.original)
        } label: {
            Text("SnapshotQuality")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityID.Settings.snapshotQualityPicker)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotQuality)
    }
}

/// A view component that allows the user to choose between a photo and a video.
struct SnapshotOutputTypeView: View {
    @Binding var outputType: CaptureOutputType

    var body: some View {
        Picker(selection: $outputType) {
            Text("OutputTypePhoto").tag(CaptureOutputType.photo)
            Text("OutputTypeVideo").tag(CaptureOutputType.video)
        } label: {
            Text("OutputType")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityID.Settings.outputTypePicker)
        .accessibilityLabel(AccessibilityLabel.Settings.outputType)
    }
}

/// A view component that allows the user to set the video length.
@MainActor
struct VideoDurationView: View {
    @Binding var videoDuration: Int

    var body: some View {
        Stepper(value: $videoDuration, in: SnapshotSettings.videoDurationRange) {
            StableCountLabel(key: "VideoDuration %d", count: videoDuration, range: SnapshotSettings.videoDurationRange)
        }
        .accessibilityIdentifier(AccessibilityID.Settings.videoDurationStepper)
        .accessibilityLabel(AccessibilityLabel.Settings.videoDuration(videoDuration))
    }
}

/// A view component that allows the user to select the capture size for photos and videos.
struct SnapshotOutputSizeView: View {
    @Binding var outputSize: CameraSnapConfiguration.OutputSize

    var body: some View {
        Picker(selection: $outputSize) {
            ForEach(CameraSnapConfiguration.OutputSize.allCases, id: \.self) { size in
                Text(LocalizedStringKey(size.rawValue)).tag(size)
            }
        } label: {
            Text("OutputSize")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityID.Settings.outputSizePicker)
        .accessibilityLabel(AccessibilityLabel.Settings.outputSize)
    }
}

/// A view component that allows the user to choose how long local capture files are kept.
struct KeepFilesView: View {
    @Binding var keepFiles: RetentionPeriod
    let pendingKeepFiles: RetentionPeriod?
    let confirm: (RetentionPeriod) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Picker(selection: $keepFiles) {
                ForEach(RetentionPeriod.allCases, id: \.self) { period in
                    Text(period.title).tag(period)
                }
            } label: {
                Text("KeepFiles")
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(AccessibilityID.Settings.keepFilesPicker)
            .accessibilityLabel(AccessibilityLabel.Settings.keepFiles)

            Text("KeepFilesFootnote")
                .font(DesignSystem.Typography.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.Settings.keepFilesFootnote)
        }
        .alert("KeepFilesConfirmTitle", isPresented: isConfirming, presenting: pendingKeepFiles) { period in
            Button("KeepFilesConfirmButton", role: .destructive) { confirm(period) }
            Button("ButtonCancel", role: .cancel, action: cancel)
        } message: { period in
            Text(String(format: NSLocalizedString("KeepFilesConfirmMessage %@", comment: ""), period.title))
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingKeepFiles != nil }, set: {
            if !$0 {
                cancel()
            }
        })
    }
}

/// A view component that allows the user to toggle iCloud synchronization.
struct ICloudSyncView: View {
    @Binding var isICloudSyncEnable: Bool

    var body: some View {
        Toggle(isOn: $isICloudSyncEnable) {
            Text("SyncWithiCloud")
        }
        .disabled(FileManager.default.ubiquityIdentityToken == nil)
        .help("SyncWithiCloudHelp")
        .accessibilityIdentifier(AccessibilityID.Settings.iCloudToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.syncICloud)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that provides options for synchronizing with Dropbox.
/// It shows different options based on whether the user is already authenticated with Dropbox.
struct DropboxView: View {
    @Binding var isDropboxEnable: Bool
    @Binding var dropboxName: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if dropboxName.isEmpty == false {
                Toggle(isOn: $isDropboxEnable) {
                    Text(String(format: NSLocalizedString("SyncedWithDropbox %@", comment: ""), dropboxName))
                }
                .accessibilityIdentifier(AccessibilityID.Settings.dropboxToggle)
                .accessibilityLabel(AccessibilityLabel.Settings.syncDropbox)

                Button("Logout") {
                    DropboxNotifier.logout()
                    dropboxName = ""
                }
                .disabled(isDropboxEnable == false)
                .accessibilityIdentifier(AccessibilityID.Settings.dropboxLogoutButton)

            } else {
                Toggle(isOn: $isDropboxEnable) {
                    Text("SyncWithDropbox")
                }
                .accessibilityIdentifier(AccessibilityID.Settings.dropboxToggle)
                .accessibilityLabel(AccessibilityLabel.Settings.syncDropbox)
                .accessibilityHint(AccessibilityHint.Settings.toggleHint)

                Button("Authorize") {
                    DropboxNotifier.authorize(on: NSViewController())
                }
                .disabled(isDropboxEnable == false)
                .accessibilityIdentifier(AccessibilityID.Settings.dropboxAuthButton)
            }
        }
    }
}

/// A view component that allows the user to toggle local notifications.
struct LocalNotificationView: View {
    @Binding var isLocalNotificationEnable: Bool

    var body: some View {
        Toggle(isOn: $isLocalNotificationEnable) {
            Text("PushLocalNotification")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.notificationToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.localNotification)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/PluralLocalizationTests.swift
// @related-tests: Tests/ViewModels/SettingsViewModelTests.swift
// @test-coverage: Visible keep-last and video-duration labels share count forms with VoiceOver.
