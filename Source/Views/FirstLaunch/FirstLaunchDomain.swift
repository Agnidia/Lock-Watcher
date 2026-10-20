//
//  FirstLaunchDomain.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Represents constants associated with the domain for the first launch experience in the app.
///
/// This struct conforms to the `DomainViewConstant` protocol (which presumably provides a structure for domain-specific UI constants).
/// The constants defined here pertain to the appearance and layout of the first launch screen.
struct FirstLaunchDomain: DomainViewConstant {
    /// A unique identifier for the domain.
    var name: String = "FirstLaunchDomain"
    
    /// Specifies the window's frame, i.e., its position and size.
    ///
    /// Here, the window starts at the origin (top-left) and has dimensions of 320x220.
    var window: CGRect = .init(origin: .zero, size: .init(width: 320, height: 220))
    
    /// Specifies the border (or padding) to be applied to the content inside the domain.
    ///
    /// This ensures there's adequate space between the content and the edges of the domain.
    /// For example, the top border is 10, which means there's a space of 10 units between the content's top edge and the domain's top edge.
    var border: EdgeInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)
}
