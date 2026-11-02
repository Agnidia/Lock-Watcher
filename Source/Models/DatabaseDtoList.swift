//
//  DatabaseDtoList.swift
//
//  Created on 05.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Represents a list of `DatabaseDto` objects and provides functionalities for
/// managing and encoding/decoding this list for database storage purposes.
///
final class DatabaseDtoList: Codable, ObservableObject {
    /// Enumerates the keys used in the encoding and decoding processes.
    ///
    enum CodingKeys: String, CodingKey {
        case dtos
    }
    
    /// The list of `DatabaseDto` objects.
    @Published var dtos: [DatabaseDto]
    
    /// Initializes the `DatabaseDtoList` with an array of `DatabaseDto` objects.
    ///
    /// - Parameter dtos: The array of `DatabaseDto` objects.
    init(dtos: [DatabaseDto]) {
        self.dtos = dtos
    }
    
    /// Appends a `DatabaseDto` object to the list.
    ///
    /// - Parameter dto: The `DatabaseDto` object to be added.
    func append(_ dto: DatabaseDto) {
        dtos.append(dto)
    }
    
    /// Encodes the list of `DatabaseDto` objects into the provided encoder.
    ///
    /// - Parameter encoder: The encoder to encode data into.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(dtos, forKey: .dtos)
    }
    
    /// Initializes the `DatabaseDtoList` object by decoding from the provided decoder.
    ///
    /// - Parameter decoder: The decoder that contains the data.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        dtos = try container.decode([DatabaseDto].self, forKey: .dtos)
    }
}

extension DatabaseDtoList {
    /// Provides an empty `DatabaseDtoList` object.
    static var empty: DatabaseDtoList {
        DatabaseDtoList(dtos: [])
    }
}
