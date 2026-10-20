//
//  DesignSystem.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

// MARK: - Design Tokens

/// Centralized design system for Lock-Watcher application.
/// Use these constants instead of hardcoded values for consistent styling.
enum DesignSystem {
    // MARK: - Spacing

    /// Spacing scale for consistent layout throughout the app.
    enum Spacing {
        /// Extra small spacing: 4pt
        static let xs: CGFloat = 4

        /// Small spacing: 8pt (standard inter-element spacing)
        static let sm: CGFloat = 8

        /// Medium spacing: 12pt
        static let md: CGFloat = 12

        /// Large spacing: 16pt (standard padding)
        static let lg: CGFloat = 16

        /// Extra large spacing: 24pt
        static let xl: CGFloat = 24

        /// Double extra large spacing: 32pt
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    /// Corner radius scale for rounded elements.
    enum CornerRadius {
        /// Extra small radius: 3pt (small badges, icons)
        static let xs: CGFloat = 3

        /// Small radius: 4pt (date badges, small elements)
        static let sm: CGFloat = 4

        /// Medium radius: 6pt (images, cards)
        static let md: CGFloat = 6

        /// Large radius: 8pt (containers, panels)
        static let lg: CGFloat = 8

        /// Extra large radius: 12pt (large cards, dialogs)
        static let xl: CGFloat = 12
    }

    // MARK: - Typography

    /// Typography scale for consistent text styling.
    enum Typography {
        /// Large title for main headings
        static let largeTitle: Font = .largeTitle

        /// Title for section headers
        static let title: Font = .title

        /// Title 2 for subsection headers
        static let title2: Font = .title2

        /// Title 3 for minor headers
        static let title3: Font = .title3

        /// Headline for emphasized content
        static let headline: Font = .headline

        /// Body for main content
        static let body: Font = .body

        /// Callout for secondary content
        static let callout: Font = .callout

        /// Subheadline for metadata
        static let subheadline: Font = .subheadline

        /// Footnote for minor details
        static let footnote: Font = .footnote

        /// Caption for labels and hints
        static let caption: Font = .caption

        /// Caption 2 for smallest text
        static let caption2: Font = .caption2
    }

    // MARK: - Animation

    /// Animation durations for consistent motion.
    enum Animation {
        /// Quick animation: 0.15s
        static let quick: Double = 0.15

        /// Standard animation: 0.25s
        static let standard: Double = 0.25

        /// Slow animation: 0.4s
        static let slow: Double = 0.4

        /// Spring animation with standard parameters
        static var spring: SwiftUI.Animation {
            .spring(response: 0.3, dampingFraction: 0.7)
        }
    }

    // MARK: - Shadows

    /// Shadow definitions for elevation.
    enum Shadow {
        /// Subtle shadow for slight elevation
        static let subtle = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

        /// Medium shadow for cards and panels
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

        /// Strong shadow for modals and overlays
        static let strong = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - Layout

    /// Layout constants for view sizing.
    enum Layout {
        /// Main view width
        static let mainViewWidth: CGFloat = 340

        /// Settings view width
        static let settingsViewWidth: CGFloat = 420

        /// First launch view size
        static let firstLaunchSize = CGSize(width: 320, height: 220)

        /// Main image height
        static let mainImageHeight: CGFloat = 240

        /// Gallery height
        static let galleryHeight: CGFloat = 148

        /// Standard border width
        static let borderWidth: CGFloat = 1
    }

    // MARK: - Colors

    /// Semantic color names for consistent theming.
    /// These reference colors defined in Assets.xcassets.
    enum Colors {
        /// Primary accent color
        static let accent = Color.accentColor

        /// Default menu item color
        static let defaultMenu = Color("defaultMenu")

        /// Extended/active menu item color
        static let extendedMenu = Color("extendedMenu")

        /// Divider color
        static let divider = Color("divider")

        /// Success state color
        static let success = Color("success")

        /// Error state color
        static let error = Color("error")

        /// Secondary text color
        static let secondaryText = Color.secondary

