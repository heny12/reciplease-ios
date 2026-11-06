//
//  RecipeQuantityScaling.swift
//  PantryPal
//
//  Serving scaling for mixed numbers, fractions, vulgar fractions, and ranges.
//  "1 1/2 cups" doubled is "3 cups", not "2 1/2 cups".
//

import Foundation

enum RecipeQuantityScaling {
    private static let nonScalableQuantityWhitelist: Set<String> = [
        "to taste",
        "a pinch",
        "pinch",
        "as needed"
    ]

    private static let vulgarFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0 / 3.0, "⅔": 2.0 / 3.0,
        "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
        "⅙": 1.0 / 6.0, "⅚": 5.0 / 6.0,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
    ]

    static func scaledDisplay(
        quantity: String,
        recipeServings: Int?,
        currentServings: Int
    ) -> (text: String, scaleFactorToShow: Int?) {
        scaledDisplay(
            amount: nil,
            unit: nil,
            quantity: quantity,
            recipeServings: recipeServings,
            currentServings: currentServings
        )
    }

    /// Prefers structured `amount` / `unit` when the backend sent them.
    static func scaledDisplay(
        amount: Double?,
        unit: String?,
        quantity: String,
        recipeServings: Int?,
        currentServings: Int
    ) -> (text: String, scaleFactorToShow: Int?) {
        let baseServings = max(recipeServings ?? 1, 1)
        let factor = Double(currentServings) / Double(baseServings)
        let unchanged = baseServings == currentServings

        if let amount {
            if unchanged {
                if !quantity.isEmpty { return (quantity, nil) }
                return (formatAmount(amount, unit: unit), nil)
            }
            if isNonScalableQuantity(quantity) { return (quantity.isEmpty ? formatAmount(amount, unit: unit) : quantity, nil) }
            return (formatAmount(amount * factor, unit: unit), nil)
        }

        guard !quantity.isEmpty else { return (quantity, nil) }
        if unchanged { return (quantity, nil) }
        if isNonScalableQuantity(quantity) { return (quantity, nil) }

        guard let parsed = parseLeadingQuantity(quantity) else {
            return (quantity, scaleIndicator(for: factor))
        }
        let first = formatQuantityValue(parsed.first * factor)
        let scaled: String
        if let second = parsed.second {
            let secondText = formatQuantityValue(second * factor)
            scaled = first + parsed.separator + secondText
        } else {
            scaled = first
        }
        return (scaled + parsed.remainder, nil)
    }

    static func formatQuantityValue(_ value: Double) -> String {
        let isNegative = value < 0
        let absValue = abs(value)
        let whole = Int(absValue.rounded(.towardZero))
        let fraction = absValue - Double(whole)
        let epsilon = 0.01

        let denominators = [2, 3, 4, 8, 16]
        var bestNumerator = 0
        var bestDenominator = 1
        var bestDiff = epsilon

        for denom in denominators {
            let rawNumerator = fraction * Double(denom)
            let roundedNumerator = rawNumerator.rounded()
            guard roundedNumerator > 0 else { continue }
            let approx = roundedNumerator / Double(denom)
            let diff = abs(approx - fraction)
            if diff < bestDiff {
                bestDiff = diff
                bestNumerator = Int(roundedNumerator)
                bestDenominator = denom
            }
        }

        let sign = isNegative ? "-" : ""

        if bestNumerator > 0 {
            let fractionString = "\(bestNumerator)/\(bestDenominator)"
            if whole == 0 {
                return sign + fractionString
            } else {
                return "\(sign)\(whole) \(fractionString)"
            }
        }

        if abs(absValue.rounded() - absValue) < 0.01 {
            return sign + String(Int(absValue.rounded()))
        }
        return sign + trimTrailingZeros(String(format: "%.2f", absValue))
    }

    private struct ParsedLeadingQuantity {
        var first: Double
        var second: Double?
        var separator: String
        var remainder: String
    }

    private static func parseLeadingQuantity(_ quantity: String) -> ParsedLeadingQuantity? {
        let scalars = quantity
        var index = scalars.startIndex
        skipSpaces(in: scalars, index: &index)
        guard let first = parseNumber(in: scalars, index: &index) else { return nil }

        let checkpoint = index
        skipSpaces(in: scalars, index: &index)
        if let separator = rangeSeparator(in: scalars, index: &index),
           let second = parseNumber(in: scalars, index: &index) {
            let remainder = String(scalars[index...])
            return ParsedLeadingQuantity(first: first, second: second, separator: separator, remainder: remainder)
        }
        index = checkpoint
        var remainder = String(scalars[index...])
        if !remainder.isEmpty, !remainder.hasPrefix(" "), remainder.first?.isLetter == true {
            remainder = " " + remainder
        }
        return ParsedLeadingQuantity(first: first, second: nil, separator: "", remainder: remainder)
    }

    private static func rangeSeparator(in text: String, index: inout String.Index) -> String? {
        guard index < text.endIndex else { return nil }
        let character = text[index]
        if character == "-" || character == "–" || character == "—" {
            index = text.index(after: index)
            skipSpaces(in: text, index: &index)
            return "-"
        }
        let rest = text[index...]
        if rest.lowercased().hasPrefix("to"),
           rest.dropFirst(2).first.map({ $0.isWhitespace || $0.isNumber || vulgarFractions[$0] != nil }) == true {
            index = text.index(index, offsetBy: 2)
            skipSpaces(in: text, index: &index)
            return " to "
        }
        return nil
    }

    private static func parseNumber(in text: String, index: inout String.Index) -> Double? {
        guard index < text.endIndex else { return nil }
        if let vulgar = vulgarFractions[text[index]] {
            index = text.index(after: index)
            return vulgar
        }
        let start = index
        var sawDigit = false
        var sawDot = false
        while index < text.endIndex {
            let character = text[index]
            if vulgarFractions[character] != nil { break }
            if character.isNumber {
                sawDigit = true
                index = text.index(after: index)
            } else if character == ".", !sawDot {
                sawDot = true
                index = text.index(after: index)
            } else {
                break
            }
        }
        if sawDigit, let base = Double(text[start..<index]) {
            if index < text.endIndex, let vulgar = vulgarFractions[text[index]] {
                index = text.index(after: index)
                return base + vulgar
            }
            if index < text.endIndex, text[index] == "/" {
                index = start
                return parseSimpleFraction(in: text, index: &index)
            }
            if index < text.endIndex, text[index] == " " {
                var lookAhead = text.index(after: index)
                if lookAhead < text.endIndex, let vulgar = vulgarFractions[text[lookAhead]] {
                    index = text.index(after: lookAhead)
                    return base + vulgar
                }
                if let fraction = parseSimpleFraction(in: text, index: &lookAhead), fraction < 1 {
                    index = lookAhead
                    return base + fraction
                }
            }
            return base
        }
        index = start
        return parseSimpleFraction(in: text, index: &index)
    }

    private static func parseSimpleFraction(in text: String, index: inout String.Index) -> Double? {
        let start = index
        guard index < text.endIndex, text[index].isNumber else { return nil }
        while index < text.endIndex, text[index].isNumber {
            index = text.index(after: index)
        }
        guard index < text.endIndex, text[index] == "/" else {
            index = start
            return nil
        }
        index = text.index(after: index)
        let denominatorStart = index
        guard index < text.endIndex, text[index].isNumber else {
            index = start
            return nil
        }
        while index < text.endIndex, text[index].isNumber {
            index = text.index(after: index)
        }
        guard let numerator = Double(text[start..<text.index(before: denominatorStart)]),
              let denominator = Double(text[denominatorStart..<index]),
              denominator != 0 else {
            index = start
            return nil
        }
        return numerator / denominator
    }

    private static func skipSpaces(in text: String, index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private static func formatAmount(_ amount: Double, unit: String?) -> String {
        let number = formatQuantityValue(amount)
        guard let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return number
        }
        return number + " " + unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isNonScalableQuantity(_ quantity: String) -> Bool {
        nonScalableQuantityWhitelist.contains(quantity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func scaleIndicator(for factor: Double) -> Int? {
        let epsilon = 0.05
        if abs(factor - 1.0) < epsilon {
            return nil
        } else if factor > 1.0 {
            let up = Int(round(factor))
            return up >= 2 ? up : nil
        } else {
            let down = Int(round(1.0 / factor))
            return down >= 2 ? -down : nil
        }
    }

    private static func trimTrailingZeros(_ string: String) -> String {
        var text = string
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }
}
