//
//  RecipeIngredient.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct RecipeIngredient: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let quantity: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case quantity
    }
}
