//
//  CompanionFixturePhotos.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
    import Foundation
    import UIKit

    /// Screenshot-run photos drawn at launch, so no binary assets ship and nothing touches iCloud.
    struct FixturePhotoSource: CloudPhotoSource {
        enum Mode: Sendable {
            case photos
            case empty
            case unavailable
        }

        let mode: Mode

        private static let palette: [(name: String, top: UIColor, bottom: UIColor)] = [
            ("front-door", .systemIndigo, .systemTeal),
            ("desk", .systemOrange, .systemPink),
            ("hallway", .systemGreen, .systemMint),
            ("garage", .systemPurple, .systemBlue)
        ]

        func listPhotos() async throws -> [CloudPhoto] {
            switch mode {
            case .unavailable:
                throw CloudPhotoError.unavailable
            case .empty:
                []
            case .photos:
                Self.palette.enumerated().map { index, entry in
                    CloudPhoto(url: URL(filePath: "/fixture/\(entry.name).jpeg"), date: Date(timeIntervalSince1970: 1_793_021_520 - TimeInterval(index) * 5400))
                }
            }
        }

        func imageData(for photo: CloudPhoto) async throws -> Data {
            guard let entry = Self.palette.first(where: { photo.id.hasPrefix($0.name) }) else { throw CloudPhotoError.unreadable }
            let size = CGSize(width: 1200, height: 900)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                let colors = [entry.top.cgColor, entry.bottom.cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                }
                UIColor.white.withAlphaComponent(0.85).setFill()
                UIBezierPath(ovalIn: CGRect(x: 430, y: 220, width: 340, height: 340)).fill()
                UIBezierPath(roundedRect: CGRect(x: 330, y: 600, width: 540, height: 220), cornerRadius: 110).fill()
                let label = NSAttributedString(string: entry.name.uppercased(), attributes: [
                    .font: UIFont.systemFont(ofSize: 56, weight: .bold),
                    .foregroundColor: UIColor.white
                ])
                label.draw(at: CGPoint(x: (size.width - label.size().width) / 2, y: 60))
            }
            guard let data = image.jpegData(compressionQuality: 0.8) else { throw CloudPhotoError.unreadable }
            return data
        }
    }

    extension CompanionFixture {
        var photoMode: FixturePhotoSource.Mode {
            switch self {
            case .photos, .proDetail: .photos
            case .photosUnavailable: .unavailable
            case .ready, .denied, .alerts, .alertsMany, .pro, .proOffers, .proDetailBare: .empty
            }
        }
    }
#endif

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
