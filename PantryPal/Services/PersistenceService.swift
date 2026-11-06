//
//  PersistenceService.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

// Codable struct for saving image URLs (without UIImage)
struct SavedImageData: Codable, Identifiable {
    let id: UUID
    let uploadedURL: String?
    
    init(id: UUID, uploadedURL: String?) {
        self.id = id
        self.uploadedURL = uploadedURL
    }
}

// Codable struct for storing cookbook membership
struct SavedCookbook: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var recipeIds: [UUID]
    let createdAt: Date
    var isDefaultFavorites: Bool
    /// System bucket for generated/imported recipes (not user-deletable as a concept; may be recreated).
    var isDefaultUncategorized: Bool
    /// Inbox for recipes migrated out of Uncategorized. Not a favorite and not a fresh session.
    var isInbox: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, recipeIds, createdAt, isDefaultFavorites, isDefaultUncategorized, isInbox
    }

    init(
        id: UUID,
        name: String,
        recipeIds: [UUID],
        createdAt: Date,
        isDefaultFavorites: Bool,
        isDefaultUncategorized: Bool = false,
        isInbox: Bool = false
    ) {
        self.id = id
        self.name = name
        self.recipeIds = recipeIds
        self.createdAt = createdAt
        self.isDefaultFavorites = isDefaultFavorites
        self.isDefaultUncategorized = isDefaultUncategorized
        self.isInbox = isInbox
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        recipeIds = try c.decodeIfPresent([UUID].self, forKey: .recipeIds) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isDefaultFavorites = try c.decodeIfPresent(Bool.self, forKey: .isDefaultFavorites) ?? false
        isDefaultUncategorized = try c.decodeIfPresent(Bool.self, forKey: .isDefaultUncategorized) ?? false
        isInbox = try c.decodeIfPresent(Bool.self, forKey: .isInbox) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(recipeIds, forKey: .recipeIds)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isDefaultFavorites, forKey: .isDefaultFavorites)
        try c.encode(isDefaultUncategorized, forKey: .isDefaultUncategorized)
        try c.encode(isInbox, forKey: .isInbox)
    }
}

/// Which meal slot on a given calendar day (Plan tab).
enum MealPlanSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case snack
    case dinner
    case dessert

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .snack: return "Snack"
        case .dinner: return "Dinner"
        case .dessert: return "Dessert"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .snack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        case .dessert: return "birthday.cake.fill"
        }
    }
}

/// Up to one recipe per meal slot for a single day (persisted).
struct SavedDayMealPlan: Codable, Hashable, Equatable {
    var breakfast: UUID?
    var lunch: UUID?
    var snack: UUID?
    var dinner: UUID?
    var dessert: UUID?

    init(
        breakfast: UUID? = nil,
        lunch: UUID? = nil,
        snack: UUID? = nil,
        dinner: UUID? = nil,
        dessert: UUID? = nil
    ) {
        self.breakfast = breakfast
        self.lunch = lunch
        self.snack = snack
        self.dinner = dinner
        self.dessert = dessert
    }

    func recipeId(for slot: MealPlanSlot) -> UUID? {
        switch slot {
        case .breakfast: return breakfast
        case .lunch: return lunch
        case .snack: return snack
        case .dinner: return dinner
        case .dessert: return dessert
        }
    }

    mutating func setRecipe(_ id: UUID?, for slot: MealPlanSlot) {
        switch slot {
        case .breakfast: breakfast = id
        case .lunch: lunch = id
        case .snack: snack = id
        case .dinner: dinner = id
        case .dessert: dessert = id
        }
    }
}

/// EventKit `EKEvent.eventIdentifier` per meal slot (Plan tab calendar sync).
struct SavedDayMealPlanCalendarIds: Codable, Hashable, Equatable {
    var breakfast: String?
    var lunch: String?
    var snack: String?
    var dinner: String?
    var dessert: String?

    init(
        breakfast: String? = nil,
        lunch: String? = nil,
        snack: String? = nil,
        dinner: String? = nil,
        dessert: String? = nil
    ) {
        self.breakfast = breakfast
        self.lunch = lunch
        self.snack = snack
        self.dinner = dinner
        self.dessert = dessert
    }

    func eventIdentifier(for slot: MealPlanSlot) -> String? {
        switch slot {
        case .breakfast: return breakfast
        case .lunch: return lunch
        case .snack: return snack
        case .dinner: return dinner
        case .dessert: return dessert
        }
    }

