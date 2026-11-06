//
//  PantryMatchCalculator.swift
//  Reciplease
//
//  Name-based pantry match. This does not prove you have enough of an ingredient.
//

import Foundation

struct PantryMatchResult: Equatable {
    var matched: Int
    var total: Int
    var score: Double
}

enum PantryMatchCalculator {
    static let defaultStaples: Set<String> = [
        "salt", "pepper", "black pepper", "oil", "olive oil", "vegetable oil",
        "canola oil", "cooking oil", "butter", "water", "sugar", "flour", "all-purpose flour",
        "baking powder", "baking soda", "vanilla", "vanilla extract", "garlic powder",
        "onion powder", "paprika", "cinnamon", "cumin", "oregano", "basil", "thyme",
        "rosemary", "bay leaf", "bay leaves", "vinegar", "soy sauce", "honey", "maple syrup",
        "mustard", "ketchup", "mayonnaise", "hot sauce", "worcestershire sauce",
        "chili powder", "brown sugar", "white vinegar"
    ]

    static let highMatchThreshold = 0.75

    static func breakdown(
        ingredientNames: [String],
        pantryNames: [String],
        staples: Set<String> = defaultStaples
    ) -> PantryMatchResult {
        let rows = ingredientNames.map(normalize).filter { !$0.isEmpty }
        let total = rows.count
        guard total > 0 else {
            return PantryMatchResult(matched: 0, total: 0, score: 0)
        }
        let matched = rows.reduce(into: 0) { count, name in
            if isInPantry(name, pantryNames: pantryNames) || isStaple(name, staples: staples) {
                count += 1
            }
        }
        let score = min(max(Double(matched) / Double(total), 0), 1)
        return PantryMatchResult(matched: matched, total: total, score: score)
    }

    static func isInPantry(_ ingredientName: String, pantryNames: [String]) -> Bool {
        let normalizedName = normalize(ingredientName)
        guard !normalizedName.isEmpty else { return false }
        let words = normalizedName.components(separatedBy: " ")
        for pantryItem in pantryNames {
            let pantryName = normalize(pantryItem)
            guard !pantryName.isEmpty else { continue }
            if normalizedName == pantryName { return true }
            if normalizedName.contains(pantryName) || pantryName.contains(normalizedName) { return true }
            let pantryWords = pantryName.components(separatedBy: " ")
            for pantryWord in pantryWords where pantryWord.count > 3 && normalizedName.contains(pantryWord) {
                return true
            }
            for word in words where word.count > 3 && pantryName.contains(word) {
                return true
            }
        }
        return false
    }

    static func isStaple(_ ingredientName: String, staples: Set<String> = defaultStaples) -> Bool {
        let normalizedName = normalize(ingredientName)
        guard !normalizedName.isEmpty else { return false }
        if staples.contains(normalizedName) { return true }
        for word in normalizedName.components(separatedBy: " ") where !word.isEmpty {
            if staples.contains(word) { return true }
        }
        return false
    }

    static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
