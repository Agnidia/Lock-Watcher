//
//  SettingsView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

@MainActor
struct SettingsView: View {
    /// The view model injected via environment.
    @Environment(SettingsViewModel.self) var viewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var animation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
    
    var body: some View {
        let _ = Self.logViewChanges()
        if viewModel.isAccessGranted {
            VStack(alignment: .leading) {
                Group {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            LaunchAtLoginView()
                            ProtectionView(isProtectionEnable: viewModel.isProtected, authSettings: viewModel.authSettings, securityUtil: SecurityUtil())
                        }
                        .extended(viewModel.isSecurityInfoExpand, titleKey: "SettingsMenuSecurity")
                    }
                    .accessibilityIdentifier(AccessibilityID.Settings.securitySection)

                    VStack(alignment: .leading) {
                        UseSnapshotOnWakeUpView(isUseSnapshotOnWakeUp: viewModel.isUseSnapshotOnWakeUp)
                            .onChange(of: viewModel.isUseSnapshotOnWakeUp.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                        UseSnapshotOnLoginView(isUseSnapshotOnLogin: viewModel.isUseSnapshotOnLogin)
                            .onChange(of: viewModel.isUseSnapshotOnLogin.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                        if AppSettings.isMASBuild == false {
                            UseSnapshotOnWrongPasswordView(isUseSnapshotOnWrongPassword: viewModel.isUseSnapshotOnWrongPassword)
                                .onChange(of: viewModel.isUseSnapshotOnWrongPassword.wrappedValue) { _, _ in
                                    viewModel.restartWatching()
                                }
                        }
                        if DeviceUtil().device() == .laptop {
                            UseSnapshotOnSwitchToBatteryPowerView(isUseSnapshotOnSwitchToBatteryPower: viewModel.isUseSnapshotOnSwitchToBatteryPower)
                                .onChange(of: viewModel.isUseSnapshotOnSwitchToBatteryPower.wrappedValue) { _, _ in
                                    viewModel.restartWatching()
                                }
                        }
                        UseSnapshotOnUSBMountView(isUseSnapshotOnUSBMount: viewModel.isUseSnapshotOnUSBMount)
                            .onChange(of: viewModel.isUseSnapshotOnUSBMount.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                        UseSnapshotOnDisplayAttachView(isUseSnapshotOnDisplayAttach: viewModel.isUseSnapshotOnDisplayAttach)
                            .onChange(of: viewModel.isUseSnapshotOnDisplayAttach.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                        UseSnapshotOnLocationChangeView(isUseSnapshotOnLocationChange: viewModel.isUseSnapshotOnLocationChange)
                        UseSnapshotOnLockedInputView(isUseSnapshotOnLockedInput: viewModel.isUseSnapshotOnLockedInput,
                                                     lockedInputDelay: viewModel.lockedInputDelay)
                            .onChange(of: viewModel.isUseSnapshotOnLockedInput.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                            .onChange(of: viewModel.lockedInputDelay.wrappedValue) { _, _ in
                                viewModel.restartWatching()
                            }
                    }
                    .extended(viewModel.isSnapshotInfoExpand, titleKey: "SettingsMenuSnapshot")
                    .accessibilityIdentifier(AccessibilityID.Settings.snapshotSection)

                    VStack(alignment: .leading) {
                        KeepLastCountView(keepLastActionsCount: viewModel.keepLastActionsCount)

                        AddLocationToSnapshotView(addLocationToSnapshot: viewModel.addLocationToSnapshot, requestAuthorization: viewModel.requestSnapshotLocationAuthorization)
                            .onChange(of: viewModel.addLocationToSnapshot.wrappedValue) { _, value in
                                viewModel.setupLocationManager(enable: value)
                            }

                        AddIPAddressToSnapshotView(addIPAddressToSnapshot: viewModel.addIPAddressToSnapshot)

                        TraceRouteToSnapshotView(isAddTraceRouteToSnapshot: viewModel.addTraceRouteToSnapshot, traceRouteServer: viewModel.traceRouteServer)

                        SaveSnapshotToDiskView(isSaveSnapshotToDisk: viewModel.isSaveSnapshotToDisk)

                        SnapshotOutputTypeView(outputType: viewModel.snapshotOutputType)
                        if viewModel.showsVideoDuration {
                            VideoDurationView(videoDuration: viewModel.snapshotVideoDuration)
                        }
                        if viewModel.showsSnapshotQuality {
                            SnapshotQualityView(snapshotQuality: viewModel.snapshotQuality)
                        }
                        SnapshotOutputSizeView(outputSize: viewModel.snapshotOutputSize)
                        KeepFilesView(keepFiles: viewModel.keepFiles,
                                      pendingKeepFiles: viewModel.pendingKeepFiles,
                                      confirm: viewModel.confirmKeepFiles,
                                      cancel: viewModel.cancelPendingKeepFiles)
                    }
                    .extended(viewModel.isOptionsInfoExpand, titleKey: "SettingsMenuOptions")
                    .accessibilityIdentifier(AccessibilityID.Settings.optionsSection)

                    VStack(alignment: .leading) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            if AppSettings.isMASBuild == false {
                                SendNotificationToMailView(isSendNotificationToMail: viewModel.isSendNotificationToMail, mailRecipient: viewModel.mailRecipient)
                            }
                            ICloudSyncView(isICloudSyncEnable: viewModel.isICloudSyncEnable)

                            DropboxView(isDropboxEnable: viewModel.isDropboxEnable, dropboxName: viewModel.dropboxName)

                            LocalNotificationView(isLocalNotificationEnable: viewModel.isUseSnapshotLocalNotification)
                        }
                    }
                    .extended(viewModel.isSyncInfoExpand, titleKey: "SettingsMenuSync")
                    .accessibilityIdentifier(AccessibilityID.Settings.syncSection)
                }
                .frame(alignment: .top)
            }
            .padding(viewModel.viewSettings.border)
            .frame(width: viewModel.viewSettings.window.width, alignment: .top)
            .accessibilityIdentifier(AccessibilityID.Settings.container)
            .onAppear(perform: viewModel.refreshLocationAuthorization)
        } else {
            Text("")
                .onAppear {
                    viewModel.accessGrantedBlock?()
                }
        }
    }
}

#Preview("Settings View") {
    SettingsView()
        .environment(SettingsViewModel.preview)
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/SettingsViewModelTests.swift
