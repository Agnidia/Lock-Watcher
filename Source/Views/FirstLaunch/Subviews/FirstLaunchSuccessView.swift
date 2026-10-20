//
//  FirstLaunchSuccessView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that presents a success message and visuals to the user when the initial setup completes successfully.
struct FirstLaunchSuccessView: View {
    /// The count-down timer value that informs the user about the time left before proceeding.
    let successCountDown: Int

    /// The frame size for adjusting visual elements within this view.
    let frameSize: CGSize

    /// The body property that returns the content of the view.
    var body: some View {
        VStack {
            // Label showing a success message along with an associated system image.
            Label("SetupSuccess", systemImage: "bolt.circle")
                .font(.system(size: frameSize.height * 0.2))
                .padding(.horizontal)
                .foregroundColor(DesignSystem.Colors.success)
                .accessibilityLabel(AccessibilityLabel.FirstLaunch.success)

            // Text that provides additional information or tips after the successful setup.
            Text("Tips0")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.success)

            // Image providing a visual tip or guide for the user after the successful setup.
            Image("tips0").aspectRatio(contentMode: .fit)
                .frame(width: frameSize.width, alignment: .center)
                .accessibilityHidden(true)

            // Countdown timer text, showing the user how much time is left before moving on.
            Text(PluralLocalization.string("SuccessTimer %d", count: successCountDown))
                .font(DesignSystem.Typography.body)
                .accessibilityIdentifier(AccessibilityID.FirstLaunch.successCountdown)
                .accessibilityLabel(AccessibilityLabel.FirstLaunch.countdown(successCountDown))
        }
    }
}

#Preview("Success View") {
    FirstLaunchSuccessView(successCountDown: 5, frameSize: CGSize(width: 400, height: 300))
}

// MARK: - Test Info

// @test-file: Tests/Utils/PluralLocalizationTests.swift
// @test-coverage: Visible countdown uses the same count as its VoiceOver label.
