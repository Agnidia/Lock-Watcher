//
//  NSApplication+Dock.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit

/// Protocol to abstract the behavior related to setting the activation policy of an application.
protocol ApplicationPolicyProtocol {
    /// Sets the application's activation policy.
    ///
    /// - Parameter policy: The activation policy to set.
    /// - Returns: The activation policy that was set.
    @MainActor
    @discardableResult
    func setActivation(policy: NSApplication.ActivationPolicy) -> NSApplication.ActivationPolicy
}

extension NSApplication: ApplicationPolicyProtocol {
    /// Implementation of `setActivation(policy:)` for `NSApplication`.
    ///
    /// - Parameter policy: The activation policy to set.
    /// - Returns: The activation policy that was set, or `.regular` if the policy could not be set.
    @MainActor
    @objc
    @discardableResult
    func setActivation(policy: ActivationPolicy) -> ActivationPolicy {
        NSApp.setActivationPolicy(policy) ? policy : .regular
    }
}

extension NSApplication {
    /// Toggles the visibility of the application's icon on the Dock.
    ///
    /// If the `hidden` parameter is `true`, the application's Dock icon is hidden, and the application behaves like an accessory application.
    /// If `false`, the application's Dock icon is shown, and the application behaves like a regular application.
    ///
    /// - Parameters:
    ///   - hidden: A Boolean value that determines whether to hide or show the Dock icon.
    ///   - app: An instance conforming to `NSApplication` and `ApplicationPolicyProtocol`. Defaults to the shared `NSApplication` instance.
    static func setDockIcon(hidden: Bool, app: NSApplication & ApplicationPolicyProtocol = NSApplication.shared) {
        let policy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        app.setActivation(policy: policy)
        app.activate(ignoringOtherApps: true)
        app.windows.first?.orderFrontRegardless()
    }
}
