//
//  PreviewPersons.swift
//
//  Created on 13.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation

/// The persons of `Preview Assets.xcassets`, shared by both apps. Fixture photo names are `person-N.jpeg`, so an alert's `fileName` selects its person.
enum PreviewPersons {
    static let count = 11
    
    static func fileName(_ index: Int) -> String {
        index < count ? "person-\(index).jpeg" : "person-\(index % count)-\(index).jpeg"
    }
    
    static func assetName(_ index: Int) -> String {
        "Persons/person-\(index % count)"
    }
    
    static func assetName(forFileName fileName: String) -> String? {
        guard fileName.hasPrefix("person-"), let index = Int(fileName.dropFirst("person-".count).prefix { $0.isNumber }), index < count else { return nil }
        return assetName(index)
    }
}
#endif
