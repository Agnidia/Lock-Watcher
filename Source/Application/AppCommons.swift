//
//  AppCommons.swift
//
//  Created on 23.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Contains commonly used closure types to promote consistency throughout the code.
enum Commons {
    /// Represents a closure that takes no parameters and returns no value.
    typealias EmptyClosure = () -> Void
    
    /// Represents a closure that takes a boolean parameter and returns no value.
    typealias BoolClosure = @Sendable (Bool) -> Void

    /// Represents a closure that takes a string parameter and returns no value.
    typealias StringClosure = @Sendable (String) -> Void

    /// Represents a closure that takes a thief dto parameter and returns no value.
    typealias ThiefClosure = @Sendable (ThiefDto) -> Void

    /// Represents a closure that takes a trigger parameter and returns no value.
    typealias TriggerClosure = @Sendable (TriggerType) -> Void
}

/// Describes the different states a SwiftUI View can be in.
enum StateMode: Int, CaseIterable {
    /// The view is in its default state.
    case idle
    
    /// The view is in a state where the user is not logged in or identified.
    case anonymous
    
    /// The view is in a state where the user is logged in or identified.
    case authorised
    
    /// The view is performing a task or loading data.
    case progress
    
    /// The view successfully completed a task or operation.
    case success
    
    /// There was an error or issue with a task or operation on the view.
    case fault
    
    /// A list of all possible states for the view.
    static var allCases: [StateMode] {
        [.idle, .anonymous, .authorised, .progress, .success, .fault]
    }
}
