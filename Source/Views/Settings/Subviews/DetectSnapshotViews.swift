//
//  DetectSnapshotViews.swift
//
//  Created on 23.08.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

/// A view component that provides a toggle for the user to enable or disable snapshot functionality upon system wake up.
struct UseSnapshotOnWakeUpView: View {
    /// A binding to a boolean value that indicates whether the snapshot on wake up feature is enabled or disabled.
    @Binding var isUseSnapshotOnWakeUp: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnWakeUp) {
            Text("SnapshotOnWakeUp")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.wakeUpToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnWakeUp)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that provides a toggle for the user to enable or disable snapshot functionality upon system login.
struct UseSnapshotOnLoginView: View {
    /// A binding to a boolean value that indicates whether the snapshot on login feature is enabled or disabled.
    @Binding var isUseSnapshotOnLogin: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnLogin) {
            Text("SnapshotOnLogin")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.loginToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnLogin)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that provides a toggle for the user to enable or disable snapshot functionality when the wrong password is entered.
struct UseSnapshotOnWrongPasswordView: View {
    /// A binding to a boolean value that indicates whether the snapshot on wrong password feature is enabled or disabled.
    @Binding var isUseSnapshotOnWrongPassword: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnWrongPassword) {
            Text("SnapshotOnWrongPassword")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.wrongPasswordToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnWrongPassword)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that provides a toggle for the user to enable or disable snapshot functionality when the system switches to battery power.
struct UseSnapshotOnSwitchToBatteryPowerView: View {
    /// A binding to a boolean value that indicates whether the snapshot on switch to battery power feature is enabled or disabled.
    @Binding var isUseSnapshotOnSwitchToBatteryPower: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnSwitchToBatteryPower) {
            Text("SnapshotOnSwitchToBatteryPower")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.batteryToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnBattery)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A view component that provides a toggle for the user to enable or disable snapshot functionality when a USB is mounted.
struct UseSnapshotOnUSBMountView: View {
    /// A binding to a boolean value that indicates whether the snapshot on USB mount feature is enabled or disabled.
    @Binding var isUseSnapshotOnUSBMount: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnUSBMount) {
            Text("SnapshotOnUSBMount")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.usbToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnUSB)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A toggle for taking a snapshot when a display is attached while the Mac is locked.
struct UseSnapshotOnDisplayAttachView: View {
    @Binding var isUseSnapshotOnDisplayAttach: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnDisplayAttach) {
            Text("SnapshotOnDisplayAttach")
        }
        .accessibilityIdentifier(AccessibilityID.Settings.displayAttachToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnDisplayAttach)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A toggle for taking a snapshot when the Mac moves while locked.
struct UseSnapshotOnLocationChangeView: View {
    @Binding var isUseSnapshotOnLocationChange: Bool

    var body: some View {
        Toggle(isOn: $isUseSnapshotOnLocationChange) {
            Text("SnapshotOnLocationChange")
        }
        .help(Text("SnapshotOnLocationChangeHelp"))
        .accessibilityIdentifier(AccessibilityID.Settings.locationChangeToggle)
        .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnLocationChange)
        .accessibilityHint(AccessibilityHint.Settings.toggleHint)
    }
}

/// A toggle for taking a snapshot on keyboard or mouse input while the Mac is locked.
@MainActor
struct UseSnapshotOnLockedInputView: View {
    @Binding var isUseSnapshotOnLockedInput: Bool
    @Binding var lockedInputDelay: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $isUseSnapshotOnLockedInput) {
                StableCountLabel(key: "SnapshotOnLockedInput %d", count: lockedInputDelay, range: TriggerSettings.lockedInputDelayRange)
            }
            .accessibilityIdentifier(AccessibilityID.Settings.lockedInputToggle)
            .accessibilityLabel(AccessibilityLabel.Settings.snapshotOnLockedInput(lockedInputDelay))
            .accessibilityHint(AccessibilityHint.Settings.toggleHint)

            Stepper(value: $lockedInputDelay, in: TriggerSettings.lockedInputDelayRange) {
                EmptyView()
            }
            .labelsHidden()
            .disabled(!isUseSnapshotOnLockedInput)
            .accessibilityIdentifier(AccessibilityID.Settings.lockedInputDelayStepper)
            .accessibilityLabel(AccessibilityLabel.Settings.lockedInputDelay)
            .accessibilityValue(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: lockedInputDelay))
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/PluralLocalizationTests.swift
// @related-tests: Tests/ViewModels/SettingsViewModelTests.swift
// @test-coverage: Locked-input visible, spoken, and stepper-value counts use plural variants.
