//
//  StructuredCooking.swift
//  Reciplease
//
//  Per-step ingredient allocations, heat, doneness, and countdown timers.
//

import Foundation

struct StructuredStepIngredientUse: Codable, Hashable, Identifiable {
    var ingredientId: String?
    var name: String
    var amount: Double?
    var unit: String?
    var displayQuantity: String?

    var id: String { ingredientId ?? name }

    enum CodingKeys: String, CodingKey {
        case ingredientId, name, amount, unit, displayQuantity
    }

    init(
        ingredientId: String? = nil,
        name: String,
        amount: Double? = nil,
        unit: String? = nil,
        displayQuantity: String? = nil
    ) {
        self.ingredientId = ingredientId
        self.name = name
        self.amount = amount
        self.unit = unit
        self.displayQuantity = displayQuantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ingredientId = FlexibleDecoding.decodeString(container, forKey: .ingredientId)
        name = FlexibleDecoding.decodeString(container, forKey: .name) ?? ""
        amount = FlexibleDecoding.decodeDouble(container, forKey: .amount)
        unit = FlexibleDecoding.decodeString(container, forKey: .unit)
        displayQuantity = FlexibleDecoding.decodeString(container, forKey: .displayQuantity)
    }
}

struct StructuredStep: Codable, Hashable, Identifiable {
    var stepNumber: Int
    var text: String
    var ingredientUses: [StructuredStepIngredientUse]
    var timerSeconds: Int?
    var heat: String?
    var donenessCue: String?

    var id: Int { stepNumber }

    enum CodingKeys: String, CodingKey {
        case stepNumber, text, ingredientUses, timerSeconds, heat, donenessCue
    }

    init(
        stepNumber: Int,
        text: String,
        ingredientUses: [StructuredStepIngredientUse] = [],
        timerSeconds: Int? = nil,
        heat: String? = nil,
        donenessCue: String? = nil
    ) {
        self.stepNumber = stepNumber
        self.text = text
        self.ingredientUses = ingredientUses
        self.timerSeconds = timerSeconds
        self.heat = heat
        self.donenessCue = donenessCue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stepNumber = FlexibleDecoding.decodeInt(container, forKey: .stepNumber) ?? 0
        text = FlexibleDecoding.decodeString(container, forKey: .text) ?? ""
        ingredientUses = (try? container.decode([StructuredStepIngredientUse].self, forKey: .ingredientUses)) ?? []
        timerSeconds = FlexibleDecoding.decodeInt(container, forKey: .timerSeconds)
        heat = FlexibleDecoding.decodeString(container, forKey: .heat)
        donenessCue = FlexibleDecoding.decodeString(container, forKey: .donenessCue)
    }
}

enum CookTimer {
    /// Prefers a structured duration, then a plain-language duration in the step text.
    static func seconds(timerSeconds: Int?, stepText: String) -> Int? {
        if let timerSeconds, timerSeconds > 0 {
            return timerSeconds
        }
        return StepTimerDetector.detect(in: stepText)
    }
}

enum StepTimerDetector {
    static func detect(in text: String) -> Int? {
        let pattern = #"(\d+)\s*-?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return nil }
        var total = 0
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let amountRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let amount = Int(text[amountRange]) else { continue }
            total += amount * seconds(per: String(text[unitRange]))
        }
        return total > 0 ? total : nil
    }

    private static func seconds(per unit: String) -> Int {
        let normalized = unit.lowercased()
        if normalized.hasPrefix("h") { return 3600 }
        if normalized.hasPrefix("s") { return 1 }
        return 60
    }
}
