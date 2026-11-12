//
//  SettingsDomain.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Represents the configuration and constants for the Settings domain.
struct SettingsDomain: DomainViewConstant {
    /// The name associated with the Settings domain.
    var name: String = "SettingsDomain"

    /// The fixed size of the settings window: a 200 pt sidebar beside a scrolling form.
    var window: CGRect = .init(origin: .zero, size: .init(width: DesignSystem.Layout.settingsViewWidth, height: DesignSystem.Layout.settingsViewHeight))

    /// The grouped form and the sidebar supply their own insets, so the window adds none.
    var border: EdgeInsets = .init()
}