        /// Background color for alerts/dialogs
        static let alertBackground = Color(white: 0.9)
    }
}

// MARK: - Shadow Style

/// A structure representing shadow properties.
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extension for Shadows

extension View {
    /// Applies a shadow style to the view.
    func shadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers for UI testing and VoiceOver.
enum AccessibilityID {
    // MARK: - Main View

    enum Main {
        static let container = "main.container"
        static let lastSnapshot = "main.lastSnapshot"
        static let snapshotImage = "main.snapshotImage"
        static let snapshotDate = "main.snapshotDate"
        static let imageGallery = "main.imageGallery"
        static let emptyState = "main.emptyState"
        static let removeImageButton = "main.removeImageButton"
    }

    // MARK: - Info View

    enum Info {
        static let container = "info.container"
        static let debugTriggerButton = "info.debugTriggerButton"
        static let cleanButton = "info.cleanButton"
        static let openSettingsButton = "info.openSettingsButton"
        static let quitButton = "info.quitButton"
        static let websiteLink = "info.websiteLink"
        static let expandToggle = "info.expandToggle"
    }

    // MARK: - Settings View

    enum Settings {
        static let container = "settings.container"

        // Security section
        static let securitySection = "settings.securitySection"
        static let launchAtLoginToggle = "settings.launchAtLoginToggle"
        static let protectionToggle = "settings.protectionToggle"
        static let passwordField = "settings.passwordField"
        static let setPasswordButton = "settings.setPasswordButton"
        static let biometryToggle = "settings.biometryToggle"

        // Snapshot triggers section
        static let snapshotSection = "settings.snapshotSection"
        static let wakeUpToggle = "settings.wakeUpToggle"
        static let loginToggle = "settings.loginToggle"
        static let wrongPasswordToggle = "settings.wrongPasswordToggle"
        static let batteryToggle = "settings.batteryToggle"
        static let usbToggle = "settings.usbToggle"
        static let displayAttachToggle = "settings.displayAttachToggle"
        static let locationChangeToggle = "settings.locationChangeToggle"
        static let lockedInputToggle = "settings.lockedInputToggle"
        static let lockedInputDelayStepper = "settings.lockedInputDelayStepper"

        // Options section
        static let optionsSection = "settings.optionsSection"
        static let keepLastStepper = "settings.keepLastStepper"
        static let locationToggle = "settings.locationToggle"
        static let ipAddressToggle = "settings.ipAddressToggle"
        static let traceRouteToggle = "settings.traceRouteToggle"
        static let traceRouteServerField = "settings.traceRouteServerField"
        static let saveToDiskToggle = "settings.saveToDiskToggle"
        static let snapshotQualityPicker = "settings.snapshotQualityPicker"
        static let outputTypePicker = "settings.outputTypePicker"
        static let videoDurationStepper = "settings.videoDurationStepper"
        static let outputSizePicker = "settings.outputSizePicker"
        static let keepFilesPicker = "settings.keepFilesPicker"
        static let keepFilesFootnote = "settings.keepFilesFootnote"

        // Sync section
        static let syncSection = "settings.syncSection"
        static let emailToggle = "settings.emailToggle"
        static let emailField = "settings.emailField"
        static let iCloudToggle = "settings.iCloudToggle"
        static let dropboxToggle = "settings.dropboxToggle"
        static let dropboxAuthButton = "settings.dropboxAuthButton"
        static let dropboxLogoutButton = "settings.dropboxLogoutButton"
        static let notificationToggle = "settings.notificationToggle"
    }

    // MARK: - First Launch View

    enum FirstLaunch {
        static let container = "firstLaunch.container"
        static let optionsContainer = "firstLaunch.optionsContainer"
        static let takeSnapshotButton = "firstLaunch.takeSnapshotButton"
        static let progressIndicator = "firstLaunch.progressIndicator"
        static let successView = "firstLaunch.successView"
        static let successCountdown = "firstLaunch.successCountdown"
        static let faultView = "firstLaunch.faultView"
        static let openSettingsButton = "firstLaunch.openSettingsButton"
    }

    // MARK: - Security Alert

    enum SecurityAlert {
        static let container = "securityAlert.container"
        static let passwordPrompt = "securityAlert.passwordPrompt"
        static let passwordField = "securityAlert.passwordField"
        static let okButton = "securityAlert.okButton"
        static let cancelButton = "securityAlert.cancelButton"
    }

