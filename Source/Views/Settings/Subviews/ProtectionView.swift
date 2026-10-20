//
//  ProtectionView.swift
//
//  Created on 23.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A view component that provides a user interface for enabling protection access to the application.
/// The user can toggle the protection on or off and set a password to protect the access.
struct ProtectionView: View {
    /// A binding that determines if protection is enabled or not.
    @Binding var isProtectionEnable: Bool

    @Binding var authSettings: AuthSettings

    /// A state to manage the value of the password entered by the user.
    @State var password: String = ""

    var securityUtil: SecurityUtilProtocol

    /// The body of the view, containing a toggle to enable/disable protection, a secure field for password input, and a button to set the password.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // A toggle that allows the user to enable or disable protection.
                Toggle(isOn: $isProtectionEnable) {
                    Text("ProtectAccess")
                }
                .accessibilityIdentifier(AccessibilityID.Settings.protectionToggle)
                .accessibilityLabel(AccessibilityLabel.Settings.protectAccess)
                .accessibilityHint(AccessibilityHint.Settings.toggleHint)

                // A secure field that allows the user to input a password.
                SecureField("ProtectPassword", text: $password)
                    .textFieldStyle(.roundedBorder)
                    // Disable password input if protection is turned off.
                    .disabled(isProtectionEnable == false || authSettings == .biometricsOrWatch)
                    .accessibilityIdentifier(AccessibilityID.Settings.passwordField)
                    .accessibilityHint(AccessibilityHint.Settings.passwordHint)

                // A button that allows the user to set the entered password.
                Button("ButtonSet") {
                    Task { [securityUtil, psw = password] in
                        await securityUtil.save(password: psw)
                    }
                    password = "" // Clear the password field after saving.
                }
                // Disable the set button if protection is turned off or password field is empty.
                .disabled(isProtectionEnable == false || password.isEmpty || authSettings == .biometricsOrWatch)
                .accessibilityIdentifier(AccessibilityID.Settings.setPasswordButton)
                .accessibilityLabel(AccessibilityLabel.Settings.setPassword)
            }
            Toggle(isOn: biometryToggle) {
                Text("BiometryAllowed")
            }
            .disabled(!isProtectionEnable)
            .accessibilityIdentifier(AccessibilityID.Settings.biometryToggle)
            .accessibilityLabel(AccessibilityLabel.Settings.biometryAllowed)
            .accessibilityHint(AccessibilityHint.Settings.toggleHint)
        }
    }

    private var biometryToggle: Binding<Bool> {
        .init(
            get: {
                authSettings == .biometricsOrWatch
            },
            set: { isOn in
                authSettings = isOn ? .biometricsOrWatch : .empty
            }
        )
    }
}

#Preview("Protection Enabled") {
    ProtectionView(isProtectionEnable: .constant(true), authSettings: .constant(.biometricsOrWatch), securityUtil: SecurityUtil.preview)
}

#Preview("Protection Disabled") {
    ProtectionView(isProtectionEnable: .constant(false), authSettings: .constant(.biometricsOrWatch), securityUtil: SecurityUtil.preview)
}
