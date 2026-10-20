//
//  DeviceUtil.swift
//
//  Created on 23.05.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Darwin.sys.sysctl
import Foundation

/// Enumeration of supported device types.
enum Devices {
    /// Represents macOS laptop devices (like MacBook, MacBook Pro, and MacBook Air).
    case laptop
    /// Represents non-laptop macOS devices (like iMac, Mac Mini, etc.).
    case nonLaptop
}

protocol DeviceUtilProtocol {
    /// Fetches the device type based on the hardware model.
    func device() -> Devices
}

/// `DeviceUtil` is a utility class that helps identify the type of macOS device.
public class DeviceUtil: DeviceUtilProtocol {
    /// Fetches the device type based on the hardware model.
    ///
    /// - Returns: A `Devices` enumeration value representing the type of the device.
    func device() -> Devices {
        var size: size_t = 0
        let name = "hw.model"
        
        // Querying for the size of the data type for the given name.
        var res = sysctlbyname(name, nil, &size, nil, 0)
        
        // If there's an error in fetching the size, return nonLaptop as a default.
        if res != 0 {
            return .nonLaptop
        }
        
        // Preparing the array to store the device name.
        var ret = [CChar](repeating: 0, count: size + 1)
        
        // Querying for the device name.
        res = sysctlbyname(name, &ret, &size, nil, 0)
        
        // If successfully retrieved the name, check if it contains "MacBook", indicating it's a laptop.
        let device: String? = if res == 0 {
            ret.withUnsafeBufferPointer { buffer in
                buffer.baseAddress.map { String(cString: $0) }
            }
        } else {
            nil
        }
        
        return if device?.contains("MacBook") == true ||
        device?.contains("Mac14,5") == true || device?.contains("Mac14,6") == true || device?.contains("Mac14,7") == true ||
        device?.contains("Mac14,9") == true || device?.contains("Mac14,10") == true || device?.contains("Mac14,15") == true ||
        device?.contains("Mac15,3") == true || device?.contains("Mac15,6") == true || device?.contains("Mac15,8") == true ||
        device?.contains("Mac15,9") == true || device?.contains("Mac15,10") == true || device?.contains("Mac15,11") == true ||
        device?.contains("Mac15,12") == true || device?.contains("Mac15,13") == true ||
        device?.contains("Mac16,1") == true || device?.contains("Mac16,5") == true || device?.contains("Mac16,6") == true ||
        device?.contains("Mac16,7") == true || device?.contains("Mac16,8") == true || device?.contains("Mac15,12") == true ||
        device?.contains("Mac16,13") == true {
            .laptop
        } else {
            .nonLaptop
        }
    }
}