    // MARK: - Extended Divider

    enum ExtendedDivider {
        static let container = "extendedDivider.container"
        static let toggleButton = "extendedDivider.toggleButton"
    }
}

// MARK: - Accessibility Labels

/// Centralized accessibility labels for VoiceOver support.
enum AccessibilityLabel {
    // MARK: - Main View

    enum Main {
        static let lastSnapshot = NSLocalizedString("AccessibilityLastSnapshot", comment: "Last captured snapshot image")
        static let snapshotGallery = NSLocalizedString("AccessibilitySnapshotGallery", comment: "Gallery of recent snapshots")
        static let removeSnapshot = NSLocalizedString("AccessibilityRemoveSnapshot", comment: "Remove this snapshot")
        static let emptyState = NSLocalizedString("AccessibilityNoSnapshots", comment: "No snapshots to display")
        static func snapshotDate(_ date: String) -> String {
            String(format: NSLocalizedString("AccessibilitySnapshotDate %@", comment: "Snapshot captured on date"), date)
        }

        static func galleryImage(_ index: Int, total: Int) -> String {
            String(format: NSLocalizedString("AccessibilityGalleryImage %d %d", comment: "Image number in gallery"), index, total)
        }
    }

    // MARK: - Info View

    enum Info {
        static let openSettings = NSLocalizedString("AccessibilityOpenSettings", comment: "Open application settings")
        static let quitApp = NSLocalizedString("AccessibilityQuitApp", comment: "Quit Lock-Watcher")
        static let visitWebsite = NSLocalizedString("AccessibilityVisitWebsite", comment: "Visit Agnidia website")
        static let expandSection = NSLocalizedString("AccessibilityExpandInfo", comment: "Expand information section")
        static let collapseSection = NSLocalizedString("AccessibilityCollapseInfo", comment: "Collapse information section")
    }

    // MARK: - Settings

    enum Settings {
        static let launchAtLogin = NSLocalizedString("AccessibilityLaunchAtLogin", comment: "Launch Lock-Watcher when you log in")
        static let protectAccess = NSLocalizedString("AccessibilityProtectAccess", comment: "Require password to access Lock-Watcher")
        static let biometryAllowed = NSLocalizedString("AccessibilityBiometryAllowed", comment: "Allow Touch ID or Apple Watch to unlock")
        static let setPassword = NSLocalizedString("AccessibilitySetPassword", comment: "Set protection password")

        static let snapshotOnWakeUp = NSLocalizedString("AccessibilitySnapshotWakeUp", comment: "Take snapshot when Mac wakes up")
        static let snapshotOnLogin = NSLocalizedString("AccessibilitySnapshotLogin", comment: "Take snapshot on login attempt")
        static let snapshotOnWrongPassword = NSLocalizedString("AccessibilitySnapshotWrongPassword", comment: "Take snapshot on wrong password")
        static let snapshotOnBattery = NSLocalizedString("AccessibilitySnapshotBattery", comment: "Take snapshot when switching to battery")
        static let snapshotOnUSB = NSLocalizedString("AccessibilitySnapshotUSB", comment: "Take snapshot when USB device is connected")
        static let snapshotOnDisplayAttach = NSLocalizedString("AccessibilitySnapshotDisplayAttach", comment: "Take snapshot when a display is attached while locked")
        static let snapshotOnLocationChange = NSLocalizedString("AccessibilitySnapshotLocationChange", comment: "Take snapshot when the Mac moves while locked")
        static func snapshotOnLockedInput(_ delay: Int) -> String {
            PluralLocalization.string("AccessibilitySnapshotLockedInput %d", count: delay)
        }

        static let lockedInputDelay = NSLocalizedString("AccessibilityLockedInputDelay", comment: "Delay before the locked-input snapshot")

        static func keepLast(_ count: Int) -> String {
            PluralLocalization.string("AccessibilityKeepLast %d", count: count)
        }

