//
//  PreviewAlertsTests.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest

#if DEBUG
    final class PreviewAlertsTests: XCTestCase {
        func testEveryTriggerHasOnePreviewAlert() {
            let triggers = PreviewAlerts.all().compactMap { AlertTrigger(alert: $0) }
            XCTAssertEqual(Set(triggers), Set(AlertTrigger.allCases))
            XCTAssertEqual(triggers.count, AlertTrigger.allCases.count)
        }

        func testPreviewAlertIdentifiersAreUnique() {
            let ids = PreviewAlerts.all().map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count)
        }

        func testCaptureFileNamesResolveToPersonAssets() {
            for alert in PreviewAlerts.all() {
                guard let fileName = alert.fileName else { continue }
                XCTAssertNotNil(PreviewPersons.assetName(forFileName: fileName), fileName)
            }
        }
    }
#endif
