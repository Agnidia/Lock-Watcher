//
//  FirstLaunchFaultViews.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that presents a fault message and action to guide the user when there's a setup fault on first launch.
struct FirstLaunchFaultViews: View {
    /// A binding that informs if this fault view should be hidden.
    @Binding var isHidden: Bool

    /// The frame size for adjusting visual elements within this view.
    @State var frameSize: CGSize

    /// The body property that returns the content of the view.
    var body: some View {
        VStack {
            // Label showing a fault message along with an associated system image.
            Label("SetupFault", systemImage: "exclamationmark.circle")
                .font(.system(size: frameSize.height * 0.25))
                .padding(.horizontal)
                .foregroundColor(DesignSystem.Colors.error)
                .accessibilityLabel(AccessibilityLabel.FirstLaunch.fault)

            // Additional text message providing more information about the fault.
            Text("SetupFaultMessage")
                .font(DesignSystem.Typography.headline)

            // Button that directs the user to open their system settings.
            Button("SetupOpenSettings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                isHidden = true
            }
            .accessibilityIdentifier(AccessibilityID.FirstLaunch.openSettingsButton)
            .accessibilityLabel(AccessibilityLabel.FirstLaunch.openCameraSettings)
        }
    }
}

#Preview("Fault View") {
    FirstLaunchFaultViews(isHidden: .constant(false), frameSize: CGSize(width: 400, height: 300))
}
