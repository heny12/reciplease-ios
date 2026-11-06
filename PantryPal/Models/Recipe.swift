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

struct RecipeUndoSnapshot: Codable, Hashable {
    var name: String
    var description: String
    var ingredients: [RecipeIngredient]
    var steps: [String]
    var structuredSteps: [StructuredStep]?
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var servings: Int?
    var difficulty: Int?
    var tips: [String]?
    var imageURL: String?
    var hook: String?
    var extraIngredients: [String]?
    var changeSummary: String?

    init(recipe: Recipe) {
        name = recipe.name
        description = recipe.description
        ingredients = recipe.ingredients
        steps = recipe.steps
        structuredSteps = recipe.structuredSteps
        prepTimeMinutes = recipe.prepTimeMinutes
        cookTimeMinutes = recipe.cookTimeMinutes
        servings = recipe.servings
        difficulty = recipe.difficulty
        tips = recipe.tips
        imageURL = recipe.imageURL
        hook = recipe.hook
        extraIngredients = recipe.extraIngredients
        changeSummary = recipe.changeSummary
    }
}

struct Recipe: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var ingredients: [RecipeIngredient]
    var steps: [String]
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var servings: Int?
    var difficulty: Int?
    var tips: [String]?
    var source: RecipeSource?
    var imageURL: String?
    var isGeneratingImage: Bool = false
    var hook: String?
    var lane: String?
    var cuisine: String?
    var technique: String?
    var extraIngredients: [String]?
    var structuredSteps: [StructuredStep]?
    var version: Int?
    var updatedAt: Int?
    var changeSummary: String?
    var changedFields: [String]?
    var visualIdentityChanged: Bool?
    var tags: [String]
    var cookedCount: Int
    var lastCookedAt: Date?
    var rating: Int?
    var wouldCookAgain: Bool?
    var cookNotes: String?
    var catalogedAt: Date?
    var undoSnapshot: RecipeUndoSnapshot?
    var pitchId: String?
    var generationSessionId: String?

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
        source: RecipeSource? = nil,
        hook: String? = nil,
        lane: String? = nil,
        cuisine: String? = nil,
        technique: String? = nil,
        extraIngredients: [String]? = nil,
        structuredSteps: [StructuredStep]? = nil,
        version: Int? = nil,
        updatedAt: Int? = nil,
        changeSummary: String? = nil,
        changedFields: [String]? = nil,
        visualIdentityChanged: Bool? = nil,
        tags: [String] = [],
        cookedCount: Int = 0,
        lastCookedAt: Date? = nil,
        rating: Int? = nil,
        wouldCookAgain: Bool? = nil,
        cookNotes: String? = nil,
        catalogedAt: Date? = nil,
        undoSnapshot: RecipeUndoSnapshot? = nil,
        pitchId: String? = nil,
        generationSessionId: String? = nil
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
        self.hook = hook
        self.lane = lane
        self.cuisine = cuisine
        self.technique = technique
        self.extraIngredients = extraIngredients
        self.structuredSteps = structuredSteps
        self.version = version
        self.updatedAt = updatedAt
        self.changeSummary = changeSummary
        self.changedFields = changedFields
        self.visualIdentityChanged = visualIdentityChanged
        self.tags = tags
        self.cookedCount = cookedCount
        self.lastCookedAt = lastCookedAt
        self.rating = rating
        self.wouldCookAgain = wouldCookAgain
        self.cookNotes = cookNotes
        self.catalogedAt = catalogedAt
        self.undoSnapshot = undoSnapshot
        self.pitchId = pitchId
        self.generationSessionId = generationSessionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = FlexibleDecoding.decodeString(container, forKey: .id) {
            id = StableIdentifier.uuid(from: raw)
        } else {
            id = UUID()
        }
        name = FlexibleDecoding.decodeString(container, forKey: .name) ?? "Untitled recipe"
        description = FlexibleDecoding.decodeString(container, forKey: .description) ?? ""
        ingredients = (try? container.decode([RecipeIngredient].self, forKey: .ingredients)) ?? []
        steps = (try? container.decode([String].self, forKey: .steps)) ?? []
        prepTimeMinutes = FlexibleDecoding.decodeInt(container, forKey: .prepTimeMinutes)
        cookTimeMinutes = FlexibleDecoding.decodeInt(container, forKey: .cookTimeMinutes)
        servings = FlexibleDecoding.decodeInt(container, forKey: .servings)
        difficulty = FlexibleDecoding.decodeInt(container, forKey: .difficulty)
        tips = try container.decodeIfPresent([String].self, forKey: .tips)
        source = try container.decodeIfPresent(RecipeSource.self, forKey: .source)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? container.decodeIfPresent(String.self, forKey: .imageUrl)
        isGeneratingImage = false
        hook = FlexibleDecoding.decodeString(container, forKey: .hook)
        lane = FlexibleDecoding.decodeString(container, forKey: .lane)
        cuisine = FlexibleDecoding.decodeString(container, forKey: .cuisine)
        technique = FlexibleDecoding.decodeString(container, forKey: .technique)
        extraIngredients = try container.decodeIfPresent([String].self, forKey: .extraIngredients)
        structuredSteps = try container.decodeIfPresent([StructuredStep].self, forKey: .structuredSteps)
        version = FlexibleDecoding.decodeInt(container, forKey: .version)
        updatedAt = FlexibleDecoding.decodeInt(container, forKey: .updatedAt)
        changeSummary = FlexibleDecoding.decodeString(container, forKey: .changeSummary)
        changedFields = try container.decodeIfPresent([String].self, forKey: .changedFields)
        visualIdentityChanged = FlexibleDecoding.decodeBool(container, forKey: .visualIdentityChanged)
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        cookedCount = FlexibleDecoding.decodeInt(container, forKey: .cookedCount) ?? 0
        lastCookedAt = try container.decodeIfPresent(Date.self, forKey: .lastCookedAt)
        rating = FlexibleDecoding.decodeInt(container, forKey: .rating)
        wouldCookAgain = FlexibleDecoding.decodeBool(container, forKey: .wouldCookAgain)
        cookNotes = FlexibleDecoding.decodeString(container, forKey: .cookNotes)
        catalogedAt = try container.decodeIfPresent(Date.self, forKey: .catalogedAt)
        undoSnapshot = try container.decodeIfPresent(RecipeUndoSnapshot.self, forKey: .undoSnapshot)
        pitchId = FlexibleDecoding.decodeString(container, forKey: .pitchId)
        generationSessionId = FlexibleDecoding.decodeString(container, forKey: .generationSessionId)
    }

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
        try container.encodeIfPresent(hook, forKey: .hook)
        try container.encodeIfPresent(lane, forKey: .lane)
        try container.encodeIfPresent(cuisine, forKey: .cuisine)
        try container.encodeIfPresent(technique, forKey: .technique)
        try container.encodeIfPresent(extraIngredients, forKey: .extraIngredients)
        try container.encodeIfPresent(structuredSteps, forKey: .structuredSteps)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(changeSummary, forKey: .changeSummary)
        try container.encodeIfPresent(changedFields, forKey: .changedFields)
        try container.encodeIfPresent(visualIdentityChanged, forKey: .visualIdentityChanged)
        try container.encode(tags, forKey: .tags)
        try container.encode(cookedCount, forKey: .cookedCount)
        try container.encodeIfPresent(lastCookedAt, forKey: .lastCookedAt)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(wouldCookAgain, forKey: .wouldCookAgain)
        try container.encodeIfPresent(cookNotes, forKey: .cookNotes)
        try container.encodeIfPresent(catalogedAt, forKey: .catalogedAt)
        try container.encodeIfPresent(undoSnapshot, forKey: .undoSnapshot)
        try container.encodeIfPresent(pitchId, forKey: .pitchId)
        try container.encodeIfPresent(generationSessionId, forKey: .generationSessionId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, ingredients, steps
        case prepTimeMinutes, cookTimeMinutes, servings, difficulty, tips, source
        case imageURL
        case imageUrl = "imageUrl"
        case hook, lane, cuisine, technique, extraIngredients, structuredSteps
        case version, updatedAt, changeSummary, changedFields, visualIdentityChanged
        case tags, cookedCount, lastCookedAt, rating, wouldCookAgain, cookNotes
        case catalogedAt, undoSnapshot, pitchId, generationSessionId
    }

    var totalTimeMinutes: Int? {
        switch (prepTimeMinutes, cookTimeMinutes) {
        case let (prep?, cook?): return prep + cook
        case let (prep?, nil): return prep
        case let (nil, cook?): return cook
        default: return nil
        }
    }

    func withImage(url: String?, generating: Bool) -> Recipe {
        var copy = self
        copy.imageURL = url
        copy.isGeneratingImage = generating
        return copy
    }

    func stampedForLibrary(now: Date = Date()) -> Recipe {
        var copy = self
        if copy.catalogedAt == nil { copy.catalogedAt = now }
        copy.isGeneratingImage = false
        return copy
    }

    func pitchCard() -> RecipePitch {
        let pantry = ingredients
            .filter { ($0.category ?? "pantry").lowercased() != "extra" }
            .map(\.name)
        let minutes = totalTimeMinutes
        return RecipePitch(
            pitchId: pitchId ?? id.uuidString,
            lane: lane,
            title: name,
            hook: hook ?? description,
            totalTimeMinutes: minutes,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            difficulty: difficulty,
            servings: servings,
            cuisine: cuisine,
            technique: technique,
            pantryIngredientsUsed: pantry,
            staplesUsed: [],
            extraIngredients: extraIngredients ?? ingredients.filter { ($0.category ?? "").lowercased() == "extra" }.map(\.name)
        )
    }
}

