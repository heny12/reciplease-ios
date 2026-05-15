//
//  GroceryListItem.swift
//  PantryPal
//

import Foundation

struct GroceryListItem: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    var name: String
    var quantity: String
    var isChecked: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String = "",
        isChecked: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.createdAt = createdAt
    }
}
