//
//  Recipe.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct RecipeSource: Codable, Hashable {
    let name: String
    let url: String?
}

/// How a recipe is classified from `RecipeSource.name` (same rules as card source border colors).
enum RecipeSourceCategory: Equatable, Hashable {
    case reciplease
    case cookbook
    case web
    case other
}

struct Recipe: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let servings: Int?
    let difficulty: Int?
    let tips: [String]?
    let source: RecipeSource?
    var imageURL: String?
    var isGeneratingImage: Bool = false
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        ingredients: [RecipeIngredient],
        steps: [String],
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        servings: Int? = nil,
        difficulty: Int? = nil,
        imageURL: String? = nil,
        isGeneratingImage: Bool = false,
        tips: [String]? = nil,
        source: RecipeSource? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.steps = steps
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.servings = servings
        self.difficulty = difficulty
        self.tips = tips
        self.source = source
        self.imageURL = imageURL
        self.isGeneratingImage = isGeneratingImage
    }
    
    // Custom decoder: Generate id if not present (API responses), use existing id if present (saved data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but generate a new one if it's not present (API responses)
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID() // Generate new ID for API responses that don't include it
        }
        
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        ingredients = try container.decode([RecipeIngredient].self, forKey: .ingredients)
        steps = try container.decode([String].self, forKey: .steps)
        prepTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .prepTimeMinutes)
        cookTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .cookTimeMinutes)
        servings = try container.decodeIfPresent(Int.self, forKey: .servings)
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty)
        tips = try container.decodeIfPresent([String].self, forKey: .tips)
        source = try container.decodeIfPresent(RecipeSource.self, forKey: .source)
        // Support both "imageURL" (local persistence) and "imageUrl" (backend API)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? container.decodeIfPresent(String.self, forKey: .imageUrl)
        isGeneratingImage = false // Not encoded/decoded, just UI state
    }
    
    // Custom encoder: Always include id when encoding (for local persistence)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(steps, forKey: .steps)
        try container.encodeIfPresent(prepTimeMinutes, forKey: .prepTimeMinutes)
        try container.encodeIfPresent(cookTimeMinutes, forKey: .cookTimeMinutes)
        try container.encodeIfPresent(servings, forKey: .servings)
        try container.encodeIfPresent(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(tips, forKey: .tips)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        // isGeneratingImage is not encoded
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ingredients
        case steps
        case prepTimeMinutes
        case cookTimeMinutes
        case servings
        case difficulty
        case tips
        case source
        case imageURL      // local persistence key
        case imageUrl = "imageUrl" // backend API key
    }
}

extension Recipe {
    /// Ingredient lines with a non-empty `name`, suitable for nutrition and validation.
    var nonEmptyRecipeIngredientLines: [RecipeIngredient] {
        ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var sourceCategory: RecipeSourceCategory {
        guard let rawSourceName = source?.name else {
            return .other
        }
        let normalized = rawSourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return .other
        }
        if normalized.contains("reciplease") {
            return .reciplease
        }
        if normalized.contains("cookbook") {
            return .cookbook
        }
        if normalized.contains("web") || normalized.contains("url") {
            return .web
        }
        return .other
    }
}

struct RecipeResponse: Codable {
    let recipes: [Recipe]
}

// MARK: - Meal plan API (POST /api/recipe/meal-plan)
//
// `MealPlanRequest.counts` encodes `breakfast`, `lunch`, `dinner`, `snack`, and `dessert` (non-negative integers).
// `MealPlanResult` decodes the same keys as arrays of `Recipe`; dessert also accepts a top-level `desserts` array if `dessert` is empty.

/// Ingredient object for meal-plan (and generate) requests: `generalName` required; optional `specificName`, `quantity`. Omits local `id`.
struct MealPlanIngredientPayload: Encodable {
    let generalName: String
    let specificName: String?
    let quantity: String?

    init(generalName: String, specificName: String? = nil, quantity: String? = nil) {
        self.generalName = generalName
        self.specificName = specificName
        self.quantity = quantity
    }

