//
//  XPCPowerProtocol.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

@objc
public protocol XPCPowerProtocol {
    @objc
    func startCheckPower(_ replyBlock: @escaping (NSInteger) -> Void)
    @objc
    func stopCheckPower()
}
