//
//  RecipeQuantityScaling.swift
//  PantryPal
//
//  Shared recipe ingredient quantity display for a chosen serving count (mirrors RecipeDetailView).
//

import Foundation

enum RecipeQuantityScaling {
    private static let nonScalableQuantityWhitelist: Set<String> = [
        "to taste",
        "a pinch"
    ]

    static func scaledDisplay(
        quantity: String,
        recipeServings: Int?,
        currentServings: Int
    ) -> (text: String, scaleFactorToShow: Int?) {
        guard !quantity.isEmpty else { return (quantity, nil) }

        let baseServings = max(recipeServings ?? 1, 1)
        let factor = Double(currentServings) / Double(baseServings)
        guard baseServings != currentServings else { return (quantity, nil) }

        if isNonScalableQuantity(quantity) { return (quantity, nil) }

        let parts = quantity.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else {
            return (quantity, scaleIndicator(for: factor))
        }

        let numberPart = String(first)
        let rest = parts.count > 1 ? " " + parts[1] : ""

        let numericValue: Double?
        if numberPart.contains("/") {
            let fractionParts = numberPart.split(separator: "/")
            if fractionParts.count == 2,
               let num = Double(fractionParts[0]),
               let den = Double(fractionParts[1]),
               den != 0 {
                numericValue = num / den
            } else {
                numericValue = nil
            }
        } else {
            numericValue = Double(numberPart)
        }

        guard let value = numericValue else {
            return (quantity, scaleIndicator(for: factor))
        }

        let scaled = value * factor
        let formatted = formatQuantityValue(scaled)
        return (formatted + rest, nil)
    }

    private static func isNonScalableQuantity(_ quantity: String) -> Bool {
        nonScalableQuantityWhitelist.contains(quantity.trimmingCharacters(in: .whitespaces).lowercased())
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

    private static func formatQuantityValue(_ value: Double) -> String {
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
            let intString = String(Int(absValue.rounded()))
            return sign + intString
        } else {
            let decimalString = trimTrailingZeros(String(format: "%.2f", absValue))
            return sign + decimalString
        }
    }

    private static func trimTrailingZeros(_ string: String) -> String {
        var s = string
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            s.removeLast()
        }
        return s
    }
}
