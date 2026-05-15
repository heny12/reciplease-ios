//
//  PantryViewModel.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Validation Errors

/// One checked empty slot on the meal-plan sheet (chronological days, B → L → S → D → dessert per day).
struct MealPlanSlotSelection: Sendable {
    let dayKey: String
    let slot: MealPlanSlot
}

/// Snapshot from `GenerateMealPlanPlaceholderSheet` for `generateMealPlanFromSheet`.
struct MealPlanGenerationSheetPayload: Sendable {
    let mealTypeCounts: MealTypeCounts
    let orderedSelectedSlots: [MealPlanSlotSelection]
    let prompt: String?
    let strictness: MealPlanStrictness
}

enum ValidationError: LocalizedError {
    case maxIngredientsReached(maxCount: Int)
    case ingredientNameTooLong(maxLength: Int)
    case generatePromptTooLong(maxLength: Int)
    case modifyPromptTooLong(maxLength: Int)
    
    var errorDescription: String? {
        switch self {
        case .maxIngredientsReached(let maxCount):
            return "You can only have up to \(maxCount) ingredients in your pantry. Please remove some ingredients before adding more."
        case .ingredientNameTooLong(let maxLength):
            return "Ingredient name must be \(maxLength) characters or less."
        case .generatePromptTooLong(let maxLength):
            return "Recipe preferences must be \(maxLength) characters or less."
        case .modifyPromptTooLong(let maxLength):
            return "Modification request must be \(maxLength) characters or less."
        }
    }
}

// Struct to hold image and its uploaded URL
struct ImageWithURL: Identifiable {
    let id: UUID
    let image: UIImage
    var uploadedURL: String?
    var isUploading: Bool = false
    
    init(id: UUID = UUID(), image: UIImage, uploadedURL: String? = nil, isUploading: Bool = false) {
        self.id = id
        self.image = image
        self.uploadedURL = uploadedURL
        self.isUploading = isUploading
    }
}

// Extension to make it easier to update
extension ImageWithURL {
    func with(uploadedURL: String? = nil, isUploading: Bool? = nil) -> ImageWithURL {
        var updated = self
        if let uploadedURL = uploadedURL {
            updated.uploadedURL = uploadedURL
        }
        if let isUploading = isUploading {
            updated.isUploading = isUploading
        }
        return updated
    }
}

struct Cookbook: Identifiable, Hashable {
    let id: UUID
    var name: String
    var recipeIds: [UUID]
    let createdAt: Date
    var isDefaultFavorites: Bool
    var isDefaultUncategorized: Bool
}

struct PantryMatchBreakdown {
    let matchedIngredientCount: Int
    let totalIngredientCount: Int
    let score: Double
}

class PantryViewModel: ObservableObject {
    private let maxConcurrentRecipeImageGenerations = 4
    /// Max recipes shown in the Recipes tab (newest first); oldest dropped when over cap. Cookbook data is separate (`favoritedRecipes`).
    private let maxRecipesInRecipesTab = 30
    private let cookbookMigrationFlagKey = "Reciplease.CookbooksMigrationComplete.v1"

    @Published var ingredients: [Ingredient] = []
    @Published var recipes: [Recipe] = []  // Generated recipes (for Recipes tab, persisted to local storage)
    @Published var favoritedRecipes: [Recipe] = []  // Bookmarked recipes (kept for compatibility)
    @Published var selectedImages: [ImageWithURL] = []
    @Published var favoriteRecipeIds: [UUID] = []  // Keep for backward compatibility
    @Published var cookbooks: [Cookbook] = []
    @Published var pantryMatchScores: [UUID: Double] = [:]
    
    @Published var pantryInsights: [String] = []
    @Published var isLoadingInsights = false

    /// Plan tab: `yyyy-MM-dd` → at most one recipe per meal slot.
    @Published var mealPlanByDay: [String: SavedDayMealPlan] = [:]
    /// EventKit event identifiers for synced Plan meals (parallel to `mealPlanByDay` keys).
    @Published var mealPlanCalendarEventIdsByDay: [String: SavedDayMealPlanCalendarIds] = [:]
    @Published var groceryItems: [GroceryListItem] = []
    
    @Published var isDetectingIngredients = false
    @Published var isGeneratingRecipes = false
    @Published var isScanningCookbookRecipes = false
    @Published var isScanningWebRecipes = false
    @Published var isModifyingRecipe = false
    
    // Computed property to track if any loading screen is active
    var isAnyLoadingActive: Bool {
        isDetectingIngredients || isGeneratingRecipes || isScanningWebRecipes || isModifyingRecipe
    }
    
    @Published var errorMessage: String?
    @Published var shouldNavigateToIngredients = false
    @Published var shouldNavigateToScan = false
    /// Set from Home (or elsewhere); ContentView presents cookbook scan after credit check.
    @Published var shouldOpenCookbookRecipeScan = false
    /// Set from Home (or elsewhere); ContentView presents web recipe scan after credit check.
    @Published var shouldOpenWebRecipeScan = false
    /// Set from Cookbooks recipe library pills (or elsewhere); ContentView presents generate sheet after pantry + credit checks.
    @Published var shouldOpenRecipeGeneratePrompt = false
    @Published var shouldNavigateToCookbooks: UUID? = nil
    /// When set, `CookbooksView` pushes `CookbookDetailView` for this id (e.g. after generating recipes). Cleared when the user pops. Skipped when `deepLinkedRecipeIdToOpen` is set (recipe detail takes precedence).
    @Published var openCookbookDetailId: UUID? = nil
    /// After adding a recipe to the meal plan from recipe detail (or elsewhere), switch to the Plan tab.
    @Published var shouldNavigateToPlan = false
    /// After adding planned ingredients to the grocery list, switch to the Grocery tab.
    @Published var shouldNavigateToGroceryList = false
    @Published var isShowingRecipeDetail: Bool = false  // Recipe ID to scroll to
    @Published var isShowingRecipePrompt: Bool = false  // Track recipe prompt visibility
    @Published var showNoRecipesAlert = false
    @Published var showNoIngredientsAlert = false
    @Published var deepLinkedRecipeIdToOpen: UUID? = nil
    @Published var cookbookValidationMessage: String?
    
    // Usage limit tracking
    let usageTracker = UsageTracker.shared
    
    var defaultCookbookId: UUID? {
        cookbooks.first(where: { $0.isDefaultFavorites })?.id ?? cookbooks.first?.id
    }

    var uncategorizedCookbookId: UUID? {
        cookbooks.first(where: { $0.isDefaultUncategorized })?.id
    }

    /// Free users are capped by `AppConfig.maxCookbooks`; Pro subscribers can create unlimited cookbooks.
    /// System cookbooks (Favorites, Uncategorized) do not count toward the free limit.
    var canCreateMoreCookbooks: Bool {
        if RevenueCatService.shared.isProMember {
            return true
        }
        let userCreatedCount = cookbooks.filter { !$0.isDefaultFavorites && !$0.isDefaultUncategorized }.count
        return userCreatedCount < AppConfig.maxCookbooks
    }