    init(_ ingredient: Ingredient) {
        generalName = ingredient.generalName
        specificName = ingredient.specificName
        quantity = ingredient.quantity
    }
}

/// Per-slot recipe counts in the meal-plan request. Omitted keys decode as 0.
struct MealTypeCounts: Codable, Equatable, Sendable {
    var breakfast: Int
    var lunch: Int
    var dinner: Int
    var snack: Int
    var dessert: Int

    init(breakfast: Int = 0, lunch: Int = 0, dinner: Int = 0, snack: Int = 0, dessert: Int = 0) {
        self.breakfast = max(0, breakfast)
        self.lunch = max(0, lunch)
        self.dinner = max(0, dinner)
        self.snack = max(0, snack)
        self.dessert = max(0, dessert)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        breakfast = max(0, try c.decodeIfPresent(Int.self, forKey: .breakfast) ?? 0)
        lunch = max(0, try c.decodeIfPresent(Int.self, forKey: .lunch) ?? 0)
        dinner = max(0, try c.decodeIfPresent(Int.self, forKey: .dinner) ?? 0)
        snack = max(0, try c.decodeIfPresent(Int.self, forKey: .snack) ?? 0)
        dessert = max(0, try c.decodeIfPresent(Int.self, forKey: .dessert) ?? 0)
    }

    var total: Int { breakfast + lunch + dinner + snack + dessert }

    enum CodingKeys: String, CodingKey {
        case breakfast
        case lunch
        case dinner
        case snack
        case dessert
    }
}

/// Server accepts these case-insensitively; send lowercase. Invalid / omitted → server treats as `"any"`.
enum MealPlanStrictness: String, Encodable, Sendable {
    case only
    case mostly
    case any
}

/// Request body for `POST /api/recipe/meal-plan`.
struct MealPlanRequest: Encodable {
    let ingredients: [MealPlanIngredientPayload]
    let prompt: String?
    let strictness: String?
    let counts: MealTypeCounts

    init(
        ingredients: [MealPlanIngredientPayload],
        prompt: String? = nil,
        strictness: MealPlanStrictness? = nil,
        counts: MealTypeCounts
    ) {
        self.ingredients = ingredients
        if let p = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            self.prompt = p
        } else {
            self.prompt = nil
        }
        self.strictness = strictness?.rawValue
        self.counts = counts
    }

    /// Builds payloads from pantry ingredients (same shape as recipe generate).
    init(
        ingredients: [Ingredient],
        prompt: String? = nil,
        strictness: MealPlanStrictness? = nil,
        counts: MealTypeCounts
    ) {
        self.init(
            ingredients: ingredients.map { MealPlanIngredientPayload($0) },
            prompt: prompt,
            strictness: strictness,
            counts: counts
        )
    }
}

/// Response body: recipes grouped by meal type (same `Recipe` model as generate).
struct MealPlanResult: Decodable {
    let breakfast: [Recipe]
    let lunch: [Recipe]
    let dinner: [Recipe]
    let snack: [Recipe]
    let dessert: [Recipe]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        breakfast = try c.decodeIfPresent([Recipe].self, forKey: .breakfast) ?? []
        lunch = try c.decodeIfPresent([Recipe].self, forKey: .lunch) ?? []
        dinner = try c.decodeIfPresent([Recipe].self, forKey: .dinner) ?? []
        snack = try c.decodeIfPresent([Recipe].self, forKey: .snack) ?? []
        let dessertByKey = try c.decodeIfPresent([Recipe].self, forKey: .dessert) ?? []
        let dessertsByKey = try c.decodeIfPresent([Recipe].self, forKey: .desserts) ?? []
        dessert = dessertByKey.isEmpty ? dessertsByKey : dessertByKey
    }

    enum CodingKeys: String, CodingKey {
        case breakfast
        case lunch
        case dinner
        case snack
        case dessert
        case desserts
    }

    /// Flattened list in breakfast → lunch → snack → dinner → dessert order.
    var allRecipes: [Recipe] {
        breakfast + lunch + snack + dinner + dessert
    }
}
