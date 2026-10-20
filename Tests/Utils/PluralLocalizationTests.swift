//
//  PluralLocalizationTests.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI
import XCTest
@testable import Lock_Watcher

// @depends-on: PluralLocalization
// @test-tag: regression
@MainActor
final class PluralLocalizationTests: XCTestCase {
    private struct Expected {
        let key: String
        let one: String
        let two: String
        let five: String?
    }

    private func languageBundle(_ language: String) throws -> Bundle {
        let appBundle = Bundle(for: AppDelegate.self)
        let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func assertVariants(_ cases: [Expected], bundle: Bundle, locale: Locale, file: StaticString = #filePath, line: UInt = #line) {
        for item in cases {
            XCTAssertEqual(PluralLocalization.string(item.key, count: 1, bundle: bundle, locale: locale), item.one, item.key, file: file, line: line)
            XCTAssertEqual(PluralLocalization.string(item.key, count: 2, bundle: bundle, locale: locale), item.two, item.key, file: file, line: line)
            if let five = item.five {
                XCTAssertEqual(PluralLocalization.string(item.key, count: 5, bundle: bundle, locale: locale), five, item.key, file: file, line: line)
            }
        }
    }

    func testEnglishVisibleAndVoiceOverCounts() throws {
        let bundle = try languageBundle("en")
        assertVariants([
            Expected(key: "AccessibilityCountdown %d", one: "Closing in 1 second", two: "Closing in 2 seconds", five: nil),
            Expected(key: "AccessibilityKeepLast %d", one: "Keep last 1 snapshot", two: "Keep last 2 snapshots", five: nil),
            Expected(key: "AccessibilityVideoDuration %d", one: "Video length 1 second", two: "Video length 2 seconds", five: nil),
            Expected(key: "AccessibilitySnapshotLockedInput %d", one: "Take snapshot on keyboard or mouse input while locked, after 1 second", two: "Take snapshot on keyboard or mouse input while locked, after 2 seconds", five: nil),
            Expected(key: "AccessibilityLockedInputDelayValue %d", one: "1 second", two: "2 seconds", five: nil),
            Expected(key: "KeepLastN %d", one: "Keep last 1 snapshot", two: "Keep last 2 snapshots", five: nil),
            Expected(key: "VideoDuration %d", one: "Video length: 1 second", two: "Video length: 2 seconds", five: nil),
            Expected(key: "SnapshotOnLockedInput %d", one: "Take snapshot on input while locked, after 1 second", two: "Take snapshot on input while locked, after 2 seconds", five: nil),
            Expected(key: "SuccessTimer %d", one: "Window will close in 1 second", two: "Window will close in 2 seconds", five: nil),
        ], bundle: bundle, locale: Locale(identifier: "en"))
    }

    func testEnglishDelayValueUsesBundleLanguageByDefault() throws {
        let bundle = try languageBundle("en")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 1, bundle: bundle), "1 second")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 2, bundle: bundle), "2 seconds")
    }

    func testUkrainianDelayValueUsesBundleLanguageByDefault() throws {
        let bundle = try languageBundle("uk")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 1, bundle: bundle), "1 секунда")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 2, bundle: bundle), "2 секунди")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 5, bundle: bundle), "5 секунд")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 11, bundle: bundle), "11 секунд")
        XCTAssertEqual(PluralLocalization.string("AccessibilityLockedInputDelayValue %d", count: 21, bundle: bundle), "21 секунда")
    }

    func testUkrainianVisibleAndVoiceOverCounts() throws {
        let bundle = try languageBundle("uk")
        assertVariants([
            Expected(key: "AccessibilityCountdown %d", one: "Закриється через 1 секунду", two: "Закриється через 2 секунди", five: "Закриється через 5 секунд"),
            Expected(key: "AccessibilityKeepLast %d", one: "Зберігати 1 останній знімок", two: "Зберігати 2 останні знімки", five: "Зберігати 5 останніх знімків"),
            Expected(key: "AccessibilityVideoDuration %d", one: "Тривалість відео 1 секунда", two: "Тривалість відео 2 секунди", five: "Тривалість відео 5 секунд"),
            Expected(key: "AccessibilitySnapshotLockedInput %d", one: "Зробити знімок при введенні з клавіатури або миші під час блокування, через 1 секунду", two: "Зробити знімок при введенні з клавіатури або миші під час блокування, через 2 секунди", five: "Зробити знімок при введенні з клавіатури або миші під час блокування, через 5 секунд"),
            Expected(key: "AccessibilityLockedInputDelayValue %d", one: "1 секунда", two: "2 секунди", five: "5 секунд"),
            Expected(key: "KeepLastN %d", one: "Залишити 1 останній знімок", two: "Залишити 2 останні знімки", five: "Залишити 5 останніх знімків"),
            Expected(key: "VideoDuration %d", one: "Тривалість відео: 1 секунда", two: "Тривалість відео: 2 секунди", five: "Тривалість відео: 5 секунд"),
            Expected(key: "SnapshotOnLockedInput %d", one: "Зробити знімок при введенні, через 1 секунду", two: "Зробити знімок при введенні, через 2 секунди", five: "Зробити знімок при введенні, через 5 секунд"),
            Expected(key: "SuccessTimer %d", one: "Вікно закриється через 1 секунду", two: "Вікно закриється через 2 секунди", five: "Вікно закриється через 5 секунд"),
        ], bundle: bundle, locale: Locale(identifier: "uk"))
    }

    func testChangingCountKeepsLocalizedLabelWidth() throws {
        let cases: [(key: String, range: ClosedRange<Int>, values: [Int])] = [
            ("KeepLastN %d", 1 ... 30, [9, 10]),
            ("VideoDuration %d", SnapshotSettings.videoDurationRange, [1, 2]),
            ("SnapshotOnLockedInput %d", TriggerSettings.lockedInputDelayRange, [9, 10]),
        ]

        for language in ["en", "uk"] {
            let bundle = try languageBundle(language)
            for item in cases {
                let widths = item.values.map { count in
                    let host = NSHostingView(rootView: StableCountLabel(key: item.key, count: count, range: item.range, bundle: bundle))
                    return host.fittingSize.width
                }
                XCTAssertEqual(widths[0], widths[1], accuracy: 1, "\(language): \(item.key)")
            }
        }
    }

    func testEnglishRetainedCountAtNineAndTen() throws {
        let bundle = try languageBundle("en")
        XCTAssertEqual(PluralLocalization.string("KeepLastN %d", count: 9, bundle: bundle), "Keep last 9 snapshots")
        XCTAssertEqual(PluralLocalization.string("KeepLastN %d", count: 10, bundle: bundle), "Keep last 10 snapshots")
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/PluralLocalization.swift
// @doc-refs: .context/planning-0.md#acceptance-criteria
