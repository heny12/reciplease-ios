//
//  TonightMenuRequest.swift
//  Reciplease
//
//  Wire body shared by v2 pitches and the v1 generate fallback.
//

import Foundation

struct TonightMenuWireIngredient: Encodable, Equatable {
    var id: String
    var generalName: String
    var specificName: String?
    var quantity: String?
    var amount: Double?
    var unit: String?
    var pinned: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(generalName, forKey: .generalName)
        try container.encodeIfPresent(specificName, forKey: .specificName)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(pinned, forKey: .pinned)
    }

    enum CodingKeys: String, CodingKey {
        case id, generalName, specificName, quantity, amount, unit, pinned
    }
}

struct TonightMenuWireRequest: Encodable, Equatable {
    var ingredients: [TonightMenuWireIngredient]
    var prompt: String?
    var strictness: String
    var count: Int
    var moods: [String]
    var dietaryExclusions: [String]
    var confirmedStaples: [String]
    var pinnedIngredients: [String]
    var maxTimeMinutes: Int?
    var servings: Int?
    var equipment: [String]
    var excludeSignatures: [String]
    var sessionId: String?

    func withCount(_ count: Int) -> TonightMenuWireRequest {
        var copy = self
        copy.count = count
        return copy
    }
}

enum TonightMenuRequestBuilder {
    static func composedPrompt(
        mealTypes: [String],
        cuisine: String?,
        custom: String?,
        similarTo: String? = nil,
        maxLength: Int = 200
    ) -> String? {
        var parts: [String] = []
        let meals = mealTypes.filter { $0.caseInsensitiveCompare("Any") != .orderedSame }
        if !meals.isEmpty {
            parts.append("Meal type: \(meals.joined(separator: ", "))")
        }
        if let cuisine, !cuisine.isEmpty, cuisine.caseInsensitiveCompare("Any") != .orderedSame {
            parts.append("Cuisine: \(cuisine)")
        }
        if let similarTo, !similarTo.isEmpty {
            parts.append("More like \(similarTo), but a distinct dish")
        }
        if let custom {
            let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { parts.append(trimmed) }
        }
        let joined = parts.joined(separator: ". ")
        guard !joined.isEmpty else { return nil }
        if joined.count <= maxLength { return joined }
        return String(joined.prefix(maxLength))
    }

    static func summaryLabel(ingredientNames: [String], count: Int, now: Date = Date(), calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(now) {
            day = "Tonight"
        } else if calendar.isDateInYesterday(now) {
            day = "Yesterday"
        } else {
            day = "Earlier"
        }
        let highlight = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " + ")
        if highlight.isEmpty {
            return "\(day) · \(count) ideas"
        }
        return "\(day) · \(highlight) (\(count))"
    }
}

struct GenerationConstraintSnapshot: Codable, Equatable {
    var strictness: String
    var moods: [String]
    var dietaryExclusions: [String]
    var confirmedStaples: [String]
    var pinnedIngredients: [String]
    var mealTypes: [String]
    var cuisine: String?
    var servings: Int?
    var equipment: [String]
    var maxTimeMinutes: Int?
    var prompt: String?
    var ingredientNames: [String]
}

struct GenerationSession: Codable, Identifiable {
    var sessionId: String
    var createdAt: Date
    var summaryLabel: String
    var constraints: GenerationConstraintSnapshot
    var pitches: [RecipePitch]
    var expandedRecipes: [String: Recipe]
    var viewedPitchIds: [String]
    var savedPitchIds: [String]
    var dismissedPitchIds: [String]
    var usedV1Fallback: Bool

    var id: String { sessionId }

    var visiblePitches: [RecipePitch] {
        pitches.filter { !dismissedPitchIds.contains($0.pitchId) }
    }
}
