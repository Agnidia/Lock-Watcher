//
//  FixturePhotoSource.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
    import Foundation
    import UIKit

    /// Serves the preview persons from the asset catalog, so nothing touches iCloud and no binary ships in Release.
    struct FixturePhotoSource: CloudPhotoSource {
        enum Mode: Sendable {
            case photos
            case empty
            case unavailable
        }

        let mode: Mode
        var count = PreviewPersons.count

        static func photos(count: Int = PreviewPersons.count) -> [CloudPhoto] {
            (0 ..< count).map { index in
                CloudPhoto(url: URL(filePath: "/fixture/\(PreviewPersons.fileName(index))"), date: PreviewAlerts.referenceDate.addingTimeInterval(-TimeInterval(index) * 5400))
            }
        }

        func listPhotos() async throws -> [CloudPhoto] {
            switch mode {
            case .unavailable: throw CloudPhotoError.unavailable
            case .empty: []
            case .photos: Self.photos(count: count)
            }
        }

        func imageData(for photo: CloudPhoto) async throws -> Data {
            guard let asset = PreviewPersons.assetName(forFileName: photo.url.lastPathComponent),
                  let data = UIImage(named: asset)?.jpegData(compressionQuality: 0.85)
            else { throw CloudPhotoError.unreadable }
            return data
        }
    }
#endif

// MARK: - Test Info

// @test-file: CompanionTests/PreviewAlertsTests.swift
