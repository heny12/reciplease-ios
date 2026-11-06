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
    var pinned: Bool
    var expirationDate: Date?
    var amount: Double?
    var unit: String?

    init(
        id: UUID = UUID(),
        generalName: String,
        specificName: String? = nil,
        quantity: String? = nil,
        pinned: Bool = false,
        expirationDate: Date? = nil,
        amount: Double? = nil,
        unit: String? = nil
    ) {
        self.id = id
        self.generalName = generalName
        self.specificName = specificName
        self.quantity = quantity
        self.pinned = pinned
        self.expirationDate = expirationDate
        self.amount = amount
        self.unit = unit
    }

    var useSoon: Bool {
        guard let expirationDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expirationDate)).day ?? 0
        return days <= 3
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case generalName
        case specificName
        case quantity
        case pinned
        case expirationDate
        case amount
        case unit
    }
    
    // Custom decoder: Generate id if not present (API responses), use existing id if present (saved data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let raw = FlexibleDecoding.decodeString(container, forKey: .id) {
            id = StableIdentifier.uuid(from: raw)
        } else {
            id = UUID()
        }
        
        generalName = try container.decode(String.self, forKey: .generalName)
        specificName = try container.decodeIfPresent(String.self, forKey: .specificName)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        pinned = FlexibleDecoding.decodeBool(container, forKey: .pinned) ?? false
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        amount = FlexibleDecoding.decodeDouble(container, forKey: .amount)
        unit = FlexibleDecoding.decodeString(container, forKey: .unit)
    }
    
    // Custom encoder: Always include id when encoding (for local persistence)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(generalName, forKey: .generalName)
        try container.encodeIfPresent(specificName, forKey: .specificName)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encode(pinned, forKey: .pinned)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(unit, forKey: .unit)
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