        static let addLocation = NSLocalizedString("AccessibilityAddLocation", comment: "Add GPS location to snapshots")
        static let addIPAddress = NSLocalizedString("AccessibilityAddIP", comment: "Add IP address to snapshots")
        static let addTraceRoute = NSLocalizedString("AccessibilityAddTraceRoute", comment: "Add network trace route to snapshots")
        static let saveToDisk = NSLocalizedString("AccessibilitySaveToDisk", comment: "Save snapshots to disk")
        static let snapshotQuality = NSLocalizedString("AccessibilitySnapshotQuality", comment: "Snapshot JPEG quality")
        static let outputType = NSLocalizedString("AccessibilityOutputType", comment: "Capture a photo or a video")
        static func videoDuration(_ seconds: Int) -> String {
            PluralLocalization.string("AccessibilityVideoDuration %d", count: seconds)
        }

        static let outputSize = NSLocalizedString("AccessibilityOutputSize", comment: "Capture size for photos and videos")
        static let keepFiles = NSLocalizedString("AccessibilityKeepFiles", comment: "How long local capture files are kept")

        static let sendEmail = NSLocalizedString("AccessibilitySendEmail", comment: "Send snapshot notifications via email")
        static let syncICloud = NSLocalizedString("AccessibilitySyncICloud", comment: "Sync snapshots to iCloud")
        static let syncDropbox = NSLocalizedString("AccessibilitySyncDropbox", comment: "Sync snapshots to Dropbox")
        static let localNotification = NSLocalizedString("AccessibilityLocalNotification", comment: "Show local notifications for snapshots")
    }

    // MARK: - First Launch

    enum FirstLaunch {
        static let takeSnapshot = NSLocalizedString("AccessibilityTakeSnapshot", comment: "Take a test snapshot to verify camera access")
        static let progress = NSLocalizedString("AccessibilityProgress", comment: "Setting up Lock-Watcher")
        static let success = NSLocalizedString("AccessibilitySetupSuccess", comment: "Setup completed successfully")
        static let fault = NSLocalizedString("AccessibilitySetupFault", comment: "Setup failed, camera access required")
        static let openCameraSettings = NSLocalizedString("AccessibilityOpenCameraSettings", comment: "Open camera privacy settings")
        static func countdown(_ seconds: Int) -> String {
            PluralLocalization.string("AccessibilityCountdown %d", count: seconds)
        }
    }

    // MARK: - Security Alert

    enum SecurityAlert {
        static let enterPassword = NSLocalizedString("AccessibilityEnterPassword", comment: "Enter your protection password")
        static let passwordField = NSLocalizedString("AccessibilityPasswordInput", comment: "Password input field")
        static let confirm = NSLocalizedString("AccessibilityConfirm", comment: "Confirm password")
        static let cancel = NSLocalizedString("AccessibilityCancel", comment: "Cancel authentication")
    }

    // MARK: - Extended Divider

    enum ExtendedDivider {
        static func expand(_ section: String) -> String {
            String(format: NSLocalizedString("AccessibilityExpandSection %@", comment: "Expand section"), section)
        }

        static func collapse(_ section: String) -> String {
            String(format: NSLocalizedString("AccessibilityCollapseSection %@", comment: "Collapse section"), section)
        }
    }
}

// MARK: - Accessibility Hints

/// Centralized accessibility hints for additional context.
enum AccessibilityHint {
    enum Main {
        static let tapToOpen = NSLocalizedString("AccessibilityHintTapToOpen", comment: "Double-tap to open in Preview")
        static let tapToSelect = NSLocalizedString("AccessibilityHintTapToSelect", comment: "Double-tap to select this snapshot")
        static let tapToRemove = NSLocalizedString("AccessibilityHintTapToRemove", comment: "Double-tap to remove this snapshot")
    }

    enum Settings {
        static let toggleHint = NSLocalizedString("AccessibilityHintToggle", comment: "Double-tap to toggle this setting")
        static let passwordHint = NSLocalizedString("AccessibilityHintPassword", comment: "Enter a password to protect app access")
    }

    enum FirstLaunch {
        static let takeSnapshotHint = NSLocalizedString("AccessibilityHintTakeSnapshot", comment: "Double-tap to test camera and complete setup")
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/PluralLocalizationTests.swift
// @test-coverage: Spoken count labels use the plural-aware catalog path.
