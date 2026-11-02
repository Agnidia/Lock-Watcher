//
//  DispatchQueue+Debounce.swift
//
//  Created on 08.01.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

extension DispatchQueue {
    /// Debounces a given action by waiting for a specified time interval before executing.
    /// If called multiple times within the interval, only the last call will trigger the action.
    ///
    /// - Parameters:
    ///   - interval: The duration to wait before executing the action. Can be in seconds, milliseconds, microseconds, or nanoseconds.
    ///   - action: The action/closure to execute after the debounce interval.
    ///
    /// - Returns: A function that can be invoked to trigger the debounce behaviour.
    func debounce(interval: DispatchTimeInterval, action: @escaping (() -> Void)) -> () -> Void {
        var lastTask: DispatchWorkItem? // Keep track of the last scheduled task
        
        return {
            // Cancel the previous task if it exists
            lastTask?.cancel()
            
            // Create a new task
            let task = DispatchWorkItem(block: action)
            
            // Schedule the new task
            self.asyncAfter(deadline: DispatchTime.now() + interval, execute: task)
            
            // Update the reference to the last task
            lastTask = task
        }
    }
}
