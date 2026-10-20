//
//  DatabaseDto.swift
//
//  Created on 28.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Represents a data object that is suitable for database storage.
/// This is created by transforming the `ThiefDto` into a storable format.
///
public final class DatabaseDto: Codable, Identifiable {
    /// Enumerates the keys used in the encoding and decoding processes.
    ///
    enum CodingKeys: String, CodingKey {
        case date
        case data
        case path
    }
    
    /// The date the object was created or the event was captured.
    var date: Date
    
    /// The raw data, likely representing an image or snapshot from `ThiefDto`.
    var data: Data
    
    /// The optional path where additional data or files might be stored.
    var path: URL?
    
    /// Encodes the object's properties into the encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(date, forKey: .date)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(path, forKey: .path)
    }
    
    /// Initializes the object by decoding from the provided decoder.
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        date = try container.decode(Date.self, forKey: .date)
        data = try container.decode(Data.self, forKey: .data)
        path = try container.decodeIfPresent(URL.self, forKey: .path)
    }
    
    /// Fails when the record has no still, because history rows need image data; `path` prefers the movie.
    init?(with thiefDto: ThiefDto) {
        guard let snapshot = thiefDto.snapshot else { return nil }
        date = thiefDto.date
        data = snapshot.jpegData(quality: thiefDto.compressionFactor)
        path = thiefDto.videoURL ?? thiefDto.filePath
    }
}

extension DatabaseDto: Equatable, Hashable {
    /// Checks the equality between two `DatabaseDto` objects.
    public static func == (lhs: DatabaseDto, rhs: DatabaseDto) -> Bool {
        lhs.date == rhs.date &&
        lhs.data == rhs.data &&
        lhs.path == rhs.path
    }
    
    /// Checks if one `DatabaseDto` is older than the other based on the date.
    public static func < (lhs: DatabaseDto, rhs: DatabaseDto) -> Bool {
        lhs.date < rhs.date
    }
    
    /// Generates a hash value for the object.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(data)
    }
}
