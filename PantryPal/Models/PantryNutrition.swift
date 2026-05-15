//
//  PantryNutrition.swift
//  Reciplease
//
//  Models for POST /api/recipe/nutrition responses and UI-friendly totals.
//

import Foundation

// MARK: - API response (snake_case JSON)

struct RecipeNutritionAPIResponse: Codable {
    let totals: RecipeNutritionTotalsPayload?
    let disclaimer: String?
}

struct RecipeNutritionTotalsPayload: Codable {
    let caloriesKcal: Double?
    let proteinG: Double?
    let fatG: Double?
    let carbohydrateG: Double?
    let fiberG: Double?
    let sodiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydrateG = "carbohydrate_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
    }
}

// MARK: - UI layer

struct PantryNutritionTotals: Equatable {
    let caloriesKcal: Double?
    let proteinG: Double?
    let fatG: Double?
    let carbohydrateG: Double?
    let fiberG: Double?
    let sodiumMg: Double?

    init(from payload: RecipeNutritionTotalsPayload?) {
        let p = payload
        caloriesKcal = p?.caloriesKcal
        proteinG = p?.proteinG
        fatG = p?.fatG
        carbohydrateG = p?.carbohydrateG
        fiberG = p?.fiberG
        sodiumMg = p?.sodiumMg
    }

    init(
        caloriesKcal: Double?,
        proteinG: Double?,
        fatG: Double?,
        carbohydrateG: Double?,
        fiberG: Double?,
        sodiumMg: Double?
    ) {
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbohydrateG = carbohydrateG
        self.fiberG = fiberG
        self.sodiumMg = sodiumMg
    }

    /// Multiplies every numeric field (e.g. per-serving = divide full-recipe totals by `Recipe.servings`).
    func scaled(by factor: Double) -> PantryNutritionTotals {
        guard factor.isFinite, factor > 0 else { return self }
        if abs(factor - 1) < 1e-9 { return self }
        func m(_ v: Double?) -> Double? {
            guard let v, v.isFinite else { return v }
            return v * factor
        }
        return PantryNutritionTotals(
            caloriesKcal: m(caloriesKcal),
            proteinG: m(proteinG),
            fatG: m(fatG),
            carbohydrateG: m(carbohydrateG),
            fiberG: m(fiberG),
            sodiumMg: m(sodiumMg)
        )
    }
}

struct PantryNutritionResult: Equatable {
    let totals: PantryNutritionTotals
    let disclaimer: String

    init(api: RecipeNutritionAPIResponse) {
        totals = PantryNutritionTotals(from: api.totals)
        disclaimer = api.disclaimer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    init(totals: PantryNutritionTotals, disclaimer: String) {
        self.totals = totals
        self.disclaimer = disclaimer
    }

    func scaled(by factor: Double) -> PantryNutritionResult {
        PantryNutritionResult(totals: totals.scaled(by: factor), disclaimer: disclaimer)
    }
}

enum PantryNutritionFormatting {
    private static let macroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        f.locale = .current
        return f
    }()

    private static let calorieFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        f.locale = .current
        return f
    }()

    static func formatOptionalDouble(_ value: Double?, caloriesStyle: Bool = false) -> String {
        guard let value, value.isFinite else { return "—" }
        let f = caloriesStyle ? calorieFormatter : macroFormatter
        return f.string(from: NSNumber(value: value)) ?? "—"
    }
}