    /// Active recipes sorted by pantry match score (highest first), then name. Used for the Pantry list (collapsible).
    var pantryMatchRecipesSortedByScore: [Recipe] {
        uniqueActiveRecipes
            .sorted {
                let lhsScore = pantryMatchScores[$0.id] ?? 0
                let rhsScore = pantryMatchScores[$1.id] ?? 0
                if lhsScore == rhsScore {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
    }
    
    /// Checks if a recipe is bookmarked into a cookbook.
    func isFavorite(recipeId: UUID) -> Bool {
        favoritedRecipes.contains { $0.id == recipeId }
    }

    func cookbookContainingRecipe(recipeId: UUID) -> Cookbook? {
        cookbooks.first { $0.recipeIds.contains(recipeId) }
    }

    @MainActor
    func ensureUncategorizedCookbookExists() {
        guard !cookbooks.contains(where: { $0.isDefaultUncategorized }) else { return }
        cookbooks.insert(
            Cookbook(
                id: UUID(),
                name: "Uncategorized",
                recipeIds: [],
                createdAt: Date(),
                isDefaultFavorites: false,
                isDefaultUncategorized: true
            ),
            at: 0
        )
        saveData()
    }

    /// Moves recipes into the system Uncategorized cookbook (single membership). Does not set navigation flags.
    /// - Parameter prependToUncategorized: When `true`, new ids are inserted at the front in `ids` order (newest batch first). When `false`, they are appended.
    @MainActor
    func attachRecipeIdsToUncategorized(_ ids: [UUID], prependToUncategorized: Bool = false) {
        let uniqueIds = Array(NSOrderedSet(array: ids)) as? [UUID] ?? ids
        guard !uniqueIds.isEmpty else { return }

        ensureUncategorizedCookbookExists()
        guard let uncatId = uncategorizedCookbookId,
              let uncatIndex = cookbooks.firstIndex(where: { $0.id == uncatId }) else { return }

        for recipeId in uniqueIds {
            for i in cookbooks.indices where i != uncatIndex {
                cookbooks[i].recipeIds.removeAll { $0 == recipeId }
            }
            cookbooks[uncatIndex].recipeIds.removeAll { $0 == recipeId }
        }

        let tail = cookbooks[uncatIndex].recipeIds
        if prependToUncategorized {
            cookbooks[uncatIndex].recipeIds = uniqueIds + tail
        } else {
            cookbooks[uncatIndex].recipeIds = tail + uniqueIds
        }

        for recipeId in uniqueIds {
            guard let recipe = (recipes + favoritedRecipes).first(where: { $0.id == recipeId }) else { continue }
            recipes.removeAll { $0.id == recipeId }
            if !favoritedRecipes.contains(where: { $0.id == recipeId }) {
                favoritedRecipes.append(recipe)
            }
        }

        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        let lookup = makeRecipeLookup(recipes + favoritedRecipes)
        favoritedRecipes = favoriteRecipeIds.compactMap { lookup[$0] }
        saveData()
    }

    private func makeRecipeLookup(_ source: [Recipe]) -> [UUID: Recipe] {
        source.reduce(into: [UUID: Recipe]()) { result, recipe in
            // Later entries win, which lets the freshest copy replace stale duplicates.
            result[recipe.id] = recipe
        }
    }

    private var uniqueActiveRecipes: [Recipe] {
        var seen = Set<UUID>()
        return (recipes + favoritedRecipes).filter { recipe in
            guard !seen.contains(recipe.id) else { return false }
            seen.insert(recipe.id)
            return true
        }
    }

    private let pantryStaples: Set<String> = [
        "salt", "pepper", "black pepper", "oil", "olive oil", "vegetable oil",
        "canola oil", "cooking oil", "butter", "water", "sugar", "flour", "all-purpose flour",
        "baking powder", "baking soda", "vanilla", "vanilla extract", "garlic powder",
        "onion powder", "paprika", "cinnamon", "cumin", "oregano", "basil", "thyme",
        "rosemary", "bay leaf", "bay leaves", "vinegar", "soy sauce", "honey", "maple syrup",
        "mustard", "ketchup", "mayonnaise", "hot sauce", "worcestershire sauce",
        "chili powder", "brown sugar", "white vinegar"
    ]

    private func normalizedIngredientName(_ name: String) -> String {
        name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func computePantryMatchBreakdown(for recipe: Recipe, pantrySnapshot: [Ingredient]) -> PantryMatchBreakdown {
        let rows = recipe.ingredients.filter { !normalizedIngredientName($0.name).isEmpty }
        let totalCount = rows.count
        guard totalCount > 0 else {
            return PantryMatchBreakdown(matchedIngredientCount: 0, totalIngredientCount: 0, score: 0)
        }

        let matchedCount = rows.reduce(into: 0) { count, ing in
            if recipeIngredientInUserPantry(ing.name, pantryItems: pantrySnapshot)
                || recipeIngredientIsPantryStaple(ing.name) {
                count += 1
            }
        }

        let rawScore = Double(matchedCount) / Double(totalCount)
        let clampedScore = min(max(rawScore, 0), 1)
        return PantryMatchBreakdown(
            matchedIngredientCount: matchedCount,
            totalIngredientCount: totalCount,
            score: clampedScore
        )
    }

    func pantryMatchBreakdown(for recipe: Recipe) -> PantryMatchBreakdown {
        computePantryMatchBreakdown(for: recipe, pantrySnapshot: ingredients)
    }

    func pantryMatchScore(for recipeId: UUID) -> Double {
        pantryMatchScores[recipeId] ?? 0
    }

    private func schedulePantryMatchScoreRecalculation() {
        let pantrySnapshot = ingredients
        let activeRecipes = uniqueActiveRecipes
        let validRecipeIds = Set(activeRecipes.map(\.id))

        pantryMatchRecalculationTask?.cancel()
        pantryMatchRecalculationTask = Task(priority: .utility) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            var nextScores: [UUID: Double] = [:]
            nextScores.reserveCapacity(activeRecipes.count)
            for recipe in activeRecipes {
                guard !Task.isCancelled else { return }
                let breakdown = self.computePantryMatchBreakdown(for: recipe, pantrySnapshot: pantrySnapshot)
                nextScores[recipe.id] = breakdown.score
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.applyPantryMatchScores(nextScores, validRecipeIds: validRecipeIds)
            }
        }
    }

    @MainActor
    private func applyPantryMatchScores(_ nextScores: [UUID: Double], validRecipeIds: Set<UUID>) {
        let prunedScores = nextScores.filter { validRecipeIds.contains($0.key) }
        if pantryMatchScores != prunedScores {
            pantryMatchScores = prunedScores
        }
        persistenceService.savePantryMatchScores(prunedScores)
    }

    func recipes(for cookbookId: UUID) -> [Recipe] {
        guard let cookbook = cookbooks.first(where: { $0.id == cookbookId }) else { return [] }
        let recipeMap = makeRecipeLookup(recipes + favoritedRecipes)
        return cookbook.recipeIds.reversed().compactMap { recipeMap[$0] }
    }

    // MARK: - Meal plan (Plan tab)

    private static func pruneMealPlan(
        _ plan: [String: SavedDayMealPlan],
        validRecipeIds: Set<UUID>
    ) -> [String: SavedDayMealPlan] {
        func keep(_ id: UUID?) -> UUID? {
            guard let id, validRecipeIds.contains(id) else { return nil }
            return id
        }
        var out: [String: SavedDayMealPlan] = [:]
        for (day, slots) in plan {
            let pruned = SavedDayMealPlan(
                breakfast: keep(slots.breakfast),
                lunch: keep(slots.lunch),
                snack: keep(slots.snack),
                dinner: keep(slots.dinner),
                dessert: keep(slots.dessert)
            )
            if pruned.breakfast != nil || pruned.lunch != nil || pruned.snack != nil || pruned.dinner != nil || pruned.dessert != nil {
                out[day] = pruned
            }
        }
        return out
    }

    func setPlannedRecipe(dayKey: String, slot: MealPlanSlot, recipeId: UUID) {
        var dayPlan = mealPlanByDay[dayKey] ?? SavedDayMealPlan()
        dayPlan.setRecipe(recipeId, for: slot)
        mealPlanByDay[dayKey] = dayPlan
        shouldNavigateToPlan = true
        scheduleMealPlanCalendarReconcile()
    }

    func clearPlannedRecipe(dayKey: String, slot: MealPlanSlot) {
        guard var dayPlan = mealPlanByDay[dayKey] else { return }
        dayPlan.setRecipe(nil, for: slot)
        if dayPlan.breakfast == nil, dayPlan.lunch == nil, dayPlan.snack == nil, dayPlan.dinner == nil, dayPlan.dessert == nil {
            mealPlanByDay.removeValue(forKey: dayKey)
        } else {
            mealPlanByDay[dayKey] = dayPlan
        }
        scheduleMealPlanCalendarReconcile()
    }

    func plannedRecipe(dayKey: String, slot: MealPlanSlot) -> Recipe? {
        guard let id = mealPlanByDay[dayKey]?.recipeId(for: slot) else { return nil }
        return makeRecipeLookup(recipes + favoritedRecipes)[id]
    }

    /// Meal slots with a recipe from start of today onward (Plan tab subtitle / badges).
    var plannedMealSlotsFromTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var n = 0
        for (dayKey, plan) in mealPlanByDay {
            guard let day = Self.dateForMealPlanDayKey(dayKey, calendar: calendar), day >= today else { continue }
            for slot in MealPlanSlot.allCases {
                if plan.recipeId(for: slot) != nil { n += 1 }
            }
        }
        return n
    }

    private static func dateForMealPlanDayKey(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return calendar.date(from: c).map { calendar.startOfDay(for: $0) }
    }

    /// Pantry list only (not staples); aligned with recipe detail “in pantry” matching.
    func recipeIngredientInUserPantry(_ ingredientName: String) -> Bool {
        recipeIngredientInUserPantry(ingredientName, pantryItems: ingredients)
    }

    /// Same as ``recipeIngredientInUserPantry(_:)`` but uses a fixed pantry snapshot (e.g. background score recompute).
    private func recipeIngredientInUserPantry(_ ingredientName: String, pantryItems: [Ingredient]) -> Bool {
        let normalizedName = ingredientName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return false }
        let words = normalizedName.components(separatedBy: " ")

        for pantryItem in pantryItems {
            let pantryName = pantryItem.generalName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pantryName.isEmpty else { continue }

            if normalizedName == pantryName {
                return true
            }

            if normalizedName.contains(pantryName) || pantryName.contains(normalizedName) {
                return true
            }

            let pantryWords = pantryName.components(separatedBy: " ")
            for pantryWord in pantryWords {
                if pantryWord.count > 3 && normalizedName.contains(pantryWord) {
                    return true
                }
            }
            for word in words {
                if word.count > 3 && pantryName.contains(word) {
                    return true
                }
            }
        }

        return false
    }

    /// Common pantry staples (salt, oil, …) — same heuristic as recipe detail.
    func recipeIngredientIsPantryStaple(_ ingredientName: String) -> Bool {
        let normalizedName = normalizedIngredientName(ingredientName)
        guard !normalizedName.isEmpty else { return false }
        if pantryStaples.contains(normalizedName) {
            return true
        }
        for word in normalizedName.components(separatedBy: " ") where !word.isEmpty {
            if pantryStaples.contains(word) {
                return true
            }
        }
        return false
    }