extension Recipe {
    var nonEmptyRecipeIngredientLines: [RecipeIngredient] {
        ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var sourceCategory: RecipeSourceCategory {
        guard let rawSourceName = source?.name else { return .other }
        let normalized = rawSourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return .other }
        if normalized.contains("reciplease") { return .reciplease }
        if normalized.contains("cookbook") { return .cookbook }
        if normalized.contains("web") || normalized.contains("url") { return .web }
        return .other
    }

    func restoringUndo() -> Recipe? {
        guard let undoSnapshot else { return nil }
        var copy = self
        copy.name = undoSnapshot.name
        copy.description = undoSnapshot.description
        copy.ingredients = undoSnapshot.ingredients
        copy.steps = undoSnapshot.steps
        copy.structuredSteps = undoSnapshot.structuredSteps
        copy.prepTimeMinutes = undoSnapshot.prepTimeMinutes
        copy.cookTimeMinutes = undoSnapshot.cookTimeMinutes
        copy.servings = undoSnapshot.servings
        copy.difficulty = undoSnapshot.difficulty
        copy.tips = undoSnapshot.tips
        copy.imageURL = undoSnapshot.imageURL
        copy.hook = undoSnapshot.hook
        copy.extraIngredients = undoSnapshot.extraIngredients
        copy.changeSummary = nil
        copy.changedFields = nil
        copy.visualIdentityChanged = nil
        copy.undoSnapshot = nil
        copy.isGeneratingImage = false
        return copy
    }
}