    mutating func setEventIdentifier(_ id: String?, for slot: MealPlanSlot) {
        switch slot {
        case .breakfast: breakfast = id
        case .lunch: lunch = id
        case .snack: snack = id
        case .dinner: dinner = id
        case .dessert: dessert = id
        }
    }

    var hasAnyIdentifier: Bool {
        breakfast != nil || lunch != nil || snack != nil || dinner != nil || dessert != nil
    }
}

// Container for all saved app data
struct SavedAppData: Codable {
    var imageURLs: [SavedImageData]
    var ingredients: [Ingredient]
    var recipes: [Recipe]
    var favoritedRecipes: [Recipe]
    var favoriteRecipeIds: [UUID]
    var cookbooks: [SavedCookbook]
    var pantryInsights: [String]
    /// Keys: `yyyy-MM-dd` in the user’s current calendar (start-of-day).
    var mealPlanByDay: [String: SavedDayMealPlan]
    /// Parallel map: EventKit event identifiers for synced meal plan events.
    var mealPlanCalendarEventIdsByDay: [String: SavedDayMealPlanCalendarIds]
    var groceryItems: [GroceryListItem]
    var generationSessions: [GenerationSession]

    init(
        imageURLs: [SavedImageData] = [],
        ingredients: [Ingredient] = [],
        recipes: [Recipe] = [],
        favoritedRecipes: [Recipe] = [],
        favoriteRecipeIds: [UUID] = [],
        cookbooks: [SavedCookbook] = [],
        pantryInsights: [String] = [],
        mealPlanByDay: [String: SavedDayMealPlan] = [:],
        mealPlanCalendarEventIdsByDay: [String: SavedDayMealPlanCalendarIds] = [:],
        groceryItems: [GroceryListItem] = [],
        generationSessions: [GenerationSession] = []
    ) {
        self.imageURLs = imageURLs
        self.ingredients = ingredients
        self.recipes = recipes
        self.favoritedRecipes = favoritedRecipes
        self.favoriteRecipeIds = favoriteRecipeIds
        self.cookbooks = cookbooks
        self.pantryInsights = pantryInsights
        self.mealPlanByDay = mealPlanByDay
        self.mealPlanCalendarEventIdsByDay = mealPlanCalendarEventIdsByDay
        self.groceryItems = groceryItems
        self.generationSessions = generationSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageURLs = try container.decodeIfPresent([SavedImageData].self, forKey: .imageURLs) ?? []
        ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
        recipes = try container.decodeIfPresent([Recipe].self, forKey: .recipes) ?? []
        favoritedRecipes = try container.decodeIfPresent([Recipe].self, forKey: .favoritedRecipes) ?? []
        favoriteRecipeIds = try container.decodeIfPresent([UUID].self, forKey: .favoriteRecipeIds) ?? []
        cookbooks = try container.decodeIfPresent([SavedCookbook].self, forKey: .cookbooks) ?? []
        pantryInsights = try container.decodeIfPresent([String].self, forKey: .pantryInsights) ?? []
        mealPlanByDay = try container.decodeIfPresent([String: SavedDayMealPlan].self, forKey: .mealPlanByDay) ?? [:]
        mealPlanCalendarEventIdsByDay = try container.decodeIfPresent([String: SavedDayMealPlanCalendarIds].self, forKey: .mealPlanCalendarEventIdsByDay) ?? [:]
        groceryItems = try container.decodeIfPresent([GroceryListItem].self, forKey: .groceryItems) ?? []
        generationSessions = try container.decodeIfPresent([GenerationSession].self, forKey: .generationSessions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imageURLs, forKey: .imageURLs)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(recipes, forKey: .recipes)
        try container.encode(favoritedRecipes, forKey: .favoritedRecipes)
        try container.encode(favoriteRecipeIds, forKey: .favoriteRecipeIds)
        try container.encode(cookbooks, forKey: .cookbooks)
        try container.encode(pantryInsights, forKey: .pantryInsights)
        try container.encode(mealPlanByDay, forKey: .mealPlanByDay)
        try container.encode(mealPlanCalendarEventIdsByDay, forKey: .mealPlanCalendarEventIdsByDay)
        try container.encode(groceryItems, forKey: .groceryItems)
        try container.encode(generationSessions, forKey: .generationSessions)
    }
}

class PersistenceService {
    static let shared = PersistenceService()
    
