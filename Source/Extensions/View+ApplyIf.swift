//
//  View+ApplyIf.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension View {
    /// A SwiftUI View extension to conditionally apply modifications to a view.
    ///
    /// This method takes a Boolean condition and two closures, and depending on the evaluation of the condition,
    /// it will apply one of the two closures to the current view and return the resulting view.
    ///
    /// - Parameters:
    ///   - condition: A Boolean value that determines which closure to apply. If `true`, the `apply` closure is used; if `false`, the `else` closure is used.
    ///   - apply: A closure that takes the current view and returns a modified view. This closure is applied if the `condition` is `true`.
    ///   - else: A closure that takes the current view and returns a modified view. This closure is applied if the `condition` is `false`.
    /// - Returns: A modified view depending on the evaluation of the condition.
    ///
    /// - Example:
    /// ```swift
    /// Text("Hello, World!")
    ///     .applyIf(isBold, apply: { $0.bold() }, else: { $0.italic() })
    /// ```
    /// In the example above, if `isBold` is true, the text will be bold; otherwise, it will be italic.
    ///
    @ViewBuilder
    func applyIf<T: View>(_ condition: @autoclosure () -> Bool, apply: (Self) -> T, else: (Self) -> T) -> some View {
        if condition() {
            apply(self)
        } else {
            `else`(self)
        }
    }
}
