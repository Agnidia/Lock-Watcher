//
//  ViewProtocols.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A protocol that describes the constants associated with a specific domain view.
///
/// This protocol is intended for use in UI elements that need domain-specific layout and appearance constants.
protocol DomainViewConstant {
    /// A unique identifier for the domain view.
    var name: String { get }
    
    /// Specifies the frame of the domain view, defining its position and size.
    var window: CGRect { get set }
    
    /// Defines the edge insets (or padding) to be applied to the content inside the domain view.
    var border: EdgeInsets { get set }
}

/// A protocol that bridges a concrete view to its associated `DomainViewConstant`.
///
/// Conforming types will provide domain-specific constants via the `viewSettings` property.
@MainActor
protocol DomainViewConstantProtocol {
    /// The associated `DomainViewConstant` type that provides layout and appearance constants.
    associatedtype DomainViewConstant
    
    /// The instance of the `DomainViewConstant` for this view.
    var viewSettings: DomainViewConstant { get }
}

/// A container for general view constants used across different views.
enum ViewConstants {
    /// A standard spacing value for views.
    static let spacing: CGFloat = 8
    
    /// A standard padding value for views.
    static let padding: CGFloat = 8
    
    /// A padding value that is double the standard padding.
    static let doublePadding: CGFloat = padding * 2
}
