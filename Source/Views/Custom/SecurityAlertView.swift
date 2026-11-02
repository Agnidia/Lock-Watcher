//
//  SecurityAlertView.swift
//
//  Created on 02.02.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import SwiftUI

/// Represents a view for obtaining secure input, typically a password.
///
/// The user has the option to either confirm or cancel the action.
/// When either of the buttons is pressed, the alert view is dismissed.
struct SecurityAlertView: View {
    @Binding var password: String // Holds the value of the password entered by the user.
    @Binding var isPresented: Bool // Determines if the alert view is presented or not.

    var body: some View {
        VStack {
            // Displaying the prompt for the password.
            Text("EnterPassword")
                .font(DesignSystem.Typography.headline)
                .padding()
                .accessibilityIdentifier(AccessibilityID.SecurityAlert.passwordPrompt)
                .accessibilityLabel(AccessibilityLabel.SecurityAlert.enterPassword)

            // Secure field for password input.
            SecureField("", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding()
                .accessibilityIdentifier(AccessibilityID.SecurityAlert.passwordField)
                .accessibilityLabel(AccessibilityLabel.SecurityAlert.passwordField)

            Divider()

            HStack {
                Spacer()

                // OK Button: This will confirm the password input.
                Button(action: {
                    isPresented = false // Dismiss the alert view.
                }) {
                    Text("ButtonOk")
                }
                .accessibilityIdentifier(AccessibilityID.SecurityAlert.okButton)
                .accessibilityLabel(AccessibilityLabel.SecurityAlert.confirm)

                Spacer()

                Divider()

                Spacer()

                // Cancel Button: This will dismiss the alert without taking any action.
                Button(action: {
                    isPresented = false // Dismiss the alert view.
                }) {
                    Text("ButtonCancel")
                }
                .accessibilityIdentifier(AccessibilityID.SecurityAlert.cancelButton)
                .accessibilityLabel(AccessibilityLabel.SecurityAlert.cancel)

                Spacer()
            }
            .padding(.zero)
        }
        .background(DesignSystem.Colors.alertBackground) // Setting a light gray background.
        .accessibilityIdentifier(AccessibilityID.SecurityAlert.container)
    }
}

#Preview("Security Alert") {
    SecurityAlertView(password: .constant("1234"), isPresented: .constant(true))
}
