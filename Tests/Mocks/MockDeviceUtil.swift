//
//  MockDeviceUtil.swift
//
//  Created on 30.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
@testable import Lock_Watcher

/// MockDeviceUtil is a subclass of DeviceUtil used to override the behavior of `sysctlbyname`
final class MockDeviceUtil: DeviceUtil {
    let mockDevice: String?
    
    init(mockDevice: String?) {
        self.mockDevice = mockDevice
    }
    
    override func device() -> Devices {
        mockDevice?.contains("MacBook") == true ? .laptop : .nonLaptop
    }
}
