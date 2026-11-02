//
//  Date+Formatter.swift
//
//  Created on 03.09.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

extension Date {
    /// A custom date formatter tailored for the application's specific needs.
    /// This formatter provides both a short date and time representation.
    ///
    /// - Returns: A `DateFormatter` instance with the application's default date and time styles.
    static let defaultFormat: DateFormatter = {
        let formatter = DateFormatter()
        
        // Configures the formatter to represent dates in a short style.
        formatter.dateStyle = .short
        
        // Configures the formatter to represent times in a short style.
        formatter.timeStyle = .short
        
        formatter.locale = .init(identifier: "en")
        formatter.timeZone = .gmt
        
        return formatter
    }()
}
