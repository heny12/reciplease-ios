//
//  RecipeLibraryQuery.swift
//  Reciplease
//
//  Search, smart filters, and sort for All Recipes and cookbooks.
//

import Foundation

enum RecipeCollectionTag {
    static let weeknight = "Weeknight Go-Tos"
    static let mealPrep = "Meal Prep"
    static let wantToTry = "Want to Try"
    static let favorites = "Favorites"
    static let all = [weeknight, mealPrep, wantToTry, favorites]
}

enum RecipeLibrarySort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case fastest = "Fastest"
    case bestPantryMatch = "Best Pantry Match"
    case recentlyCooked = "Recently Cooked"
    case alphabetical = "A–Z"

    var id: String { rawValue }
}

enum SmartRecipeFilter: String, CaseIterable, Identifiable {
    case under30 = "Under 30 Min"
    case highPantryMatch = "High Pantry Match"
    case wantToTry = "Want to Try"
    case cookedBefore = "Cooked Before"

    var id: String { rawValue }
}

enum RecipeLibraryQuery {
    static func matchesSearch(_ recipe: Recipe, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if recipe.name.localizedCaseInsensitiveContains(trimmed) { return true }
        if recipe.description.localizedCaseInsensitiveContains(trimmed) { return true }
        if recipe.hook?.localizedCaseInsensitiveContains(trimmed) == true { return true }
        if recipe.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(trimmed) }) { return true }
        if recipe.extraIngredients?.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) == true { return true }
        if recipe.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
        return false
    }

    static func matches(recipe: Recipe, smart: SmartRecipeFilter?, pantryScore: Double) -> Bool {
        guard let smart else { return true }
        switch smart {
        case .under30:
            guard let minutes = recipe.totalTimeMinutes else { return false }
            return minutes <= 30
        case .highPantryMatch:
            return pantryScore >= PantryMatchCalculator.highMatchThreshold
        case .wantToTry:
            return recipe.tags.contains { $0.caseInsensitiveCompare(RecipeCollectionTag.wantToTry) == .orderedSame }
        case .cookedBefore:
            return recipe.cookedCount > 0
        }
    }

    static func sorted(
        _ recipes: [Recipe],
        by sort: RecipeLibrarySort,
        pantryScores: [UUID: Double]
    ) -> [Recipe] {
        switch sort {
        case .newest:
            return recipes.sorted { lhs, rhs in
                let left = lhs.catalogedAt ?? .distantPast
                let right = rhs.catalogedAt ?? .distantPast
                if left != right { return left > right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .fastest:
            return recipes.sorted { lhs, rhs in
                let left = lhs.totalTimeMinutes ?? Int.max
                let right = rhs.totalTimeMinutes ?? Int.max
                if left != right { return left < right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .bestPantryMatch:
            return recipes.sorted { lhs, rhs in
                let left = pantryScores[lhs.id] ?? 0
                let right = pantryScores[rhs.id] ?? 0
                if left != right { return left > right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .recentlyCooked:
            return recipes.sorted { lhs, rhs in
                let left = lhs.lastCookedAt ?? .distantPast
                let right = rhs.lastCookedAt ?? .distantPast
                if left != right { return left > right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .alphabetical:
            return recipes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}
