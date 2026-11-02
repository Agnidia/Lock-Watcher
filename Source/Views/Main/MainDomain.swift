//
//  MainDomain.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Represents the main domain's configuration settings for the view.
struct MainDomain: DomainViewConstant {
    /// The name identifier for this domain.
    var name: String = "MainDomain"
    
    /// Defines the initial position and size of the window in this domain.
    var window: CGRect = .init(origin: .zero, size: .init(width: 340, height: CGFloat.infinity))
    
    /// Specifies the border or padding around the content within this domain.
    var border: EdgeInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)
}
