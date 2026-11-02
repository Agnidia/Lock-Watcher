//
//  CLLocationCoordinate2D+Sendable.swift
//
//  Created on 26.12.2024.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreLocation

extension CLLocationCoordinate2D: @retroactive @unchecked Sendable {}
