//
//  LaunchAtLoginView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import LaunchAtLogin
import SwiftUI

/// A view component that provides a toggle for the user to enable or disable launching the app at system login.
struct LaunchAtLoginView: View {
    /// The body of the view, containing a toggle that is controlled by the `LaunchAtLogin` library.
    var body: some View {
        LaunchAtLogin.Toggle {
            Text("LaunchAtLogin")
        }
    }
}

#Preview("Launch At Login") {
    LaunchAtLoginView()
}