    @MainActor
    func createCookbook(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            cookbookValidationMessage = "Cookbook name cannot be empty."
            return false
        }
        guard trimmedName.count <= AppConfig.maxCookbookNameLength else {
            cookbookValidationMessage = "Cookbook name must be \(AppConfig.maxCookbookNameLength) characters or less."
            return false
        }
        guard canCreateMoreCookbooks else {
            cookbookValidationMessage = "You can create up to \(AppConfig.maxCookbooks) cookbooks. Upgrade to Pro for unlimited cookbooks."
            return false
        }
        guard !cookbooks.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            cookbookValidationMessage = "A cookbook with this name already exists."
            return false
        }
        guard trimmedName.caseInsensitiveCompare("Uncategorized") != .orderedSame else {
            cookbookValidationMessage = "That name is reserved for the default recipe folder."
            return false
        }

        cookbooks.append(
            Cookbook(
                id: UUID(),
                name: trimmedName,
                recipeIds: [],
                createdAt: Date(),
                isDefaultFavorites: false,
                isDefaultUncategorized: false
            )
        )
        cookbookValidationMessage = nil
        saveData()
        return true
    }
    
    /// Helper function to update a recipe in both lists if it exists
    @MainActor
    private func updateRecipeInBothLists(recipeId: UUID, updateClosure: (Recipe) -> Recipe) {
        var updated = false
        
        // Update in recipes list
        if let index = recipes.firstIndex(where: { $0.id == recipeId }) {
            var updatedRecipes = recipes
            updatedRecipes[index] = updateClosure(recipes[index])
            recipes = updatedRecipes
            updated = true
        }
        
        // Update in favoritedRecipes list
        if let index = favoritedRecipes.firstIndex(where: { $0.id == recipeId }) {
            var updatedFavoritedRecipes = favoritedRecipes
            updatedFavoritedRecipes[index] = updateClosure(favoritedRecipes[index])
            favoritedRecipes = updatedFavoritedRecipes
            updated = true
        }
        
        if updated {
            saveData()
        }
    }

    /// Marks image-generation state for multiple recipes in a single save/update pass.
    @MainActor
    private func updateRecipesImageGenerationState(recipeIds: Set<UUID>, isGenerating: Bool) {
        guard !recipeIds.isEmpty else { return }

        var updated = false

        let updatedRecipes = recipes.map { recipe -> Recipe in
            guard recipeIds.contains(recipe.id), recipe.isGeneratingImage != isGenerating else {
                return recipe
            }
            updated = true
            return Recipe(
                id: recipe.id,
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                steps: recipe.steps,
                prepTimeMinutes: recipe.prepTimeMinutes,
                cookTimeMinutes: recipe.cookTimeMinutes,
                servings: recipe.servings,
                difficulty: recipe.difficulty,
                imageURL: recipe.imageURL,
                isGeneratingImage: isGenerating,
                tips: recipe.tips,
                source: recipe.source
            )
        }

        let updatedFavoritedRecipes = favoritedRecipes.map { recipe -> Recipe in
            guard recipeIds.contains(recipe.id), recipe.isGeneratingImage != isGenerating else {
                return recipe
            }
            updated = true
            return Recipe(
                id: recipe.id,
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                steps: recipe.steps,
                prepTimeMinutes: recipe.prepTimeMinutes,
                cookTimeMinutes: recipe.cookTimeMinutes,
                servings: recipe.servings,
                difficulty: recipe.difficulty,
                imageURL: recipe.imageURL,
                isGeneratingImage: isGenerating,
                tips: recipe.tips,
                source: recipe.source
            )
        }

        guard updated else { return }

        recipes = updatedRecipes
        favoritedRecipes = updatedFavoritedRecipes
        saveData()
    }

    private func generateImagesForRecipesInBackground(recipeIds: [UUID]) async {
        let uniqueRecipeIds = Array(NSOrderedSet(array: recipeIds)) as? [UUID] ?? recipeIds
        guard !uniqueRecipeIds.isEmpty else {
            print("⚠️ No recipes queued for background image generation")
            return
        }

        print("🖼️ Starting background image generation for \(uniqueRecipeIds.count) recipe(s)")

        await MainActor.run {
            updateRecipesImageGenerationState(recipeIds: Set(uniqueRecipeIds), isGenerating: true)
        }

        let maxConcurrentTasks = min(maxConcurrentRecipeImageGenerations, uniqueRecipeIds.count)
        await withTaskGroup(of: Void.self) { group in
            var nextIndex = 0

            func enqueueNextIfNeeded() {
                guard nextIndex < uniqueRecipeIds.count else { return }
                let recipeId = uniqueRecipeIds[nextIndex]
                nextIndex += 1
                group.addTask {
                    await self.generateRecipeImage(recipeId: recipeId, shouldMarkLoadingState: false)
                }
            }

            for _ in 0..<maxConcurrentTasks {
                enqueueNextIfNeeded()
            }

            while await group.next() != nil {
                enqueueNextIfNeeded()
            }
        }

        print("✅ Finished background image generation queue")
    }
    
    /// Reloads recipes from local storage (for Recipes tab)
    /// Filters out bookmarked recipes so they don't appear in both tabs
    @MainActor
    func reloadRecipes() {
        let savedData = persistenceService.load()
        let bookmarkedIds = Set(savedData.cookbooks.flatMap(\.recipeIds))
        recipes = savedData.recipes.map { recipe in
            Recipe(
                id: recipe.id,
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                steps: recipe.steps,
                prepTimeMinutes: recipe.prepTimeMinutes,
                cookTimeMinutes: recipe.cookTimeMinutes,
                servings: recipe.servings,
                difficulty: recipe.difficulty,
                imageURL: recipe.imageURL,
                isGeneratingImage: false,
                tips: recipe.tips,
                source: recipe.source
            )
        }.filter { !bookmarkedIds.contains($0.id) }
        trimRecipesTabToLimitIfNeeded()
        print("🔄 Reloaded \(recipes.count) recipes from storage (excluding \(bookmarkedIds.count) bookmarked)")
    }
    
    /// Reloads bookmarked recipes from local storage (for Cookbooks tab)
    @MainActor
    func reloadFavoritedRecipes() {
        let savedData = persistenceService.load()
        cookbooks = normalizedCookbookDisplayOrder(savedData.cookbooks.map {
            Cookbook(
                id: $0.id,
                name: $0.name,
                recipeIds: $0.recipeIds,
                createdAt: $0.createdAt,
                isDefaultFavorites: $0.isDefaultFavorites,
                isDefaultUncategorized: $0.isDefaultUncategorized
            )
        })
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))

        let lookup = makeRecipeLookup(savedData.recipes + savedData.favoritedRecipes)
        favoritedRecipes = favoriteRecipeIds.compactMap { lookup[$0] }.map { recipe in
            Recipe(
                id: recipe.id,
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                steps: recipe.steps,
                prepTimeMinutes: recipe.prepTimeMinutes,
                cookTimeMinutes: recipe.cookTimeMinutes,
                servings: recipe.servings,
                difficulty: recipe.difficulty,
                imageURL: recipe.imageURL,
                isGeneratingImage: false,
                tips: recipe.tips,
                source: recipe.source
            )
        }
        print("🔄 Reloaded \(favoritedRecipes.count) bookmarked recipes from storage")
    }
    
    /// Adds a recipe to the chosen cookbook.
    /// - Parameter navigateToCookbooksTab: When true (default), switches the main tab to Cookbooks after saving—omit when the user is already managing cookbooks in-context (e.g. list swipe).
    @MainActor
    func addRecipeToCookbook(recipeId: UUID, cookbookId: UUID, navigateToCookbooksTab: Bool = true) {
        guard let cookbookIndex = cookbooks.firstIndex(where: { $0.id == cookbookId }) else { return }

        if let currentCookbookIndex = cookbooks.firstIndex(where: { $0.recipeIds.contains(recipeId) }) {
            cookbooks[currentCookbookIndex].recipeIds.removeAll { $0 == recipeId }
        }

        cookbooks[cookbookIndex].recipeIds.removeAll { $0 == recipeId }
        cookbooks[cookbookIndex].recipeIds.append(recipeId)

        if let recipe = (recipes + favoritedRecipes).first(where: { $0.id == recipeId }) {
            if !favoritedRecipes.contains(where: { $0.id == recipeId }) {
                favoritedRecipes.append(recipe)
            }

            reviewPromptService.registerFavoriteAction()
            AppAnalytics.log(.recipeBookmarked, parameters: [
                "recipe_name": recipe.name,
                "cookbook_name": cookbooks[cookbookIndex].name
            ])
        }

        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        if navigateToCookbooksTab {
            shouldNavigateToCookbooks = cookbookId
        }
        saveData()
    }

    @MainActor
    func moveRecipeToCookbook(recipeId: UUID, fromCookbookId: UUID, toCookbookId: UUID) {
        guard fromCookbookId != toCookbookId else { return }
        guard let fromIndex = cookbooks.firstIndex(where: { $0.id == fromCookbookId }),
              let toIndex = cookbooks.firstIndex(where: { $0.id == toCookbookId }) else { return }

        cookbooks[fromIndex].recipeIds.removeAll { $0 == recipeId }
        cookbooks[toIndex].recipeIds.removeAll { $0 == recipeId }
        cookbooks[toIndex].recipeIds.append(recipeId)
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        saveData()
    }

    @MainActor
    func removeRecipeFromCookbook(recipeId: UUID, cookbookId: UUID) {
        guard let cookbookIndex = cookbooks.firstIndex(where: { $0.id == cookbookId }) else { return }
        cookbooks[cookbookIndex].recipeIds.removeAll { $0 == recipeId }
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))

        if !favoriteRecipeIds.contains(recipeId) {
            favoritedRecipes.removeAll { $0.id == recipeId }
        }

        if let recipe = (recipes + favoritedRecipes).first(where: { $0.id == recipeId }) {
            AppAnalytics.log(.recipeUnbookmarked, parameters: [
                "recipe_name": recipe.name,
                "cookbook_name": cookbooks[cookbookIndex].name
            ])
        }
        saveData()
    }

    @MainActor
    func deleteCookbook(cookbookId: UUID) -> Bool {
        guard let cookbookIndex = cookbooks.firstIndex(where: { $0.id == cookbookId }) else { return false }

        let cookbook = cookbooks[cookbookIndex]
        guard !cookbook.isDefaultFavorites else {
            cookbookValidationMessage = "The Favorites cookbook cannot be deleted."
            return false
        }

        let removedRecipeIds = cookbook.recipeIds
        cookbooks.remove(at: cookbookIndex)

        // Recompute membership after deletion.
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        let recipeLookup = makeRecipeLookup(recipes + favoritedRecipes)

        // Recipes removed from all cookbooks return to the loose `recipes` list (Pantry suggestions / library).
        for recipeId in removedRecipeIds where !favoriteRecipeIds.contains(recipeId) {
            guard let recipe = recipeLookup[recipeId] else { continue }
            if !recipes.contains(where: { $0.id == recipeId }) {
                recipes.insert(recipe, at: 0)
            }
        }

        favoritedRecipes.removeAll { !favoriteRecipeIds.contains($0.id) }
        cookbookValidationMessage = nil
        saveData()

        AppAnalytics.log(.cookbookDeleted, parameters: [
            "cookbook_name": cookbook.name,
            "recipe_count": removedRecipeIds.count
        ])
        return true
    }

    /// Legacy compatibility wrapper.
    @MainActor
    func toggleFavorite(recipeId: UUID) {
        if let cookbook = cookbookContainingRecipe(recipeId: recipeId) {
            removeRecipeFromCookbook(recipeId: recipeId, cookbookId: cookbook.id)
        } else if let defaultId = defaultCookbookId {
            addRecipeToCookbook(recipeId: recipeId, cookbookId: defaultId)
        }
    }
    
    /// Deletes a recipe from the library (all cookbooks, generated list, and bookmark storage).
    @MainActor
    func deleteRecipe(recipeId: UUID) {
        let recipe = (recipes + favoritedRecipes).first(where: { $0.id == recipeId })

        for i in cookbooks.indices {
            cookbooks[i].recipeIds.removeAll { $0 == recipeId }
        }
        recipes.removeAll { $0.id == recipeId }
        favoritedRecipes.removeAll { $0.id == recipeId }
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        saveData()

        if let recipe {
            AppAnalytics.log(.recipeDeleted, parameters: [
                "recipe_name": recipe.name
            ])
        }
    }
    
    private let gcsService = GCSUploadService.shared
    private let apiService = RecipeAPIService.shared
    private let persistenceService = PersistenceService.shared
    private let reviewPromptService = ReviewPromptService.shared
    private var cancellables = Set<AnyCancellable>()
    private var pantryMatchRecalculationTask: Task<Void, Never>?
    
    init() {
        // Load saved data
        loadData()
        
        // Auto-save when data changes
        setupAutoSave()
    }
    
    deinit {
        pantryMatchRecalculationTask?.cancel()
    }
    
    
    /// Detects ingredients from already-uploaded images
    /// - Parameter mergeWithExisting: If true, adds new ingredients to existing ones (with deduplication). If false, replaces all ingredients.
    func detectIngredients(mergeWithExisting: Bool = false) async {
        // Ingredient scanning is free for all users (no generation credits).
        // Collect all uploaded URLs and validate them
        let imageURLs = selectedImages.compactMap { imageWithURL -> String? in
            guard let urlString = imageWithURL.uploadedURL,
                  !urlString.isEmpty,
                  URL(string: urlString) != nil else {
                print("⚠️ Invalid or missing URL for image \(imageWithURL.id)")
                return nil
            }
            return urlString
        }
        
        print("🔍 detectIngredients called (mergeWithExisting: \(mergeWithExisting))")
        print("📸 Total selected images: \(selectedImages.count)")
        print("🔗 Valid image URLs: \(imageURLs.count)")
        
        // Log each image's status
        for (index, imageWithURL) in selectedImages.enumerated() {
            if let url = imageWithURL.uploadedURL {
                print("   [\(index + 1)] Image \(imageWithURL.id): URL = \(url)")
            } else {
                print("   [\(index + 1)] Image \(imageWithURL.id): No URL (uploading: \(imageWithURL.isUploading))")
            }
        }
        
        guard !imageURLs.isEmpty else {
            print("⚠️ No valid image URLs available")
            await MainActor.run {
                if selectedImages.contains(where: { $0.isUploading }) {
                    errorMessage = "Please wait for images to finish uploading"
                } else {
                    errorMessage = "No valid image URLs found. Please add images again."
                }
            }
            return
        }
        
        await MainActor.run {
            isDetectingIngredients = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isDetectingIngredients = false
            }
        }
        
        do {
            // Detect ingredients from uploaded images
            let detectedIngredients = try await apiService.detectIngredients(imageURLs: imageURLs)
            
            // Check if no ingredients were detected
            if detectedIngredients.isEmpty {
                await MainActor.run {
                    showNoIngredientsAlert = true
                    print("⚠️ No ingredients detected from images")
                }
                return
            }
            
            await MainActor.run {
                // Capitalize ingredient names
                var capitalizedIngredients = detectedIngredients
                for i in 0..<capitalizedIngredients.count {
                    capitalizedIngredients[i].capitalizeName()
                }
                
                if mergeWithExisting {
                    // Add new ingredients, deduplicating by general name (case-insensitive)
                    let existingNames = Set(ingredients.map { $0.generalName.lowercased() })
                    let newIngredients = capitalizedIngredients.filter { newIngredient in
                        !existingNames.contains(newIngredient.generalName.lowercased())
                    }
                    
                    // Enforce max ingredients limit
                    let currentCount = ingredients.count
                    let availableSlots = AppConfig.maxIngredients - currentCount
                    if availableSlots <= 0 {
                        errorMessage = ValidationError.maxIngredientsReached(maxCount: AppConfig.maxIngredients).localizedDescription
                        print("⚠️ Cannot add ingredients: max limit (\(AppConfig.maxIngredients)) reached")
                        return
                    }
                    
                    let ingredientsToAdd = Array(newIngredients.prefix(availableSlots))
                    ingredients.append(contentsOf: ingredientsToAdd)
                    
                    if newIngredients.count > availableSlots {
                        let skipped = newIngredients.count - availableSlots
                        print("⚠️ Only added \(ingredientsToAdd.count) ingredients (skipped \(skipped) due to max limit of \(AppConfig.maxIngredients))")
                        errorMessage = "Added \(ingredientsToAdd.count) ingredients. Some were skipped because you've reached the maximum of \(AppConfig.maxIngredients) ingredients."
                    } else {
                        print("✅ Added \(newIngredients.count) new ingredients (skipped \(capitalizedIngredients.count - newIngredients.count) duplicates)")
                    }
                } else {
                    // Replace all ingredients - enforce max limit
                    let ingredientsToAdd = Array(capitalizedIngredients.prefix(AppConfig.maxIngredients))
                    ingredients = ingredientsToAdd
                    
                    if capitalizedIngredients.count > AppConfig.maxIngredients {
                        let skipped = capitalizedIngredients.count - AppConfig.maxIngredients
                        print("⚠️ Only kept \(ingredientsToAdd.count) ingredients (skipped \(skipped) due to max limit of \(AppConfig.maxIngredients))")
                        errorMessage = "Added \(ingredientsToAdd.count) ingredients. Some were skipped because the maximum is \(AppConfig.maxIngredients) ingredients."
                    } else {
                        print("✅ Replaced pantry with \(capitalizedIngredients.count) ingredients")
                    }
                }
                
                saveData() // Save after detecting ingredients
                
                // Clear scanned images after successful detection
                selectedImages = []
                
                shouldNavigateToIngredients = true
                
                // Record usage after successful scan
                usageTracker.recordScan()
                
                // Log analytics event
                AppAnalytics.log(.ingredientsScanned, parameters: [
                    "ingredient_count": detectedIngredients.count,
                    "image_count": imageURLs.count
                ])

                pantryInsights = []
                fetchPantryInsights()
            }
        } catch let error as APIError {
            await MainActor.run {
                // Use the user-friendly error message from APIError
                self.errorMessage = error.localizedDescription
                print("❌ Error in detectIngredients: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to detect ingredients. Please try again."
                print("❌ Unexpected error in detectIngredients: \(error)")
            }
        }
    }

    /// Scans cookbook recipe photos and adds parsed recipes to the Recipes tab list.
    func scanCookbookRecipesFromSelectedImages() async {
        // Use recipe generation quota since this flow returns generated recipes.
        let canGenerate = await MainActor.run {
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
            if GenerationCreditsManager.shared.canConsumeGenerationCredit() {
                return true
            }
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
            return false
        }

        guard canGenerate else { return }

        let imageURLs = selectedImages.compactMap { imageWithURL -> String? in
            guard let urlString = imageWithURL.uploadedURL,
                  !urlString.isEmpty,
                  URL(string: urlString) != nil else {
                return nil
            }
            return urlString
        }

        guard !imageURLs.isEmpty else {
            await MainActor.run {
                if selectedImages.contains(where: { $0.isUploading }) {
                    errorMessage = "Please wait for images to finish uploading"
                } else {
                    errorMessage = "No valid image URLs found. Please add images again."
                }
            }
            return
        }

        await MainActor.run {
            isScanningCookbookRecipes = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isScanningCookbookRecipes = false
            }
        }

        do {
            let scannedRecipes = try await apiService.scanCookbookRecipes(imageURLs: imageURLs)
            await MainActor.run {
                if scannedRecipes.isEmpty {
                    showNoRecipesAlert = true
                    return
                }

                recipes = scannedRecipes + recipes
                attachRecipeIdsToUncategorized(scannedRecipes.map(\.id))
                shouldNavigateToCookbooks = uncategorizedCookbookId
                selectedImages = []

                usageTracker.recordRecipeGeneration()
                GenerationCreditsManager.shared.consumeGenerationCredit()
                AppAnalytics.log(.cookbookRecipesScanned, parameters: [
                    "recipe_count": scannedRecipes.count,
                    "image_count": imageURLs.count
                ])

                let preloadURLs = scannedRecipes.compactMap(\.imageURL)
                ImagePreloadService.shared.preloadImages(for: preloadURLs)

                let recipeIdsNeedingImages = scannedRecipes
                    .filter { $0.imageURL == nil }
                    .map(\.id)
                if !recipeIdsNeedingImages.isEmpty {
                    Task {
                        await generateImagesForRecipesInBackground(recipeIds: recipeIdsNeedingImages)
                    }
                }
            }
        } catch let error as APIError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                print("❌ Error in scanCookbookRecipesFromSelectedImages: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to scan cookbook recipes. Please try again."
                print("❌ Unexpected error in scanCookbookRecipesFromSelectedImages: \(error)")
            }
        }
    }

    func isValidWebRecipeURL(_ rawURL: String) -> Bool {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }
        return true
    }

    /// Scans recipes from a webpage URL and adds parsed recipes to the Recipes tab list.
    func scanRecipesFromWebPage(urlString: String) async {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidWebRecipeURL(trimmedURL) else {
            await MainActor.run {
                errorMessage = "Please enter a valid webpage URL starting with http:// or https://."
            }
            return
        }

        let canGenerate = await MainActor.run {
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
            if GenerationCreditsManager.shared.canConsumeGenerationCredit() {
                return true
            }
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
            return false
        }
        guard canGenerate else { return }

        await MainActor.run {
            isScanningWebRecipes = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isScanningWebRecipes = false
            }
        }

        do {
            let scannedRecipes = try await apiService.scanRecipesFromWebURL(urlString: trimmedURL)
            await MainActor.run {
                if scannedRecipes.isEmpty {
                    showNoRecipesAlert = true
                    return
                }

                recipes = scannedRecipes + recipes
                attachRecipeIdsToUncategorized(scannedRecipes.map(\.id))
                shouldNavigateToCookbooks = uncategorizedCookbookId

                usageTracker.recordRecipeGeneration()
                GenerationCreditsManager.shared.consumeGenerationCredit()
                AppAnalytics.log(.webRecipesScanned, parameters: [
                    "recipe_count": scannedRecipes.count
                ])

                let preloadURLs = scannedRecipes.compactMap(\.imageURL)
                ImagePreloadService.shared.preloadImages(for: preloadURLs)

                let recipeIdsNeedingImages = scannedRecipes
                    .filter { $0.imageURL == nil }
                    .map(\.id)
                if !recipeIdsNeedingImages.isEmpty {
                    Task {
                        await generateImagesForRecipesInBackground(recipeIds: recipeIdsNeedingImages)
                    }
                }
            }
        } catch let error as APIError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                print("❌ Error in scanRecipesFromWebPage: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to scan recipes from URL. Please try again."
                print("❌ Unexpected error in scanRecipesFromWebPage: \(error)")
            }
        }
    }
    
    /// Generates recipes from current ingredients
    func generateRecipes(prompt: String? = nil, strictness: MealPlanStrictness? = nil) async {
        guard !ingredients.isEmpty else { return }
        
        // Validate prompt length if provided
        if let prompt = prompt, !prompt.isEmpty {
            guard prompt.count <= AppConfig.maxGeneratePromptLength else {
                await MainActor.run {
                    errorMessage = ValidationError.generatePromptTooLong(maxLength: AppConfig.maxGeneratePromptLength).localizedDescription
                }
                return
            }
        }
        
        let canGenerate = await MainActor.run {
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
            if GenerationCreditsManager.shared.canConsumeGenerationCredit() {
                return true
            }
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
            return false
        }
        
        guard canGenerate else { return }
        
        await MainActor.run {
            isGeneratingRecipes = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isGeneratingRecipes = false
            }
        }
        
        do {
            var generatedRecipes = try await apiService.generateRecipes(
                ingredients: ingredients,
                prompt: prompt,
                strictness: strictness
            )
            await MainActor.run {
                if generatedRecipes.isEmpty {
                    showNoRecipesAlert = true
                } else {
                    // Add new recipes to the front of the existing list
                    recipes = generatedRecipes + recipes
                    print("📝 Added \(generatedRecipes.count) new recipes to the front (total: \(recipes.count), favorited recipes preserved separately: \(favoritedRecipes.count))")
                    
                    attachRecipeIdsToUncategorized(generatedRecipes.map(\.id))
                    shouldNavigateToCookbooks = uncategorizedCookbookId
                    
                    // Record usage after successful generation
                    usageTracker.recordRecipeGeneration()
                    GenerationCreditsManager.shared.consumeGenerationCredit()
                    
                    // Log analytics event
                    var genParams: [String: Any] = [
                        "recipe_count": generatedRecipes.count,
                        "ingredient_count": ingredients.count,
                        "has_prompt": prompt != nil && !prompt!.isEmpty
                    ]
                    if let strictness {
                        genParams["strictness"] = strictness.rawValue
                    }
                    AppAnalytics.log(.recipesGenerated, parameters: genParams)
                    
                    // Preload all recipe images in background
                    let imageURLs = generatedRecipes.compactMap { $0.imageURL }
                    ImagePreloadService.shared.preloadImages(for: imageURLs)

                    // Generate images for all newly generated recipes that still need one.
                    let recipeIdsNeedingImages = generatedRecipes
                        .filter { $0.imageURL == nil }
                        .map(\.id)

                    if recipeIdsNeedingImages.isEmpty {
                        print("⚠️ No generated recipes need image generation")
                    } else {
                        Task {
                            await generateImagesForRecipesInBackground(recipeIds: recipeIdsNeedingImages)
                        }
                    }
                }
            }
        } catch let error as APIError {
            await MainActor.run {
                // Use the user-friendly error message from APIError
                self.errorMessage = error.localizedDescription
                print("❌ Error in generateRecipes: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to generate recipes. Please try again."
                print("❌ Unexpected error in generateRecipes: \(error)")
            }
        }
    }

    /// Calls meal-plan API, adds recipes to Uncategorized, assigns recipes to selected plan slots in order, consumes credits (up to remaining).
    func generateMealPlanFromSheet(_ payload: MealPlanGenerationSheetPayload) async {
        guard !ingredients.isEmpty else {
            await MainActor.run {
                errorMessage = "Add ingredients to your pantry before generating a meal plan."
            }
            return
        }
        guard !payload.orderedSelectedSlots.isEmpty else { return }

        if let prompt = payload.prompt, !prompt.isEmpty {
            guard prompt.count <= AppConfig.maxGeneratePromptLength else {
                await MainActor.run {
                    errorMessage = ValidationError.generatePromptTooLong(maxLength: AppConfig.maxGeneratePromptLength).localizedDescription
                }
                return
            }
        }

        let canGenerate = await MainActor.run {
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
            if GenerationCreditsManager.shared.canConsumeGenerationCredit() {
                return true
            }
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
            return false
        }
        guard canGenerate else { return }

        await MainActor.run {
            isGeneratingRecipes = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isGeneratingRecipes = false
            }
        }

        do {
            let mealPlanRequest = MealPlanRequest(
                ingredients: ingredients,
                prompt: payload.prompt,
                strictness: payload.strictness,
                counts: payload.mealTypeCounts
            )
            let result = try await apiService.generateMealPlan(mealPlanRequest)
            let allRecipes = result.allRecipes

            await MainActor.run {
                if allRecipes.isEmpty {
                    showNoRecipesAlert = true
                    return
                }

                recipes = allRecipes + recipes
                attachRecipeIdsToUncategorized(allRecipes.map(\.id))
                applyMealPlanResponse(result, to: payload.orderedSelectedSlots)

                GenerationCreditsManager.shared.consumeGenerationCredits(upTo: allRecipes.count)
                usageTracker.recordRecipeGenerations(allRecipes.count)

                AppAnalytics.log(.mealPlanGenerated, parameters: [
                    "recipe_count": allRecipes.count,
                    "slot_count": payload.orderedSelectedSlots.count,
                    "ingredient_count": ingredients.count,
                    "has_prompt": payload.prompt.map { !$0.isEmpty } ?? false,
                    "strictness": payload.strictness.rawValue
                ])

                let imageURLs = allRecipes.compactMap(\.imageURL)
                ImagePreloadService.shared.preloadImages(for: imageURLs)

                let recipeIdsNeedingImages = allRecipes.filter { $0.imageURL == nil }.map(\.id)
                if !recipeIdsNeedingImages.isEmpty {
                    Task {
                        await generateImagesForRecipesInBackground(recipeIds: recipeIdsNeedingImages)
                    }
                }
            }
        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                print("❌ Meal plan API error: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to generate meal plan. Please try again."
                print("❌ Unexpected meal plan error: \(error)")
            }
        }
    }

    /// Pops recipes from each meal-type bucket in response order and assigns to the given slots (same order as the request `counts`).
    private func applyMealPlanResponse(_ result: MealPlanResult, to orderedSlots: [MealPlanSlotSelection]) {
        var breakfastQ = result.breakfast
        var lunchQ = result.lunch
        var snackQ = result.snack
        var dinnerQ = result.dinner
        var dessertQ = result.dessert

        func popRecipe(for slot: MealPlanSlot) -> Recipe? {
            switch slot {
            case .breakfast:
                return breakfastQ.isEmpty ? nil : breakfastQ.removeFirst()
            case .lunch:
                return lunchQ.isEmpty ? nil : lunchQ.removeFirst()
            case .snack:
                return snackQ.isEmpty ? nil : snackQ.removeFirst()
            case .dinner:
                return dinnerQ.isEmpty ? nil : dinnerQ.removeFirst()
            case .dessert:
                return dessertQ.isEmpty ? nil : dessertQ.removeFirst()
            }
        }

        var next = mealPlanByDay
        for selection in orderedSlots {
            guard let recipe = popRecipe(for: selection.slot) else { continue }
            var dayPlan = next[selection.dayKey] ?? SavedDayMealPlan()
            dayPlan.setRecipe(recipe.id, for: selection.slot)
            next[selection.dayKey] = dayPlan
        }
        mealPlanByDay = next
        shouldNavigateToPlan = true
        scheduleMealPlanCalendarReconcile()
    }
    
    /// Handles a deep link to a specific recipe.
    /// Expected format: reciplease://recipe/{backendIdString}
    func handleRecipeDeepLink(idString: String) async {
        let backendId = idString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔗 [DeepLink] handleRecipeDeepLink called with backendId='\(backendId)' (raw idString='\(idString)')")
        
        await MainActor.run {
            // Clear any previous error so stale alerts don't show when we open
            // a successfully-fetched deep link recipe.
            self.errorMessage = nil
        }
        
        guard !backendId.isEmpty else {
            print("❌ [DeepLink] backendId is empty after trimming")
            await MainActor.run {
                self.errorMessage = "We couldn't understand that recipe link."
            }
            return
        }
        
        do {
            print("🌐 [DeepLink] Calling UserService.fetchRecipe for backendId='\(backendId)'")
            let fetched = try await UserService.shared.fetchRecipe(id: backendId)
            print("✅ [DeepLink] Fetched recipe from API: \(fetched.name) (local id: \(fetched.id))")
            
            await MainActor.run {
                // Try to find an existing recipe that matches this one (by name + description)
                // so we don't keep inserting duplicates every time the deep link is opened.
                let recipeIdToOpen: UUID
                if let existingIndex = self.recipes.firstIndex(where: {
                    $0.name == fetched.name && $0.description == fetched.description
                }) {
                    let existing = self.recipes[existingIndex]
                    let updated = Recipe(
                        id: existing.id,
                        name: fetched.name,
                        description: fetched.description,
                        ingredients: fetched.ingredients,
                        steps: fetched.steps,
                        prepTimeMinutes: fetched.prepTimeMinutes,
                        cookTimeMinutes: fetched.cookTimeMinutes,
                        servings: fetched.servings,
                        difficulty: fetched.difficulty,
                        imageURL: fetched.imageURL,
                        isGeneratingImage: existing.isGeneratingImage,
                        tips: fetched.tips,
                        source: fetched.source
                    )
                    self.recipes[existingIndex] = updated
                    print("📚 [DeepLink] Updated existing recipe at index \(existingIndex) (id: \(existing.id))")
                    recipeIdToOpen = existing.id
                } else {
                    // Insert as a brand new recipe at the front of the list.
                    self.recipes.insert(fetched, at: 0)
                    print("📚 [DeepLink] Inserted fetched recipe at index 0 (total recipes: \(self.recipes.count))")
                    recipeIdToOpen = fetched.id
                }

                self.attachRecipeIdsToUncategorized([recipeIdToOpen])
                self.deepLinkedRecipeIdToOpen = recipeIdToOpen
                self.shouldNavigateToCookbooks = self.uncategorizedCookbookId
                print("💾 [DeepLink] Saved after attaching recipe to Uncategorized")
                print("🧭 [DeepLink] deepLinkedRecipeIdToOpen=\(recipeIdToOpen.uuidString), shouldNavigateToCookbooks=\(self.uncategorizedCookbookId?.uuidString ?? "nil")")
            }
        } catch let error as APIError {
            print("❌ [DeepLink] APIError while fetching recipe: \(error.localizedDescription) (code=\(error.apiErrorCode ?? "none"))")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        } catch {
            print("❌ [DeepLink] Unexpected error while fetching recipe: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to open recipe. Please try again."
            }
        }
    }
    
    /// Generates an image for a recipe
    func generateRecipeImage(recipeId: UUID) async {
        await generateRecipeImage(recipeId: recipeId, shouldMarkLoadingState: true)
    }

    /// Generates an image for a recipe.
    private func generateRecipeImage(recipeId: UUID, shouldMarkLoadingState: Bool) async {
        print("🖼️ generateRecipeImage called for recipeId: \(recipeId)")
        
        // Recipe images are free for all users (no generation credits).
        // Find recipe in either list
        let recipe = recipes.first(where: { $0.id == recipeId }) ?? 
                     favoritedRecipes.first(where: { $0.id == recipeId })
        
        guard let recipeToUse = recipe else {
            print("❌ Recipe not found with id: \(recipeId)")
            return
        }
        
        print("📝 Recipe found: \(recipeToUse.name)")
        print("📝 Recipe has \(recipeToUse.ingredients.count) ingredients and \(recipeToUse.steps.count) steps")
        
        if shouldMarkLoadingState {
            await MainActor.run {
                // Mark recipe as generating image - update in both lists if it exists
                print("🔄 Setting isGeneratingImage = true for recipe: \(recipeToUse.name)")
                updateRecipeInBothLists(recipeId: recipeId) { recipe in
                    Recipe(
                        id: recipe.id,
                        name: recipe.name,
                        description: recipe.description,
                        ingredients: recipe.ingredients,
                        steps: recipe.steps,
                        prepTimeMinutes: recipe.prepTimeMinutes,
                        cookTimeMinutes: recipe.cookTimeMinutes,
                        servings: recipe.servings,
                        difficulty: recipe.difficulty,
                        imageURL: recipe.imageURL,
                        isGeneratingImage: true,
                        tips: recipe.tips,
                        source: recipe.source
                    )
                }
            }
        }
        
        do {
            print("🌐 Calling API to generate recipe image...")
            let imageURL = try await apiService.generateRecipeImage(recipe: recipeToUse)
            print("✅ Image generation successful!")
            print("🖼️ Image URL received: \(imageURL)")
            
            
            await MainActor.run {
                // Update recipe with image URL in both lists if it exists
                print("🔄 Updating recipe with image URL: \(imageURL)")
                updateRecipeInBothLists(recipeId: recipeId) { recipe in
                    Recipe(
                        id: recipe.id,
                        name: recipe.name,
                        description: recipe.description,
                        ingredients: recipe.ingredients,
                        steps: recipe.steps,
                        prepTimeMinutes: recipe.prepTimeMinutes,
                        cookTimeMinutes: recipe.cookTimeMinutes,
                        servings: recipe.servings,
                        difficulty: recipe.difficulty,
                        imageURL: imageURL,
                        isGeneratingImage: false,
                        tips: recipe.tips,
                        source: recipe.source
                    )
                }
                print("✅ Recipe updated with image URL. isGeneratingImage = false")
                
                // Record usage after successful generation
                usageTracker.recordImageGeneration()
            }
        } catch let error as APIError {
            await MainActor.run {
                // Remove generating flag on error - update in both lists if it exists
                updateRecipeInBothLists(recipeId: recipeId) { recipe in
                    Recipe(
                        id: recipe.id,
                        name: recipe.name,
                        description: recipe.description,
                        ingredients: recipe.ingredients,
                        steps: recipe.steps,
                        prepTimeMinutes: recipe.prepTimeMinutes,
                        cookTimeMinutes: recipe.cookTimeMinutes,
                        servings: recipe.servings,
                        difficulty: recipe.difficulty,
                        imageURL: recipe.imageURL,
                        isGeneratingImage: false,
                        tips: recipe.tips,
                        source: recipe.source
                    )
                }
                // Use user-friendly error message from APIError
                self.errorMessage = error.localizedDescription
                print("❌ Failed to generate recipe image: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                // Remove generating flag on error - update in both lists if it exists
                updateRecipeInBothLists(recipeId: recipeId) { recipe in
                    Recipe(
                        id: recipe.id,
                        name: recipe.name,
                        description: recipe.description,
                        ingredients: recipe.ingredients,
                        steps: recipe.steps,
                        prepTimeMinutes: recipe.prepTimeMinutes,
                        cookTimeMinutes: recipe.cookTimeMinutes,
                        servings: recipe.servings,
                        difficulty: recipe.difficulty,
                        imageURL: recipe.imageURL,
                        isGeneratingImage: false,
                        tips: recipe.tips,
                        source: recipe.source
                    )
                }
                self.errorMessage = "Failed to generate image. Please try again."
                print("❌ Unexpected error generating recipe image: \(error)")
            }
        }
    }
    
    /// Adds an image to the selection and uploads it immediately
    @MainActor
    func addImage(_ image: UIImage) {
        guard selectedImages.count < AppConfig.maxScanPhotos else {
            errorMessage = "Maximum of \(AppConfig.maxScanPhotos) photos allowed"
            return
        }
        
        // Scale down image if needed (max 2560px on longest side for high-quality computer vision)
        // This preserves quality for detecting small ingredients while reducing upload size
        let scaledImage = image.resized(to: 2560)
        
        // Create new ImageWithURL and add to array
        var imageWithURL = ImageWithURL(image: scaledImage, uploadedURL: nil, isUploading: true)
        let imageId = imageWithURL.id
        selectedImages.append(imageWithURL)
        
        // Upload the image asynchronously
        Task {
            do {
                let url = try await gcsService.uploadImage(scaledImage)
                await MainActor.run {
                    // Find and update the image with its URL
                    if let index = selectedImages.firstIndex(where: { $0.id == imageId }) {
                        var updated = selectedImages
                        updated[index] = updated[index].with(uploadedURL: url, isUploading: false)
                        selectedImages = updated
                    }
                    
                }
            } catch {
                await MainActor.run {
                    // Find and remove the image if upload failed
                    if let index = selectedImages.firstIndex(where: { $0.id == imageId }) {
                        selectedImages.remove(at: index)
                        // Use user-friendly error message, never expose technical details
                        if let apiError = error as? APIError {
                            errorMessage = apiError.localizedDescription
                        } else {
                            errorMessage = "Failed to upload image. Please try again."
                        }
                        print("❌ Image upload failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Removes an image from the selection
    @MainActor
    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        saveData() // Save after removing image
    }
    
    /// Removes an ingredient from the list
    @MainActor
    func removeIngredient(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
        pantryInsights = []
        saveData() // Save after removing ingredient
    }
    
    /// Clears all ingredients from the pantry
    @MainActor
    func clearAllIngredients() {
        ingredients = []
        pantryInsights = []
        saveData()
    }

    /// Replaces the entire pantry (e.g. first-run onboarding). Clears insights; respects `AppConfig.maxIngredients`.
    @MainActor
    func replacePantryIngredients(generalNameQuantityPairs: [(generalName: String, specificName: String?, quantity: String)]) {
        var next: [Ingredient] = []
        next.reserveCapacity(min(generalNameQuantityPairs.count, AppConfig.maxIngredients))
        for item in generalNameQuantityPairs.prefix(AppConfig.maxIngredients) {
            var ing = Ingredient(
                generalName: item.generalName,
                specificName: item.specificName,
                quantity: item.quantity
            )
            ing.capitalizeName()
            next.append(ing)
        }
        ingredients = next
        pantryInsights = []
        saveData()
    }
    
    /// Fetches pantry insights in the background for the current ingredients
    func fetchPantryInsights() {
        Task { @MainActor in
            let currentIngredients = ingredients
            guard !currentIngredients.isEmpty else { return }
            guard !isLoadingInsights else { return }

            isLoadingInsights = true
            defer { isLoadingInsights = false }

            do {
                pantryInsights = try await RecipeAPIService.shared.fetchInsights(ingredients: currentIngredients)
            } catch {
                print("⚠️ Failed to fetch pantry insights: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates an existing ingredient
    @MainActor
    func updateIngredient(_ ingredient: Ingredient, generalName: String, specificName: String?, quantity: String) throws {
        // Validate name lengths
        guard generalName.count <= AppConfig.maxIngredientNameLength else {
            throw ValidationError.ingredientNameTooLong(maxLength: AppConfig.maxIngredientNameLength)
        }
        if let specificName = specificName, !specificName.isEmpty {
            guard specificName.count <= AppConfig.maxIngredientNameLength else {
                throw ValidationError.ingredientNameTooLong(maxLength: AppConfig.maxIngredientNameLength)
            }
        }
        
        if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients[index].generalName = generalName.capitalized
            ingredients[index].specificName = specificName?.isEmpty == false ? specificName?.capitalized : nil
            ingredients[index].quantity = quantity
            pantryInsights = []
            saveData() // Save after updating ingredient
        }
    }
    
    /// Adds a new ingredient manually
    @MainActor
    func addIngredient(generalName: String, specificName: String?, quantity: String) throws {
        // Validate ingredient count limit
        guard ingredients.count < AppConfig.maxIngredients else {
            throw ValidationError.maxIngredientsReached(maxCount: AppConfig.maxIngredients)
        }
        
        // Validate name lengths
        guard generalName.count <= AppConfig.maxIngredientNameLength else {
            throw ValidationError.ingredientNameTooLong(maxLength: AppConfig.maxIngredientNameLength)
        }
        if let specificName = specificName, !specificName.isEmpty {
            guard specificName.count <= AppConfig.maxIngredientNameLength else {
                throw ValidationError.ingredientNameTooLong(maxLength: AppConfig.maxIngredientNameLength)
            }
        }
        
        var newIngredient = Ingredient(
            generalName: generalName,
            specificName: specificName,
            quantity: quantity
        )
        newIngredient.capitalizeName()
        ingredients.append(newIngredient)
        pantryInsights = []
        saveData() // Save after adding ingredient
        
        AppAnalytics.log(.ingredientManuallyAdded, parameters: nil)
    }
    
    /// Modifies a recipe based on user prompt
    func modifyRecipe(recipeId: UUID, prompt: String) async {
        // Validate prompt length
        guard prompt.count <= AppConfig.maxModifyPromptLength else {
            await MainActor.run {
                errorMessage = ValidationError.modifyPromptTooLong(maxLength: AppConfig.maxModifyPromptLength).localizedDescription
            }
            return
        }
        
        // Recipe modification requires an active Pro subscription.
        let canModify = await MainActor.run {
            if !usageTracker.canModifyRecipe() {
                usageTracker.shouldShowPaywall = true
                AppAnalytics.log(.paywallTriggered, parameters: [
                    "reason": "modify_pro_required",
                    "tier": "free"
                ])
                return false
            }
            return true
        }
        
        guard canModify else { return }
        
        // Find recipe in either list
        let recipe = recipes.first(where: { $0.id == recipeId }) ?? 
                     favoritedRecipes.first(where: { $0.id == recipeId })
        
        guard let recipeToModify = recipe else {
            await MainActor.run {
                errorMessage = "Recipe not found"
            }
            return
        }
        
        await MainActor.run {
            isModifyingRecipe = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isModifyingRecipe = false
            }
        }
        
        do {
            var modifiedRecipe = try await apiService.modifyRecipe(recipe: recipeToModify, prompt: prompt)
            // Preserve the original recipe ID and image URL
            modifiedRecipe = Recipe(
                id: recipeId,
                name: modifiedRecipe.name,
                description: modifiedRecipe.description,
                ingredients: modifiedRecipe.ingredients,
                steps: modifiedRecipe.steps,
                prepTimeMinutes: modifiedRecipe.prepTimeMinutes,
                cookTimeMinutes: modifiedRecipe.cookTimeMinutes,
                servings: modifiedRecipe.servings,
                difficulty: modifiedRecipe.difficulty,
                imageURL: recipeToModify.imageURL, // Preserve existing image URL
                isGeneratingImage: false,
                tips: modifiedRecipe.tips,
                source: modifiedRecipe.source
            )
            await MainActor.run {
                // Update in both lists if it exists
                updateRecipeInBothLists(recipeId: recipeId) { _ in
                    modifiedRecipe
                }
                
                // Record usage after successful modification
                usageTracker.recordModification()
                
                AppAnalytics.log(.recipeModified, parameters: [
                    "recipe_name": modifiedRecipe.name,
                    "prompt_length": prompt.count
                ])
            }
        } catch let error as APIError {
            await MainActor.run {
                // Use the user-friendly error message from APIError
                self.errorMessage = error.localizedDescription
                print("❌ Error in modifyRecipe: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to modify recipe. Please try again."
                print("❌ Unexpected error in modifyRecipe: \(error)")
            }
        }
    }
    
    /// Clears all data (for testing or reset)
    @MainActor
    func clearAll() {
        pantryMatchRecalculationTask?.cancel()
        selectedImages = []
        ingredients = []
        pantryInsights = []
        recipes = []
        favoritedRecipes = []
        favoriteRecipeIds = []
        cookbooks = []
        pantryMatchScores = [:]
        errorMessage = nil
        saveData() // Save after clearing
        persistenceService.clear() // Also clear the saved file
        persistenceService.clearPantryMatchScores()
        UserDefaults.standard.removeObject(forKey: cookbookMigrationFlagKey)
    }
    
    /// Checks if all images have finished uploading
    var allImagesUploaded: Bool {
        !selectedImages.isEmpty && selectedImages.allSatisfy { !$0.isUploading && $0.uploadedURL != nil }
    }
    
    // MARK: - Persistence
    
    private func resetLoadingState(_ recipe: Recipe) -> Recipe {
        Recipe(
            id: recipe.id,
            name: recipe.name,
            description: recipe.description,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            prepTimeMinutes: recipe.prepTimeMinutes,
            cookTimeMinutes: recipe.cookTimeMinutes,
            servings: recipe.servings,
            difficulty: recipe.difficulty,
            imageURL: recipe.imageURL,
            isGeneratingImage: false,
            tips: recipe.tips,
            source: recipe.source
        )
    }

    /// Uncategorized first, then Favorites, then user cookbooks by `createdAt`. Any extra rows append at the end.
    private func normalizedCookbookDisplayOrder(_ books: [Cookbook]) -> [Cookbook] {
        let unc = books.first(where: { $0.isDefaultUncategorized })
        let fav = books.first(where: { $0.isDefaultFavorites })
        var rest = books.filter { !$0.isDefaultFavorites && !$0.isDefaultUncategorized }
        rest.sort { $0.createdAt < $1.createdAt }
        var ordered: [Cookbook] = []
        if let u = unc { ordered.append(u) }
        if let f = fav { ordered.append(f) }
        ordered.append(contentsOf: rest)
        for b in books where !ordered.contains(where: { $0.id == b.id }) {
            ordered.append(b)
        }
        return ordered
    }

    /// Loads saved data from disk.
    private func loadData() {
        let savedData = persistenceService.load()
        pantryMatchScores = persistenceService.loadPantryMatchScores()
        ingredients = savedData.ingredients
        groceryItems = savedData.groceryItems

        // Existing legacy source-of-truth for bookmarks before cookbooks shipped.
        let legacyFavoritedRecipes: [Recipe]
        if !savedData.favoritedRecipes.isEmpty {
            legacyFavoritedRecipes = savedData.favoritedRecipes.map(resetLoadingState)
        } else if !savedData.favoriteRecipeIds.isEmpty {
            let savedRecipes = savedData.recipes.map(resetLoadingState)
            legacyFavoritedRecipes = savedRecipes.filter { savedData.favoriteRecipeIds.contains($0.id) }
        } else {
            legacyFavoritedRecipes = []
        }

        var nextCookbooks = savedData.cookbooks.map {
            Cookbook(
                id: $0.id,
                name: $0.name,
                recipeIds: $0.recipeIds,
                createdAt: $0.createdAt,
                isDefaultFavorites: $0.isDefaultFavorites,
                isDefaultUncategorized: $0.isDefaultUncategorized
            )
        }
        let migrationPreviouslyCompleted = UserDefaults.standard.bool(forKey: cookbookMigrationFlagKey)
        var migrationChangedData = false

        for i in nextCookbooks.indices {
            if !nextCookbooks[i].isDefaultFavorites,
               nextCookbooks[i].name.caseInsensitiveCompare("Uncategorized") == .orderedSame {
                nextCookbooks[i].isDefaultUncategorized = true
                migrationChangedData = true
            }
        }

        if nextCookbooks.isEmpty {
            nextCookbooks = [
                Cookbook(
                    id: UUID(),
                    name: "Uncategorized",
                    recipeIds: [],
                    createdAt: Date(),
                    isDefaultFavorites: false,
                    isDefaultUncategorized: true
                ),
                Cookbook(
                    id: UUID(),
                    name: "Favorites",
                    recipeIds: [],
                    createdAt: Date(),
                    isDefaultFavorites: true,
                    isDefaultUncategorized: false
                )
            ]
            migrationChangedData = true
        }

        if !nextCookbooks.contains(where: { $0.isDefaultFavorites }) {
            nextCookbooks.insert(
                Cookbook(
                    id: UUID(),
                    name: "Favorites",
                    recipeIds: [],
                    createdAt: Date(),
                    isDefaultFavorites: true,
                    isDefaultUncategorized: false
                ),
                at: 0
            )
            migrationChangedData = true
        }

        if !nextCookbooks.contains(where: { $0.isDefaultUncategorized }) {
            nextCookbooks.insert(
                Cookbook(
                    id: UUID(),
                    name: "Uncategorized",
                    recipeIds: [],
                    createdAt: Date(),
                    isDefaultFavorites: false,
                    isDefaultUncategorized: true
                ),
                at: 0
            )
            migrationChangedData = true
        }

        nextCookbooks = normalizedCookbookDisplayOrder(nextCookbooks)

        if !migrationPreviouslyCompleted {
            let legacyFavoriteIds = Set(legacyFavoritedRecipes.map(\.id) + savedData.favoriteRecipeIds)
            if let defaultIndex = nextCookbooks.firstIndex(where: { $0.isDefaultFavorites }) {
                for recipeId in legacyFavoriteIds {
                    if !nextCookbooks[defaultIndex].recipeIds.contains(recipeId) {
                        nextCookbooks[defaultIndex].recipeIds.append(recipeId)
                        migrationChangedData = true
                    }
                }
            }
        }

        let persistedRecipeIds = savedData.recipes.map(\.id)
        var idsInAnyCookbook = Set(nextCookbooks.flatMap(\.recipeIds))
        if let uncIdx = nextCookbooks.firstIndex(where: { $0.isDefaultUncategorized }) {
            for rid in persistedRecipeIds where !idsInAnyCookbook.contains(rid) {
                if !nextCookbooks[uncIdx].recipeIds.contains(rid) {
                    nextCookbooks[uncIdx].recipeIds.append(rid)
                    migrationChangedData = true
                }
                idsInAnyCookbook.insert(rid)
            }
        }

        // Enforce single membership: first cookbook wins (Uncategorized, then Favorites, then user cookbooks).
        var seenIds = Set<UUID>()
        for index in nextCookbooks.indices {
            let original = nextCookbooks[index].recipeIds
            nextCookbooks[index].recipeIds = original.filter { recipeId in
                guard !seenIds.contains(recipeId) else { return false }
                seenIds.insert(recipeId)
                return true
            }
            if nextCookbooks[index].recipeIds != original {
                migrationChangedData = true
            }
        }

        cookbooks = nextCookbooks

        selectedImages = savedData.imageURLs.map { savedImage in
            ImageWithURL(
                id: savedImage.id,
                image: UIImage(),
                uploadedURL: savedImage.uploadedURL,
                isUploading: false
            )
        }

        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        let recipeMap = makeRecipeLookup((savedData.recipes + savedData.favoritedRecipes).map(resetLoadingState))
        favoritedRecipes = favoriteRecipeIds.compactMap { recipeMap[$0] }

        let favoritedIdSet = Set(favoriteRecipeIds)
        recipes = savedData.recipes.map(resetLoadingState).filter { !favoritedIdSet.contains($0.id) }
        trimRecipesTabToLimitIfNeeded()
        pantryInsights = savedData.pantryInsights

        let validMealPlanRecipeIds = Set(recipes.map(\.id) + favoritedRecipes.map(\.id))
        mealPlanByDay = Self.pruneMealPlan(savedData.mealPlanByDay, validRecipeIds: validMealPlanRecipeIds)
        mealPlanCalendarEventIdsByDay = savedData.mealPlanCalendarEventIdsByDay

        if migrationChangedData {
            saveData()
            UserDefaults.standard.set(true, forKey: cookbookMigrationFlagKey)
        }

        schedulePantryMatchScoreRecalculation()

        if pantryInsights.isEmpty, !ingredients.isEmpty {
            fetchPantryInsights()
        }

        print("📂 Loaded \(ingredients.count) ingredients, \(recipes.count) generated recipes, \(favoritedRecipes.count) bookmarked recipes, \(cookbooks.count) cookbooks, \(selectedImages.count) image URLs, \(pantryInsights.count) pantry insights")

        scheduleMealPlanCalendarReconcile()
    }
    
    /// Drops oldest entries from the Recipes tab list when over `maxRecipesInRecipesTab` (newest at front). Does not modify cookbooks / `favoritedRecipes`.
    private func trimRecipesTabToLimitIfNeeded() {
        guard recipes.count > maxRecipesInRecipesTab else { return }
        let removed = recipes.count - maxRecipesInRecipesTab
        recipes = Array(recipes.prefix(maxRecipesInRecipesTab))
        print("📝 Recipes tab capped at \(maxRecipesInRecipesTab) (removed \(removed) oldest); cookbooks unchanged")
    }
    
    /// Saves all data to disk
    private func saveData() {
        trimRecipesTabToLimitIfNeeded()
        cookbooks = normalizedCookbookDisplayOrder(cookbooks)

        // Convert ImageWithURL to SavedImageData (only URLs, not UIImage)
        let imageURLs = selectedImages.map { imageWithURL in
            SavedImageData(id: imageWithURL.id, uploadedURL: imageWithURL.uploadedURL)
        }
        
        // Keep compatibility favorites arrays in sync with cookbook membership.
        favoriteRecipeIds = Array(Set(cookbooks.flatMap(\.recipeIds)))
        let lookup = makeRecipeLookup(recipes + favoritedRecipes)
        favoritedRecipes = favoriteRecipeIds.compactMap { lookup[$0] }
        let cookbooksToSave = cookbooks.map {
            SavedCookbook(
                id: $0.id,
                name: $0.name,
                recipeIds: $0.recipeIds,
                createdAt: $0.createdAt,
                isDefaultFavorites: $0.isDefaultFavorites,
                isDefaultUncategorized: $0.isDefaultUncategorized
            )
        }
        
        let validIds = Set((recipes + favoritedRecipes).map(\.id))
        let planToSave = Self.pruneMealPlan(mealPlanByDay, validRecipeIds: validIds)
        var mealPlanWasPruned = false
        if planToSave != mealPlanByDay {
            mealPlanByDay = planToSave
            mealPlanWasPruned = true
        }

        // Save recipes (generated recipes are now persisted)
        persistenceService.save(
            imageURLs: imageURLs,
            ingredients: ingredients,
            recipes: recipes,
            favoritedRecipes: favoritedRecipes,
            favoriteRecipeIds: favoriteRecipeIds,
            cookbooks: cookbooksToSave,
            pantryInsights: pantryInsights,
            mealPlanByDay: mealPlanByDay,
            mealPlanCalendarEventIdsByDay: mealPlanCalendarEventIdsByDay,
            groceryItems: groceryItems
        )

        if mealPlanWasPruned {
            scheduleMealPlanCalendarReconcile()
        }
    }

    private func scheduleMealPlanCalendarReconcile() {
        Task { @MainActor in
            await performMealPlanCalendarReconcile()
        }
    }

    @MainActor
    private func performMealPlanCalendarReconcile() async {
        guard MealPlanCalendarService.shared.hasFullCalendarAccess else { return }
        var bindings = mealPlanCalendarEventIdsByDay
        await MealPlanCalendarService.shared.reconcile(
            mealPlanByDay: mealPlanByDay,
            recipeLookup: makeRecipeLookup(recipes + favoritedRecipes),
            bindings: &bindings
        )
        if bindings != mealPlanCalendarEventIdsByDay {
            mealPlanCalendarEventIdsByDay = bindings
            saveData()
        }
    }

    /// After the user grants Calendar access from the Plan tab (or Settings), refresh Calendar to match the meal plan.
    func syncMealPlanToSystemCalendarIfNeeded() {
        scheduleMealPlanCalendarReconcile()
    }
    
    /// Sets up automatic saving when data changes
    private func setupAutoSave() {
        // Save when ingredients change
        $ingredients
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        
        // Save when recipes change
        $recipes
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        
        // Save when selectedImages change
        $selectedImages
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        
        // Save when pantry insights change
        $pantryInsights
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)

        // Recompute pantry match scores in the background whenever pantry/recipe state changes.
        Publishers.CombineLatest3($ingredients, $recipes, $favoritedRecipes)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.schedulePantryMatchScoreRecalculation()
            }
            .store(in: &cancellables)

        $mealPlanByDay
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)

        $groceryItems
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Grocery list

    /// Unchecked first, then checked — matches the Grocery tab list order.
    static func sortedGroceryItemsForExport(_ items: [GroceryListItem]) -> [GroceryListItem] {
        let unchecked = items.filter { !$0.isChecked }.sorted { $0.createdAt < $1.createdAt }
        let checked = items.filter(\.isChecked).sorted { $0.createdAt < $1.createdAt }
        return unchecked + checked
    }

    /// Plain text for sharing (☐ / ☑ lines); same format as the Grocery tab Export pill.
    static func formattedGroceryListExportString(from items: [GroceryListItem]) -> String {
        var lines: [String] = ["Grocery list", ""]
        for item in sortedGroceryItemsForExport(items) {
            let qty = item.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            let mark = item.isChecked ? "☑ " : "□ "
            if qty.isEmpty {
                lines.append("\(mark)\(item.name)")
            } else {
                lines.append("\(mark)\(item.name) — \(qty)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func formattedGroceryListForExport() -> String {
        Self.formattedGroceryListExportString(from: groceryItems)
    }

    func addGroceryItem(name: String, quantity: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let q = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = trimmedName.lowercased()

        if let index = groceryItems.firstIndex(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == norm
        }) {
            guard let merged = Self.mergeGroceryQuantityStrings(
                existing: groceryItems[index].quantity,
                adding: q
            ) else { return }
            groceryItems[index].quantity = String(merged.prefix(AppConfig.maxIngredientNameLength))
            return
        }

        guard groceryItems.count < AppConfig.maxIngredients else {
            errorMessage = "Your grocery list can’t hold more than \(AppConfig.maxIngredients) items."
            return
        }
        let cappedName = String(trimmedName.prefix(AppConfig.maxIngredientNameLength))
        groceryItems.append(GroceryListItem(
            name: cappedName,
            quantity: String(q.prefix(AppConfig.maxIngredientNameLength))
        ))
    }

    func replaceGroceryItems(with pending: [(name: String, quantity: String)]) {
        groceryItems.removeAll()
        for item in pending {
            addGroceryItem(name: item.name, quantity: item.quantity)
        }
    }

    /// How many new rows would be created if `pending` were applied in order (merges do not consume a row).
    static func additionalGroceryRowsIfAppending(existing: [GroceryListItem], pending: [(name: String, quantity: String)]) -> Int {
        var norms = Set(existing.map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        var added = 0
        for item in pending {
            let n = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !n.isEmpty else { continue }
            if norms.contains(n) { continue }
            norms.insert(n)
            added += 1
        }
        return added
    }

    private static func mergeGroceryQuantityStrings(existing: String, adding: String) -> String? {
        let maxLen = AppConfig.maxIngredientNameLength
        let a = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = adding.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b.count <= maxLen ? b : nil }
        if b.isEmpty { return a.count <= maxLen ? a : nil }

        guard let pa = parseGroceryLeadingNumeric(a), let pb = parseGroceryLeadingNumeric(b) else {
            return b.count <= maxLen ? b : nil
        }

        let restA = pa.rest.trimmingCharacters(in: .whitespacesAndNewlines)
        let restB = pb.rest.trimmingCharacters(in: .whitespacesAndNewlines)

        if restA.isEmpty && restB.isEmpty {
            let sum = pa.value + pb.value
            let num = formatGroceryMergedScalar(sum)
            guard num.count <= maxLen else { return nil }
            return num
        }
        if restA.isEmpty || restB.isEmpty {
            return b.count <= maxLen ? b : nil
        }

        let (unitA, sufA) = splitGroceryRestIntoUnitAndSuffix(restA)
        let (unitB, sufB) = splitGroceryRestIntoUnitAndSuffix(restB)
        guard !unitA.isEmpty, !unitB.isEmpty else {
            return b.count <= maxLen ? b : nil
        }
        guard sufA.lowercased() == sufB.lowercased() else {
            return b.count <= maxLen ? b : nil
        }
        guard groceryUnitsAreCompatible(unitA, unitB) else {
            return b.count <= maxLen ? b : nil
        }

        let sum = pa.value + pb.value
        let num = formatGroceryMergedScalar(sum)
        let unitLabel = groceryMergedUnitLabel(sum: sum, unitA: unitA, unitB: unitB)
        let merged: String
        if sufB.isEmpty {
            merged = "\(num) \(unitLabel)"
        } else {
            merged = "\(num) \(unitLabel) \(sufB)"
        }
        guard merged.count <= maxLen else { return nil }
        return merged
    }

    /// First word = unit token; remainder = extra wording (must match between lines to merge).
    private static func splitGroceryRestIntoUnitAndSuffix(_ rest: String) -> (unit: String, suffix: String) {
        let t = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return ("", "") }
        let parts = t.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let u = String(parts[0])
        let s = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (u, s)
    }

    /// Maps common spellings/abbreviations to one key so "tablespoon" and "tablespoons" merge.
    private static let groceryUnitSynonymKeys: [String: String] = [
        "tbsp": "tbsp", "tbs": "tbsp", "tablespoon": "tbsp", "tablespoons": "tbsp",
        "tsp": "tsp", "teaspoon": "tsp", "teaspoons": "tsp",
        "cup": "cup", "cups": "cup",
        "oz": "oz", "ounce": "oz", "ounces": "oz",
        "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "g": "g", "gram": "g", "grams": "g",
        "kg": "kg", "kilogram": "kg", "kilograms": "kg",
        "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml",
        "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l",
        "clove": "clove", "cloves": "clove",
        "pinch": "pinch", "pinches": "pinch",
        "piece": "piece", "pieces": "piece",
        "slice": "slice", "slices": "slice",
        "can": "can", "cans": "can",
        "stalk": "stalk", "stalks": "stalk",
        "sprig": "sprig", "sprigs": "sprig",
        "bunch": "bunch", "bunches": "bunch",
        "head": "head", "heads": "head",
        "package": "package", "packages": "package", "pkg": "package",
        "stick": "stick", "sticks": "stick",
        "fillet": "fillet", "fillets": "fillet",
        "quart": "quart", "quarts": "quart",
        "pint": "pint", "pints": "pint",
        "gal": "gal", "gallon": "gal", "gallons": "gal",
    ]

    private static func groceryUnitsAreCompatible(_ unitA: String, _ unitB: String) -> Bool {
        let la = unitA.lowercased()
        let lb = unitB.lowercased()
        if la == lb { return true }
        let ka = groceryUnitSynonymKeys[la]
        let kb = groceryUnitSynonymKeys[lb]
        if let ka, let kb { return ka == kb }
        if ka != nil || kb != nil { return false }
        return groceryUnitsRoughPluralEqual(la, lb)
    }

    private static func groceryUnitsRoughPluralEqual(_ la: String, _ lb: String) -> Bool {
        if la == lb { return true }
        if la == lb + "s" || lb == la + "s" { return true }
        if la == lb + "es" || lb == la + "es" { return true }
        if la.hasSuffix("ies"), String(la.dropLast(3)) + "y" == lb { return true }
        if lb.hasSuffix("ies"), String(lb.dropLast(3)) + "y" == la { return true }
        return false
    }

    private static func groceryMergedUnitLabel(sum: Double, unitA: String, unitB: String) -> String {
        let la = unitA.lowercased()
        let lb = unitB.lowercased()
        let key = groceryUnitSynonymKeys[la] ?? groceryUnitSynonymKeys[lb] ?? la
        let plural = abs(sum - 1.0) > 1e-6
        switch key {
        case "tbsp":
            let abbrev = ["tbsp", "tbs"].contains(la) || ["tbsp", "tbs"].contains(lb)
            return abbrev ? "tbsp" : (plural ? "tablespoons" : "tablespoon")
        case "tsp":
            let abbrev = la == "tsp" || lb == "tsp"
            return abbrev ? "tsp" : (plural ? "teaspoons" : "teaspoon")
        case "cup":
            return plural ? "cups" : "cup"
        case "oz":
            let abbrev = la == "oz" || lb == "oz"
            return abbrev ? "oz" : (plural ? "ounces" : "ounce")
        case "lb":
            let abbrev = ["lb", "lbs"].contains(la) || ["lb", "lbs"].contains(lb)
            return abbrev ? (plural ? "lbs" : "lb") : (plural ? "pounds" : "pound")
        case "g":
            return plural ? "grams" : "gram"
        case "kg":
            return plural ? "kilograms" : "kilogram"
        case "ml":
            return plural ? "milliliters" : "milliliter"
        case "l":
            return plural ? "liters" : "liter"
        case "clove":
            return plural ? "cloves" : "clove"
        case "pinch":
            return plural ? "pinches" : "pinch"
        case "piece":
            return plural ? "pieces" : "piece"
        case "slice":
            return plural ? "slices" : "slice"
        case "can":
            return plural ? "cans" : "can"
        case "stalk":
            return plural ? "stalks" : "stalk"
        case "sprig":
            return plural ? "sprigs" : "sprig"
        case "bunch":
            return plural ? "bunches" : "bunch"
        case "head":
            return plural ? "heads" : "head"
        case "package":
            return plural ? "packages" : "package"
        case "stick":
            return plural ? "sticks" : "stick"
        case "fillet":
            return plural ? "fillets" : "fillet"
        case "quart":
            return plural ? "quarts" : "quart"
        case "pint":
            return plural ? "pints" : "pint"
        case "gal":
            return plural ? "gallons" : "gallon"
        default:
            return groceryPickUnknownUnitWord(sum: sum, a: unitA, b: unitB)
        }
    }

    private static func groceryPickUnknownUnitWord(sum: Double, a: String, b: String) -> String {
        let plural = abs(sum - 1.0) > 1e-6
        let la = a.lowercased()
        let lb = b.lowercased()
        if plural {
            if lb.hasSuffix("s") { return b }
            if la.hasSuffix("s") { return a }
            if lb.hasSuffix("ies") { return b }
            if la.hasSuffix("ies") { return a }
            let low = lb
            if low.hasSuffix("ch") || low.hasSuffix("sh") || low.hasSuffix("x") || low == "pinch" {
                return b + "es"
            }
            return b + "s"
        } else {
            if !lb.hasSuffix("s") { return b }
            if !la.hasSuffix("s") { return a }
            if b.lowercased().hasSuffix("ies"), b.count > 3 { return String(b.dropLast(3)) + "y" }
            if b.lowercased().hasSuffix("es"), b.count > 2 { return String(b.dropLast(2)) }
            if b.hasSuffix("s") { return String(b.dropLast()) }
            return b
        }
    }

    private static func parseGroceryLeadingNumeric(_ s: String) -> (value: Double, rest: String)? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else { return nil }
        let rest = parts.count > 1 ? String(parts[1]) : ""
        let token = String(first)
        let value: Double?
        if token.contains("/") {
            let bits = token.split(separator: "/")
            guard bits.count == 2,
                  let num = Double(bits[0]),
                  let den = Double(bits[1]),
                  den != 0 else {
                return nil
            }
            value = num / den
        } else {
            value = Double(token)
        }
        guard let v = value else { return nil }
        return (v, rest)
    }

    private static func formatGroceryMergedScalar(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        let towardZero = rounded.rounded(.towardZero)
        if abs(rounded - towardZero) < 0.0001 {
            return String(Int(towardZero))
        }
        var s = String(format: "%.2f", rounded)
        while s.contains(".") && (s.last == "0" || s.last == ".") {
            s.removeLast()
        }
        return s
    }

    func toggleGroceryItemChecked(id: UUID) {
        guard let index = groceryItems.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            groceryItems[index].isChecked.toggle()
        }
    }

    func removeGroceryItem(id: UUID) {
        groceryItems.removeAll { $0.id == id }
    }

    func updateGroceryItem(id: UUID, name: String, quantity: String) {
        guard let index = groceryItems.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        groceryItems[index].name = String(trimmedName.prefix(AppConfig.maxIngredientNameLength))
        groceryItems[index].quantity = String(quantity.prefix(AppConfig.maxIngredientNameLength))
    }

    func clearCheckedGroceryItems() {
        withAnimation(.easeInOut(duration: 0.22)) {
            groceryItems.removeAll { $0.isChecked }
        }
    }

    func checkAllGroceryItems() {
        guard !groceryItems.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            for index in groceryItems.indices {
                groceryItems[index].isChecked = true
            }
        }
    }

    func uncheckAllGroceryItems() {
        guard groceryItems.contains(where: \.isChecked) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            for index in groceryItems.indices {
                groceryItems[index].isChecked = false
            }
        }
    }
}
