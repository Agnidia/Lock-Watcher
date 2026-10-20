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
    
    /// Defines the frame of the window for the Settings domain.
    /// The window starts from the origin (0,0) and has a default width of 420.
    /// The height is allowed to grow as needed (indicated by CGFloat.infinity).
    var window: CGRect = .init(origin: .zero, size: .init(width: 420, height: CGFloat.infinity))
    
    /// Defines the padding around the contents of the Settings domain view.
    /// Top and bottom padding is 10, while leading (left) and trailing (right) padding is 16.
    var border: EdgeInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)
}