enum RecipeModificationMerge {
    /// Applies a server modification while keeping the local id, cook history, and tags.
    /// The previous version stays available for undo. Photos refresh only when the dish itself changed.
    static func applying(server: Recipe, onto original: Recipe) -> Recipe {
        var merged = server
        merged = Recipe(
            id: original.id,
            name: server.name,
            description: server.description,
            ingredients: server.ingredients,
            steps: server.steps,
            prepTimeMinutes: server.prepTimeMinutes ?? original.prepTimeMinutes,
            cookTimeMinutes: server.cookTimeMinutes ?? original.cookTimeMinutes,
            servings: server.servings ?? original.servings,
            difficulty: server.difficulty ?? original.difficulty,
            imageURL: server.visualIdentityChanged == true ? nil : (server.imageURL ?? original.imageURL),
            isGeneratingImage: false,
            tips: server.tips ?? original.tips,
            source: server.source ?? original.source,
            hook: server.hook ?? original.hook,
            lane: server.lane ?? original.lane,
            cuisine: server.cuisine ?? original.cuisine,
            technique: server.technique ?? original.technique,
            extraIngredients: server.extraIngredients ?? original.extraIngredients,
            structuredSteps: server.structuredSteps ?? original.structuredSteps,
            version: server.version ?? original.version,
            updatedAt: server.updatedAt ?? original.updatedAt,
            changeSummary: server.changeSummary,
            changedFields: server.changedFields,
            visualIdentityChanged: server.visualIdentityChanged,
            tags: original.tags,
            cookedCount: original.cookedCount,
            lastCookedAt: original.lastCookedAt,
            rating: original.rating,
            wouldCookAgain: original.wouldCookAgain,
            cookNotes: original.cookNotes,
            catalogedAt: original.catalogedAt,
            undoSnapshot: RecipeUndoSnapshot(recipe: original),
            pitchId: original.pitchId,
            generationSessionId: original.generationSessionId
        )
        return merged
    }
}

