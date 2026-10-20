//
//  PluralLocalization.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import Foundation

enum PluralLocalization {
    static func string(_ key: String, count: Int, bundle: Bundle = .main, locale: Locale? = nil) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        // A standalone .lproj bundle has no localization metadata, so its directory names the language.
        let language = bundle.bundleURL.pathExtension == "lproj"
            ? bundle.bundleURL.deletingPathExtension().lastPathComponent
            : bundle.preferredLocalizations.first ?? Locale.current.identifier
        return String(format: format, locale: locale ?? Locale(identifier: language), count)
    }
}

// MARK: - Test Info

// @test-file: Tests/Utils/PluralLocalizationTests.swift
// @test-coverage: Compiled English and Ukrainian count variants for all nine numeric labels.
