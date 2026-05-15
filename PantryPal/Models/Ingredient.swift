//
//  Ingredient.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct Ingredient: Codable, Identifiable, Hashable {
    let id: UUID
    var generalName: String
    var specificName: String?
    var quantity: String?
    
    init(id: UUID = UUID(), generalName: String, specificName: String? = nil, quantity: String? = nil) {
        self.id = id
        self.generalName = generalName
        self.specificName = specificName
        self.quantity = quantity
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case generalName
        case specificName
        case quantity
    }
    
    // Custom decoder: Generate id if not present (API responses), use existing id if present (saved data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but generate a new one if it's not present (API responses)
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID() // Generate new ID for API responses that don't include it
        }
        
        generalName = try container.decode(String.self, forKey: .generalName)
        specificName = try container.decodeIfPresent(String.self, forKey: .specificName)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
    }
    
    // Custom encoder: Always include id when encoding (for local persistence)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(generalName, forKey: .generalName)
        try container.encodeIfPresent(specificName, forKey: .specificName)
        try container.encodeIfPresent(quantity, forKey: .quantity)
    }
    
    /// Capitalizes the ingredient name if not already capitalized
    mutating func capitalizeName() {
        generalName = generalName.capitalized
        if let specific = specificName {
            specificName = specific.capitalized
        }
    }
}

struct IngredientResponse: Codable {
    let ingredients: [Ingredient]
}