    private let fileName = "reciplease_data.json"
    private let pantryMatchScoresFileName = "pantry_match_scores.json"
    
    private init() {}
    
    /// Returns the URL for the saved data file
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    /// Returns the URL for persisted pantry match scores.
    private var pantryMatchScoresFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(pantryMatchScoresFileName)
    }
    
    /// Saves all app data to disk
    func save(
        imageURLs: [SavedImageData],
        ingredients: [Ingredient],
        recipes: [Recipe],
        favoritedRecipes: [Recipe] = [],
        favoriteRecipeIds: [UUID] = [],
        cookbooks: [SavedCookbook] = [],
        pantryInsights: [String] = [],
        mealPlanByDay: [String: SavedDayMealPlan] = [:],
        mealPlanCalendarEventIdsByDay: [String: SavedDayMealPlanCalendarIds] = [:],
        groceryItems: [GroceryListItem] = [],
        generationSessions: [GenerationSession] = []
    ) {
        let data = SavedAppData(
            imageURLs: imageURLs,
            ingredients: ingredients,
            recipes: recipes,
            favoritedRecipes: favoritedRecipes,
            favoriteRecipeIds: favoriteRecipeIds,
            cookbooks: cookbooks,
            pantryInsights: pantryInsights,
            mealPlanByDay: mealPlanByDay,
            mealPlanCalendarEventIdsByDay: mealPlanCalendarEventIdsByDay,
            groceryItems: groceryItems,
            generationSessions: generationSessions
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save app data: \(error.localizedDescription)")
        }
    }
    
    /// Loads all app data from disk
    func load() -> SavedAppData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📂 No saved data found, returning empty data")
            return SavedAppData()
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let savedData = try decoder.decode(SavedAppData.self, from: data)
            print("✅ Successfully loaded app data from: \(fileURL.path)")
            print("   - \(savedData.imageURLs.count) image URLs")
            print("   - \(savedData.ingredients.count) ingredients")
            print("   - \(savedData.recipes.count) recipes")
            print("   - \(savedData.favoritedRecipes.count) favorited recipes")
            print("   - \(savedData.favoriteRecipeIds.count) favorite recipe IDs")
            print("   - \(savedData.cookbooks.count) cookbooks")
            print("   - \(savedData.pantryInsights.count) pantry insights")
            return savedData
        } catch {
            print("❌ Failed to load app data: \(error.localizedDescription)")
            return SavedAppData()
        }
    }
    
    /// Clears all saved data
    func clear() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Cleared saved app data")
            }
        } catch {
            print("❌ Failed to clear app data: \(error.localizedDescription)")
        }
    }

    /// Saves pantry match scores to a separate JSON file keyed by recipe ID.
    func savePantryMatchScores(_ scores: [UUID: Double]) {
        let payload = SavedPantryMatchScores(scoresByRecipeId: scores.mapKeys(\.uuidString))

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let encoded = try encoder.encode(payload)
            try encoded.write(to: pantryMatchScoresFileURL, options: .atomic)
        } catch {
            print("❌ Failed to save pantry match scores: \(error.localizedDescription)")
        }
    }

    /// Loads pantry match scores from the separate JSON file.
    func loadPantryMatchScores() -> [UUID: Double] {
        guard FileManager.default.fileExists(atPath: pantryMatchScoresFileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: pantryMatchScoresFileURL)
            let decoder = JSONDecoder()
            let savedScores = try decoder.decode(SavedPantryMatchScores.self, from: data)
            return savedScores.scoresByRecipeId.reduce(into: [UUID: Double]()) { result, entry in
                guard let recipeId = UUID(uuidString: entry.key) else { return }
                result[recipeId] = entry.value
            }
        } catch {
            print("❌ Failed to load pantry match scores: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Clears persisted pantry match scores.
    func clearPantryMatchScores() {
        do {
            if FileManager.default.fileExists(atPath: pantryMatchScoresFileURL.path) {
                try FileManager.default.removeItem(at: pantryMatchScoresFileURL)
                print("🗑️ Cleared pantry match scores")
            }
        } catch {
            print("❌ Failed to clear pantry match scores: \(error.localizedDescription)")
        }
    }
}

private struct SavedPantryMatchScores: Codable {
    var scoresByRecipeId: [String: Double]
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
        try reduce(into: [T: Value]()) { result, entry in
            result[try transform(entry.key)] = entry.value
        }
    }
}
