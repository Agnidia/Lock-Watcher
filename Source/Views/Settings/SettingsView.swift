//
//  SettingsView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// The settings window: a sidebar of pages, and the selected page as a grouped form, as in System Settings.
@MainActor
struct SettingsView: View {
    /// The view model injected via environment.
    @Environment(SettingsViewModel.self) var viewModel

    /// The sidebar list needs an optional selection; a deselect is ignored so a page is always open.
    private var selection: Binding<SettingsPage?> {
        Binding(
            get: { viewModel.selectedPage.wrappedValue },
            set: { page in
                if let page {
                    viewModel.selectedPage.wrappedValue = page
                }
            }
        )
    }

    var body: some View {
        let _ = Self.logViewChanges()
        if viewModel.isAccessGranted {
            NavigationSplitView(columnVisibility: .constant(.all)) {
                sidebar
            } detail: {
                detail(viewModel.selectedPage.wrappedValue)
            }
            .toolbar(removing: .sidebarToggle)
            .frame(width: viewModel.viewSettings.window.width, height: viewModel.viewSettings.window.height)
            .accessibilityIdentifier(AccessibilityID.Settings.container)
            .onAppear(perform: viewModel.refreshLocationAuthorization)
        } else {
            Text("")
                .onAppear {
                    viewModel.accessGrantedBlock?()
                }
        }
    }

    private var sidebar: some View {
        List(SettingsPage.allCases, selection: selection) { page in
            Label {
                Text(LocalizedStringKey(page.titleKey))
            } icon: {
                SettingsSidebarIcon(page: page)
            }
            .tag(page)
            .accessibilityIdentifier(AccessibilityID.Settings.sidebarItem(page.rawValue))
        }
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(DesignSystem.Layout.settingsSidebarWidth)
        .accessibilityIdentifier(AccessibilityID.Settings.sidebar)
    }

    /// About is a finished view of its own, so it fills the pane instead of sitting in a grouped form.
    @ViewBuilder
    private func detail(_ page: SettingsPage) -> some View {
        if page == .about {
            SettingsAboutView()
                .navigationTitle(Text(LocalizedStringKey(page.titleKey)))
        } else {
            SettingsPageForm(page: page) {
                pageContent(page)
            }
        }
    }

    @ViewBuilder
    private func pageContent(_ page: SettingsPage) -> some View {
        switch page {
        case .about: EmptyView()
        case .security: securityPage
        case .snapshot: snapshotPage
        case .capture: capturePage
        case .options: optionsPage
        case .sync: syncPage
        case .notifications: notificationsPage
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var securityPage: some View {
        Section {
                LaunchAtLoginView()
            }
            Section {
                ProtectionView(isProtectionEnable: viewModel.isProtected, authSettings: viewModel.authSettings, securityUtil: SecurityUtil())
            }
    }

    private var snapshotPage: some View {
        Section {
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
        }
        // The locked-input view is two rows, so its watchers sit on the section, once.
        .onChange(of: viewModel.isUseSnapshotOnLockedInput.wrappedValue) { _, _ in
            viewModel.restartWatching()
        }
        .onChange(of: viewModel.lockedInputDelay.wrappedValue) { _, _ in
            viewModel.restartWatching()
        }
    }

    private var capturePage: some View {
        Section {
            SnapshotOutputTypeView(outputType: viewModel.snapshotOutputType)
            if viewModel.showsVideoDuration {
                VideoDurationView(videoDuration: viewModel.snapshotVideoDuration)
            }
            if viewModel.showsSnapshotQuality {
                SnapshotQualityView(snapshotQuality: viewModel.snapshotQuality)
            }
            SnapshotOutputSizeView(outputSize: viewModel.snapshotOutputSize)
        }
    }

    private var optionsPage: some View {
        Section {
                KeepLastCountView(keepLastActionsCount: viewModel.keepLastActionsCount)

                AddLocationToSnapshotView(addLocationToSnapshot: viewModel.addLocationToSnapshot, requestAuthorization: viewModel.requestSnapshotLocationAuthorization)
                    .onChange(of: viewModel.addLocationToSnapshot.wrappedValue) { _, value in
                        viewModel.setupLocationManager(enable: value)
                    }

                AddIPAddressToSnapshotView(addIPAddressToSnapshot: viewModel.addIPAddressToSnapshot)

                TraceRouteToSnapshotView(isAddTraceRouteToSnapshot: viewModel.addTraceRouteToSnapshot, traceRouteServer: viewModel.traceRouteServer)
            }
    }

    @ViewBuilder
    private var syncPage: some View {
        Section {
            if AppSettings.isMASBuild == false {
                SendNotificationToMailView(isSendNotificationToMail: viewModel.isSendNotificationToMail, mailRecipient: viewModel.mailRecipient)
            }
            ICloudSyncView(isICloudSyncEnable: viewModel.isICloudSyncEnable, browse: { Task { await viewModel.openICloudFolder() } })
            DropboxView(isDropboxEnable: viewModel.isDropboxEnable, dropboxName: viewModel.dropboxName)
        }
        // Local copies sit under the cloud services: the retention footnote covers both rows.
        Section {
            SaveSnapshotToDiskView(isSaveSnapshotToDisk: viewModel.isSaveSnapshotToDisk, browse: viewModel.openLocalFolder)
            KeepFilesView(keepFiles: viewModel.keepFiles,
                          pendingKeepFiles: viewModel.pendingKeepFiles,
                          confirm: viewModel.confirmKeepFiles,
                          cancel: viewModel.cancelPendingKeepFiles)
        } footer: {
            Text("KeepFilesFootnote")
                .accessibilityIdentifier(AccessibilityID.Settings.keepFilesFootnote)
        }
    }

    @ViewBuilder
    private var notificationsPage: some View {
        Section {
            LocalNotificationView(isLocalNotificationEnable: viewModel.isUseSnapshotLocalNotification)
        }
        Section {
            PushSettingsView(isEnabled: viewModel.isSendPushEnable, model: viewModel.push)
        }
        Section {
            CompanionDownloadView()
        }
    }
}

/// A page's grouped form with its title in the toolbar, like a System Settings pane.
private struct SettingsPageForm<Content: View>: View {
    let page: SettingsPage
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .navigationTitle(Text(LocalizedStringKey(page.titleKey)))
        .accessibilityIdentifier(AccessibilityID.Settings.page(page.rawValue))
    }
}

/// The coloured rounded square with a white symbol that System Settings puts before each sidebar row.
private struct SettingsSidebarIcon: View {
    let page: SettingsPage

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: DesignSystem.Layout.settingsSidebarIconSize, height: DesignSystem.Layout.settingsSidebarIconSize)
            .background(page.tint.gradient, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview("Settings View") {
    SettingsView()
        .environment(SettingsViewModel.preview)
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/SettingsViewModelTests.swift
