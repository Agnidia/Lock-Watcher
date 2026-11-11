//
//  SettingsAboutView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CustomizedAboutView
import SwiftUI

/// The About page: app identity from the bundle, links, and the other Agnidia apps loaded from the App Store.
struct SettingsAboutView: View {
    /// This app's sibling apps shown as cards; the lookup runs when the page opens.
    static let appStoreIDs = [6_759_503_967, 1_661_688_468, 6_471_902_188]

    var body: some View {
        CustomizedAboutView(
            configuration: .init(
                appStoreIDs: Self.appStoreIDs,
                developerWebsite: URL(string: "https://agnidia.com")
            )
        ) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier(AccessibilityID.Settings.about)
    }
}

#Preview("About") {
    SettingsAboutView()
}
