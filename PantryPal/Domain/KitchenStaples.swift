//
//  KitchenStaples.swift
//  Reciplease
//
//  User-confirmed staples, with diet conflicts removed before they are sent.
//

import Foundation

enum KitchenStaples {
    static let defaults: [String] = [
        "Salt", "Black Pepper", "Olive Oil", "Vegetable Oil", "Butter",
        "Onion Powder", "Garlic Powder", "Paprika", "Cumin", "Thyme",
        "Oregano", "Rosemary", "Bay Leaves", "Flour", "Sugar", "Water", "Honey"
    ]

    static let storageKey = "Reciplease.ConfirmedStaples"

    /// Butter and honey conflict with vegan. Butter also conflicts with dairy-free.
    /// Wheat flour conflicts with gluten-free.
    static func filtered(_ staples: [String], dietaryExclusions: [String]) -> [String] {
        let exclusions = Set(dietaryExclusions.map(normalize))
        let vegan = exclusions.contains("vegan")
        let dairyFree = vegan || exclusions.contains("dairy-free") || exclusions.contains("dairyfree")
        let glutenFree = exclusions.contains("gluten-free") || exclusions.contains("glutenfree")

        return staples.filter { staple in
            let name = normalize(staple)
            if vegan && (name.contains("butter") || name.contains("honey")) {
                return false
            }
            if dairyFree && name.contains("butter") {
                return false
            }
            if glutenFree && name.contains("flour") {
                return false
            }
            return true
        }
    }

    static func loadSaved() -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return saved.isEmpty ? defaults : saved
    }

    static func save(_ staples: [String]) {
        UserDefaults.standard.set(staples, forKey: storageKey)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}

enum DietaryConstraint {
    /// Hard exclusions remembered from onboarding. Mood chips are not mixed in here.
    static func wireExclusions(from storedIds: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in storedIds {
            let wire = id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            guard !wire.isEmpty, seen.insert(wire).inserted else { continue }
            result.append(wire)
        }
        return result
    }
}
