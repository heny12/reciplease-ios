//
//  RecipeIngredient.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct RecipeIngredient: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var quantity: String
    var specificName: String?
    var amount: Double?
    var unit: String?
    var category: String?
    /// Original id string from the server when it is not itself a UUID.
    var serverKey: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        specificName: String? = nil,
        amount: Double? = nil,
        unit: String? = nil,
        category: String? = nil,
        serverKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.specificName = specificName
        self.amount = amount
        self.unit = unit
        self.category = category
        self.serverKey = serverKey
    }

    enum CodingKeys: String, CodingKey {
        case id, name, generalName, specificName, quantity, amount, unit, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = FlexibleDecoding.decodeString(container, forKey: .id) {
            serverKey = raw
            id = StableIdentifier.uuid(from: raw)
        } else {
            serverKey = nil
            id = UUID()
        }
        let general = FlexibleDecoding.decodeString(container, forKey: .generalName)
        let plain = FlexibleDecoding.decodeString(container, forKey: .name)
        name = (plain?.isEmpty == false ? plain : nil) ?? general ?? ""
        specificName = FlexibleDecoding.decodeString(container, forKey: .specificName)
        amount = FlexibleDecoding.decodeDouble(container, forKey: .amount)
        unit = FlexibleDecoding.decodeString(container, forKey: .unit)
        category = FlexibleDecoding.decodeString(container, forKey: .category)
        if let quantityString = FlexibleDecoding.decodeString(container, forKey: .quantity),
           !quantityString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quantity = quantityString
        } else if let amount {
            quantity = RecipeQuantityScaling.formatQuantityValue(amount) + (unit.map { " \($0)" } ?? "")
        } else {
            quantity = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverKey ?? id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(name, forKey: .generalName)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(specificName, forKey: .specificName)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(category, forKey: .category)
    }
}
