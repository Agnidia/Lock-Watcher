//
//  PermissionsUtils.swift
//
//  Created on 26.05.2022.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import AppKit
import AVFoundation

/// Handles camera authorization requests.
public final class PermissionsUtils {
    /// Updates the camera permissions.
    ///
    /// This method checks the current authorization status for camera services and if it's undetermined, it sends a request for authorization.
    ///
    /// - Parameter handler: A closure that gets called with a boolean indicating whether access is granted.
    class func updateCameraPermissions(completionHandler handler: @escaping Commons.BoolClosure) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { isGranted in
                handler(isGranted)
            }
        case .restricted, .denied:
            // Restricted and Denied states indicate that camera access was denied or not allowed.
            handler(false)
        case .authorized:
            // Access is authorized.
            handler(true)
        @unknown default:
            // For future cases that might be added, currently grant access.
            handler(true)
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/FirstLaunchViewModelTests.swift