struct RecipeIdentityMergeResult {
    var recipes: [Recipe]
    var favoritedRecipes: [Recipe]
    var openedId: UUID
    var remappedFrom: UUID?
}

enum RecipeIdentityMerge {
    /// Keeps the server recipe id. A same-name local copy is retargeted instead of discarding the Firestore UUID.
    static func merge(recipes: [Recipe], favoritedRecipes: [Recipe], fetched: Recipe) -> RecipeIdentityMergeResult {
        if let index = recipes.firstIndex(where: { $0.id == fetched.id }) {
            var next = recipes
            next[index] = preservingLocal(existing: recipes[index], incoming: fetched, id: fetched.id)
            return RecipeIdentityMergeResult(recipes: next, favoritedRecipes: favoritedRecipes, openedId: fetched.id, remappedFrom: nil)
        }
        if let index = favoritedRecipes.firstIndex(where: { $0.id == fetched.id }) {
            var next = favoritedRecipes
            next[index] = preservingLocal(existing: favoritedRecipes[index], incoming: fetched, id: fetched.id)
            return RecipeIdentityMergeResult(recipes: recipes, favoritedRecipes: next, openedId: fetched.id, remappedFrom: nil)
        }
        if let index = recipes.firstIndex(where: { $0.name == fetched.name && $0.description == fetched.description }) {
            let oldId = recipes[index].id
            var next = recipes
            next[index] = preservingLocal(existing: recipes[index], incoming: fetched, id: fetched.id)
            return RecipeIdentityMergeResult(recipes: next, favoritedRecipes: favoritedRecipes, openedId: fetched.id, remappedFrom: oldId == fetched.id ? nil : oldId)
        }
        if let index = favoritedRecipes.firstIndex(where: { $0.name == fetched.name && $0.description == fetched.description }) {
            let oldId = favoritedRecipes[index].id
            var next = favoritedRecipes
            next[index] = preservingLocal(existing: favoritedRecipes[index], incoming: fetched, id: fetched.id)
            return RecipeIdentityMergeResult(recipes: recipes, favoritedRecipes: next, openedId: fetched.id, remappedFrom: oldId == fetched.id ? nil : oldId)
        }
        var inserted = recipes
        inserted.insert(fetched.stampedForLibrary(), at: 0)
        return RecipeIdentityMergeResult(recipes: inserted, favoritedRecipes: favoritedRecipes, openedId: fetched.id, remappedFrom: nil)
    }

    private static func preservingLocal(existing: Recipe, incoming: Recipe, id: UUID) -> Recipe {
        Recipe(
            id: id,
            name: incoming.name,
            description: incoming.description,
            ingredients: incoming.ingredients,
            steps: incoming.steps,
            prepTimeMinutes: incoming.prepTimeMinutes,
            cookTimeMinutes: incoming.cookTimeMinutes,
            servings: incoming.servings,
            difficulty: incoming.difficulty,
            imageURL: incoming.imageURL ?? existing.imageURL,
            isGeneratingImage: false,
            tips: incoming.tips ?? existing.tips,
            source: incoming.source ?? existing.source,
            hook: incoming.hook ?? existing.hook,
            lane: incoming.lane ?? existing.lane,
            cuisine: incoming.cuisine ?? existing.cuisine,
            technique: incoming.technique ?? existing.technique,
            extraIngredients: incoming.extraIngredients ?? existing.extraIngredients,
            structuredSteps: incoming.structuredSteps ?? existing.structuredSteps,
            version: incoming.version ?? existing.version,
            updatedAt: incoming.updatedAt,
            changeSummary: incoming.changeSummary,
            changedFields: incoming.changedFields,
            visualIdentityChanged: incoming.visualIdentityChanged,
            tags: existing.tags,
            cookedCount: existing.cookedCount,
            lastCookedAt: existing.lastCookedAt,
            rating: existing.rating,
            wouldCookAgain: existing.wouldCookAgain,
            cookNotes: existing.cookNotes,
            catalogedAt: existing.catalogedAt ?? Date(),
            undoSnapshot: existing.undoSnapshot,
            pitchId: existing.pitchId,
            generationSessionId: existing.generationSessionId
        )
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
