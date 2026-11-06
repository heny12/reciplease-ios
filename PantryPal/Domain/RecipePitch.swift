//
//  RecipePitch.swift
//  Reciplease
//
//  Lightweight v2 pitch cards, plus a pitch built from a full v1 recipe.
//

import Foundation

enum RecipeLane {
    static func displayName(for raw: String?) -> String {
        switch raw?.lowercased() {
        case "quick_skillet": return "Quick Skillet"
        case "cozy_bowl", "cozy_soup": return "Cozy Bowl"
        case "sheet_pan", "sheet-pan": return "Sheet-Pan"
        case "fresh_crisp", "fresh_and_crisp": return "Fresh & Crisp"
        case "comfort_classic": return "Comfort Classic"
        case "chefs_twist", "chef_twist", "chefs-twist": return "Chef's Twist"
        case nil, "": return "Tonight's Idea"
        default:
            return raw?
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized ?? "Tonight's Idea"
        }
    }
}

struct RecipePitch: Codable, Identifiable, Hashable {
    var pitchId: String
    var lane: String?
    var title: String
    var hook: String?
    var totalTimeMinutes: Int?
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var difficulty: Int?
    var servings: Int?
    var cuisine: String?
    var technique: String?
    var pantryIngredientsUsed: [String]
    var staplesUsed: [String]
    var extraIngredients: [String]

    var id: String { pitchId }

    var laneTitle: String { RecipeLane.displayName(for: lane) }

    var signature: String { title }

    enum CodingKeys: String, CodingKey {
        case pitchId, lane, title, hook, totalTimeMinutes, prepTimeMinutes, cookTimeMinutes
        case difficulty, servings, cuisine, technique
        case pantryIngredientsUsed, staplesUsed, extraIngredients
    }

    init(
        pitchId: String,
        lane: String? = nil,
        title: String,
        hook: String? = nil,
        totalTimeMinutes: Int? = nil,
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        difficulty: Int? = nil,
        servings: Int? = nil,
        cuisine: String? = nil,
        technique: String? = nil,
        pantryIngredientsUsed: [String] = [],
        staplesUsed: [String] = [],
        extraIngredients: [String] = []
    ) {
        self.pitchId = pitchId
        self.lane = lane
        self.title = title
        self.hook = hook
        self.totalTimeMinutes = totalTimeMinutes
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.difficulty = difficulty
        self.servings = servings
        self.cuisine = cuisine
        self.technique = technique
        self.pantryIngredientsUsed = pantryIngredientsUsed
        self.staplesUsed = staplesUsed
        self.extraIngredients = extraIngredients
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pitchId = FlexibleDecoding.decodeString(container, forKey: .pitchId) ?? UUID().uuidString
        lane = FlexibleDecoding.decodeString(container, forKey: .lane)
        title = FlexibleDecoding.decodeString(container, forKey: .title) ?? "Untitled idea"
        hook = FlexibleDecoding.decodeString(container, forKey: .hook)
        totalTimeMinutes = FlexibleDecoding.decodeInt(container, forKey: .totalTimeMinutes)
        prepTimeMinutes = FlexibleDecoding.decodeInt(container, forKey: .prepTimeMinutes)
        cookTimeMinutes = FlexibleDecoding.decodeInt(container, forKey: .cookTimeMinutes)
        difficulty = FlexibleDecoding.decodeInt(container, forKey: .difficulty)
        servings = FlexibleDecoding.decodeInt(container, forKey: .servings)
        cuisine = FlexibleDecoding.decodeString(container, forKey: .cuisine)
        technique = FlexibleDecoding.decodeString(container, forKey: .technique)
        pantryIngredientsUsed = (try? container.decode([String].self, forKey: .pantryIngredientsUsed)) ?? []
        staplesUsed = (try? container.decode([String].self, forKey: .staplesUsed)) ?? []
        extraIngredients = (try? container.decode([String].self, forKey: .extraIngredients)) ?? []
        if totalTimeMinutes == nil {
            let prep = prepTimeMinutes ?? 0
            let cook = cookTimeMinutes ?? 0
            if prep + cook > 0 { totalTimeMinutes = prep + cook }
        }
    }

    func matchPill() -> String {
        let pantryCount = pantryIngredientsUsed.count
        let extras = extraIngredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if extras.isEmpty {
            if pantryCount == 1 { return "Uses 1 pantry item" }
            return "Uses \(pantryCount) pantry items"
        }
        let extraLabel = extras.count == 1 ? extras[0] : extras.joined(separator: ", ")
        let prefix = pantryCount == 1 ? "Uses 1 pantry item" : "Uses \(pantryCount) pantry items"
        let extraPrefix = extras.count == 1 ? "+1 extra" : "+\(extras.count) extras"
        return "\(prefix) · \(extraPrefix): \(extraLabel)"
    }

    var difficultyLabel: String {
        switch difficulty ?? 0 {
        case 1: return "Easy"
        case 2: return "Simple"
        case 3: return "Moderate"
        case 4: return "Involved"
        case 5...: return "Project"
        default: return "Any level"
        }
    }
}

struct PitchDeckResponse: Decodable {
    var sessionId: String?
    var status: String?
    var reasonCodes: [String]
    var pitches: [RecipePitch]

    enum CodingKeys: String, CodingKey {
        case sessionId, status, reasonCodes, pitches
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = FlexibleDecoding.decodeString(container, forKey: .sessionId)
        status = FlexibleDecoding.decodeString(container, forKey: .status)
        reasonCodes = (try? container.decode([String].self, forKey: .reasonCodes)) ?? []
        pitches = (try? container.decode([RecipePitch].self, forKey: .pitches)) ?? []
    }
}

struct ExpandRecipeResponse: Decodable {
    var recipe: Recipe
    var cached: Bool?

    enum CodingKeys: String, CodingKey {
        case recipe, cached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipe = try container.decode(Recipe.self, forKey: .recipe)
        cached = FlexibleDecoding.decodeBool(container, forKey: .cached)
    }
}
