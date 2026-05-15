//
//  RecipeGenerationFormOptionData.swift
//  PantryPal
//
//  Shared cuisine / dietary chips and canned prompts for generate-recipe and generate-meal-plan sheets.
//

import Foundation

private enum RecipeGenerationFormPreferenceStorage {
    static let cuisineOrderKey = "Reciplease.SavedFormCuisinePreferenceOrder"
    static let dietaryOrderKey = "Reciplease.SavedFormDietaryPreferenceOrder"
}

struct OptionItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
}

enum RecipeGenerationFormOptionData {
    static let cuisines: [OptionItem] = [
        OptionItem(id: "Any", name: "Any", icon: "globe"),
        OptionItem(id: "Italian", name: "Italian", icon: "🍝"),
        OptionItem(id: "Mexican", name: "Mexican", icon: "🌮"),
        OptionItem(id: "Chinese", name: "Chinese", icon: "🥢"),
        OptionItem(id: "Japanese", name: "Japanese", icon: "🍱"),
        OptionItem(id: "Indian", name: "Indian", icon: "🍛"),
        OptionItem(id: "Thai", name: "Thai", icon: "🍜"),
        OptionItem(id: "French", name: "French", icon: "🥐"),
        OptionItem(id: "Mediterranean", name: "Mediterranean", icon: "🫒"),
        OptionItem(id: "American", name: "American", icon: "🍔"),
        OptionItem(id: "Greek", name: "Greek", icon: "🧀"),
        OptionItem(id: "Korean", name: "Korean", icon: "🥘"),
        OptionItem(id: "Vietnamese", name: "Vietnamese", icon: "🍲"),
        OptionItem(id: "Middle Eastern", name: "Middle Eastern", icon: "🥙"),
        OptionItem(id: "Spanish", name: "Spanish", icon: "🥘"),
        OptionItem(id: "Turkish", name: "Turkish", icon: "🥙"),
        OptionItem(id: "Brazilian", name: "Brazilian", icon: "🍖"),
        OptionItem(id: "Caribbean", name: "Caribbean", icon: "🍍"),
        OptionItem(id: "Ethiopian", name: "Ethiopian", icon: "🍛"),
        OptionItem(id: "Moroccan", name: "Moroccan", icon: "🍲"),
        OptionItem(id: "German", name: "German", icon: "🥨"),
        OptionItem(id: "Portuguese", name: "Portuguese", icon: "🐟"),
        OptionItem(id: "Filipino", name: "Filipino", icon: "🍢")
    ]

    static let dietaryOptions: [OptionItem] = [
        OptionItem(id: "Vegetarian", name: "Vegetarian", icon: "leaf.fill"),
        OptionItem(id: "Vegan", name: "Vegan", icon: "leaf.circle.fill"),
        OptionItem(id: "Gluten Free", name: "Gluten Free", icon: "circle.dotted"),
        OptionItem(id: "Nut Free", name: "Nut Free", icon: "xmark.circle.fill"),
        OptionItem(id: "High Protein", name: "High Protein", icon: "dumbbell.fill"),
        OptionItem(id: "Raw", name: "Raw", icon: "drop.fill"),
        OptionItem(id: "Dairy Free", name: "Dairy Free", icon: "xmark.circle"),
        OptionItem(id: "Keto", name: "Keto", icon: "flame.fill"),
        OptionItem(id: "Paleo", name: "Paleo", icon: "tree.fill"),
        OptionItem(id: "Low Carb", name: "Low Carb", icon: "arrow.down.circle.fill"),
        OptionItem(id: "Low Fat", name: "Low Fat", icon: "arrow.down.circle"),
        OptionItem(id: "Sugar Free", name: "Sugar Free", icon: "xmark.circle"),
        OptionItem(id: "Halal", name: "Halal", icon: "moon.stars.fill"),
        OptionItem(id: "Kosher", name: "Kosher", icon: "star.fill")
    ]

    /// Subtitle under **Pantry ingredients** on generate-recipe and generate-meal-plan sheets.
    static let generateSheetPantryIngredientsSubtitle =
        "Any means recipes can include groceries you don't have; Mostly leans on your pantry; Pantry only uses ingredients you've added."

    static let cannedSpecialRequests: [String] = [
        "Prioritize quick dinners that can be made in about 30 minutes with minimal cleanup.",
        "Give me challenging recipes that will help me learn new cooking techniques.",
        "Prefer one-pan or sheet-pan meals with simple steps and beginner-friendly instructions.",
        "Keep flavors mild and avoid very spicy recipes while still adding lots of flavor."
    ]

    // MARK: - Saved preferences (onboarding + chip order in generate forms)

    /// Order-preserving list from onboarding / prior sessions.
    static func preferredCuisineIdsFromStorage() -> [String] {
        UserDefaults.standard.stringArray(forKey: RecipeGenerationFormPreferenceStorage.cuisineOrderKey) ?? []
    }

    static func preferredDietaryIdsFromStorage() -> [String] {
        UserDefaults.standard.stringArray(forKey: RecipeGenerationFormPreferenceStorage.dietaryOrderKey) ?? []
    }

    static func persistPreferredCuisineIds(_ orderedIds: [String]) {
        UserDefaults.standard.set(orderedIds, forKey: RecipeGenerationFormPreferenceStorage.cuisineOrderKey)
    }

    static func persistPreferredDietaryIds(_ orderedIds: [String]) {
        UserDefaults.standard.set(orderedIds, forKey: RecipeGenerationFormPreferenceStorage.dietaryOrderKey)
    }

    /// Canonical cuisine list with **Any** first, then saved onboarding picks (in order), then the rest.
    static func cuisinesOrderedForForms() -> [OptionItem] {
        guard let anyItem = cuisines.first(where: { $0.id == "Any" }) else {
            return orderedItems(preferredIds: preferredCuisineIdsFromStorage(), allItems: cuisines)
        }
        let nonAny = cuisines.filter { $0.id != "Any" }
        let preferredNonAny = preferredCuisineIdsFromStorage().filter { $0 != "Any" }
        var seen = Set<String>()
        seen.insert("Any")
        var out: [OptionItem] = [anyItem]
        let validIds = Set(nonAny.map(\.id))
        for id in preferredNonAny where validIds.contains(id) && !seen.contains(id) {
            if let item = nonAny.first(where: { $0.id == id }) {
                out.append(item)
                seen.insert(id)
            }
        }
        for item in nonAny where !seen.contains(item.id) {
            out.append(item)
        }
        return out
    }

    /// Canonical dietary list with saved IDs first (in saved order), then the rest unchanged.
    static func dietaryOptionsOrderedForForms() -> [OptionItem] {
        orderedItems(preferredIds: preferredDietaryIdsFromStorage(), allItems: dietaryOptions)
    }

    private static func orderedItems(preferredIds: [String], allItems: [OptionItem]) -> [OptionItem] {
        let validIds = Set(allItems.map(\.id))
        var seen = Set<String>()
        var out: [OptionItem] = []
        out.reserveCapacity(allItems.count)
        for id in preferredIds where validIds.contains(id) && !seen.contains(id) {
            if let item = allItems.first(where: { $0.id == id }) {
                out.append(item)
                seen.insert(id)
            }
        }
        for item in allItems where !seen.contains(item.id) {
            out.append(item)
        }
        return out
    }
}
