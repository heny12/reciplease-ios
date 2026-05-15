//
//  NutritionEstimateViews.swift
//  PantryPal
//
//  Shared “nutrition label” style layout for recipe and pantry estimates.
//

import SwiftUI

// MARK: - Palette (macro colors familiar from fitness / food apps)

private enum NutritionMacroColors {
    static let protein = Color(red: 0.20, green: 0.55, blue: 0.92)
    static let carbs = Color(red: 0.98, green: 0.62, blue: 0.14)
    static let fat = Color(red: 0.93, green: 0.38, blue: 0.48)
    static let fiber = Color.pantryPrimary
    static let sodium = Color(red: 0.45, green: 0.48, blue: 0.58)
}

// MARK: - Macro math (4 / 4 / 9 kcal per gram)

private struct MacroEnergyModel {
    let proteinG: Double
    let carbG: Double
    let fatG: Double

    init(totals: PantryNutritionTotals) {
        proteinG = totals.proteinG ?? 0
        carbG = totals.carbohydrateG ?? 0
        fatG = totals.fatG ?? 0
    }

    var proteinKcal: Double { max(0, proteinG) * 4 }
    var carbKcal: Double { max(0, carbG) * 4 }
    var fatKcal: Double { max(0, fatG) * 9 }

    var totalMacroKcal: Double { proteinKcal + carbKcal + fatKcal }

    /// Normalized fractions of calories from each macro (0…1 each), sums to 1 when `totalMacroKcal > 0`.
    var fractions: (protein: Double, carbs: Double, fat: Double) {
        let t = totalMacroKcal
        guard t > 0 else { return (0, 0, 0) }
        return (proteinKcal / t, carbKcal / t, fatKcal / t)
    }
}

// MARK: - Disclaimer

/// Server disclaimer (if any) plus a fixed estimate notice shown under nutrition content.
struct NutritionEstimateDisclaimerBlock: View {
    let serverDisclaimer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            if let serverDisclaimer, !serverDisclaimer.isEmpty {
                Text(serverDisclaimer)
                    .font(.pantryCaption2)
                    .foregroundColor(.pantryTextSecondary.opacity(0.95))
            }
            Text("Nutrition values are estimates only. They are not a substitute for professional dietary advice.")
                .font(.pantryCaption2)
                .foregroundColor(.pantryTextSecondary.opacity(0.9))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, DesignTokens.spacingSM)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Loading placeholder (matches loaded card geometry)

private struct NutritionShimmerFill<S: Shape>: View {
    let shape: S
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 24)) { context in
            let opacity: Double = {
                if reduceMotion { return 0.2 }
                let t = context.date.timeIntervalSinceReferenceDate
                return 0.12 + 0.1 * (0.5 + 0.5 * sin(t * 2.6))
            }()
            shape.fill(Color.pantryTextSecondary.opacity(opacity))
        }
    }
}

/// Skeleton layout aligned with ``NutritionEstimateRichLayout`` (energy, fiber/sodium, macro rows with bars).
struct NutritionEstimateLoadingPlaceholder: View {
    var compact: Bool = false
    /// Mirrors ``NutritionEstimateRichLayout/heroSubtitle`` (e.g. ``"Per serving"``) for the energy line shimmer.
    var heroSubtitle: String? = nil
    /// Larger energy shimmer; fiber/sodium rows before macros (recipe detail).
    var prominentEnergyAndFiberSodium: Bool = false

    private var barHeight: CGFloat { compact ? 8 : 10 }
    private var macroIconBox: CGFloat { compact ? 28 : 32 }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            energyRowPlaceholder
            if prominentEnergyAndFiberSodium {
                simpleRowPlaceholders
            }
            macroRowsPlaceholder
            if !prominentEnergyAndFiberSodium {
                simpleRowPlaceholders
            }
        }
        .accessibilityLabel("Loading nutritional information")
    }

    private var energyRowPlaceholder: some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.pantryTextSecondary.opacity(0.1))
                .frame(width: macroIconBox, height: macroIconBox)
            NutritionShimmerFill(shape: Capsule())
                .frame(width: 64, height: compact ? 14 : 16)
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: 6) {
                NutritionShimmerFill(shape: Capsule())
                    .frame(width: compact ? 72 : 80, height: compact ? 20 : 22)
                if prominentEnergyAndFiberSodium {
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: compact ? 64 : 72, height: 12)
                }
            }
        }
        .padding(.vertical, DesignTokens.spacingXS)
    }

    private var macroRowsPlaceholder: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: DesignTokens.spacingSM) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.pantryTextSecondary.opacity(0.1))
                        .frame(width: macroIconBox, height: macroIconBox)
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: compact ? 52 : 58, height: 12)
                    GeometryReader { geo in
                        let widths: [CGFloat] = [0.42, 0.62, 0.28]
                        let w = max(4, geo.size.width * widths[i])
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.pantryBorderSubtle.opacity(0.35))
                            NutritionShimmerFill(shape: Capsule())
                                .frame(width: w, height: barHeight)
                        }
                    }
                    .frame(height: barHeight)
                    .frame(maxWidth: .infinity)
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: 32, height: 12)
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: 44, height: 14)
                }
                .padding(.vertical, DesignTokens.spacingXS)
            }
        }
    }

    private var simpleRowPlaceholders: some View {
        VStack(spacing: prominentEnergyAndFiberSodium ? DesignTokens.spacingXS : DesignTokens.spacingSM) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.pantryTextSecondary.opacity(0.1))
                        .frame(
                            width: prominentEnergyAndFiberSodium ? macroIconBox : 18,
                            height: prominentEnergyAndFiberSodium ? macroIconBox : 18
                        )
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: prominentEnergyAndFiberSodium ? 52 : 48, height: prominentEnergyAndFiberSodium ? 14 : 12)
                    Spacer(minLength: 8)
                    NutritionShimmerFill(shape: Capsule())
                        .frame(width: prominentEnergyAndFiberSodium ? 58 : 52, height: prominentEnergyAndFiberSodium ? 16 : 14)
                }
                .padding(.vertical, DesignTokens.spacingXS)
            }
        }
    }
}

// MARK: - Pro gate (recipe detail)

/// Pro copy and a CTA that opens the upgrade paywall (non‑Pro recipe detail).
struct NutritionEstimateProLockedCard: View {
    var compact: Bool = false
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "crown.fill")
                    .font(.pantryCustom(size: DesignTokens.iconMedium, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pantrySecondary, Color.orange.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Pro feature")
                    .font(compact ? .pantrySubheadline : .pantryBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
            }

            Text("Unlock per-serving nutrition estimates—calories, macros, and more—for every recipe.")
                .font(.pantryCaption)
                .foregroundColor(.pantryTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticFeedback.light()
                onUnlock()
            } label: {
                Text("Unlock with Pro")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pantryPrimary)
        }
        .padding(DesignTokens.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)
                .fill(Color.pantryPrimary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)
                .stroke(Color.pantryBorderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Rich layout

/// Nutrition card: energy (+ optional fiber/sodium block), macro rows with per-macro share bars, disclaimer.
struct NutritionEstimateRichLayout: View {
    let result: PantryNutritionResult
    /// Tighter typography for macro rows on recipe detail.
    var compact: Bool = false
    /// When set (e.g. ``"Per serving"``), appended after kcal on the energy line (e.g. ``"374 kcal per serving"``).
    var heroSubtitle: String? = nil
    /// Larger energy row; fiber and sodium directly beneath, matched sizes (recipe detail layout).
    var prominentEnergyAndFiberSodium: Bool = false

    private var totals: PantryNutritionTotals { result.totals }
    private var energy: MacroEnergyModel { MacroEnergyModel(totals: totals) }

    private var labelFont: Font { compact ? .pantrySubheadline : .pantryBody }
    private var valueFont: Font { compact ? .pantrySubheadline : .pantryBody }

    private var macroIconSize: CGFloat { compact ? 28 : 32 }
    private var macroSymbolPointSize: CGFloat { compact ? 14 : 16 }
    private var macroBarHeight: CGFloat { compact ? 8 : 10 }

    private var labelColumnWidth: CGFloat { compact ? 58 : 64 }

    /// Leading column width for energy / fiber / sodium icons — matches macro row icon boxes for horizontal alignment.
    private var leadingIconColumnWidth: CGFloat { macroIconSize }
    /// Same point size as macro row symbols so flame, fiber, and sodium align visually with protein/carbs/fat.
    private var rowLeadingIconFont: Font { .pantryCustom(size: macroSymbolPointSize, weight: .semibold) }

    private var fiberSodiumLabelFont: Font { .pantrySubheadline.weight(.semibold) }
    private var fiberSodiumValueFont: Font { .pantrySubheadline.weight(.semibold) }

    private var energyKcalFont: Font { .pantryTitle2.weight(.semibold) }
    private var energyServingCaptionFont: Font { .pantryCaption2 }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            energyRow
            if prominentEnergyAndFiberSodium {
                secondaryMetricsSection
            }
            macroRowsSection
            if !prominentEnergyAndFiberSodium {
                secondaryMetricsSection
            }
            NutritionEstimateDisclaimerBlock(
                serverDisclaimer: result.disclaimer.isEmpty ? nil : result.disclaimer
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var energyRow: some View {
        let calStr = PantryNutritionFormatting.formatOptionalDouble(totals.caloriesKcal, caloriesStyle: true)
        let subtitleRaw = heroSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subtitle = subtitleRaw.isEmpty ? nil : subtitleRaw.lowercased()
        let energyTitleFont = prominentEnergyAndFiberSodium ? fiberSodiumLabelFont : labelFont.weight(.semibold)

        return HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
            Image(systemName: "flame.fill")
                .font(rowLeadingIconFont)
                .foregroundStyle(
                    LinearGradient(
                        colors: [NutritionMacroColors.carbs, Color.pantrySecondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: leadingIconColumnWidth, height: leadingIconColumnWidth, alignment: .center)

            Text("Energy")
                .font(energyTitleFont)
                .foregroundColor(.pantryTextPrimary)

            Spacer(minLength: DesignTokens.spacingSM)

            Group {
                if calStr == "—" {
                    Text("—")
                        .font(valueFont)
                        .fontWeight(.semibold)
                        .foregroundColor(.pantryTextPrimary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(calStr) kcal")
                            .font(energyKcalFont)
                            .foregroundColor(.pantryTextPrimary)
                        if let subtitle {
                            Text(subtitle)
                                .font(energyServingCaptionFont)
                                .foregroundColor(.pantryTextSecondary)
                        }
                    }
                    .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, DesignTokens.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(energyAccessibilityLabel(caloriesFormatted: calStr))
    }

    private func energyRightLine(caloriesFormatted: String) -> String {
        let trimmed = heroSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return "\(caloriesFormatted) kcal"
        }
        return "\(caloriesFormatted) kcal \(trimmed.lowercased())"
    }

    private func energyAccessibilityLabel(caloriesFormatted: String) -> String {
        if caloriesFormatted == "—" {
            return "Energy unavailable"
        }
        return "Energy, \(energyRightLine(caloriesFormatted: caloriesFormatted))"
    }

    private var macroRowsSection: some View {
        let f = energy.fractions
        let hasData = energy.totalMacroKcal > 0

        return VStack(spacing: DesignTokens.spacingSM) {
            macroRow(
                icon: "figure.strengthtraining.traditional",
                title: "Protein",
                tint: NutritionMacroColors.protein,
                fraction: f.protein,
                gramsValue: PantryNutritionFormatting.formatOptionalDouble(totals.proteinG),
                unit: "g",
                hasMacroData: hasData
            )
            macroRow(
                icon: "leaf.fill",
                title: "Carbs",
                tint: NutritionMacroColors.carbs,
                fraction: f.carbs,
                gramsValue: PantryNutritionFormatting.formatOptionalDouble(totals.carbohydrateG),
                unit: "g",
                hasMacroData: hasData
            )
            macroRow(
                icon: "drop.fill",
                title: "Fat",
                tint: NutritionMacroColors.fat,
                fraction: f.fat,
                gramsValue: PantryNutritionFormatting.formatOptionalDouble(totals.fatG),
                unit: "g",
                hasMacroData: hasData
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func macroRow(
        icon: String,
        title: String,
        tint: Color,
        fraction: Double,
        gramsValue: String,
        unit: String,
        hasMacroData: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: macroIconSize, height: macroIconSize)
                Image(systemName: icon)
                    .font(.pantryCustom(size: macroSymbolPointSize, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(title)
                .font(labelFont)
                .fontWeight(.semibold)
                .foregroundColor(.pantryTextPrimary)
                .lineLimit(1)
                .frame(minWidth: labelColumnWidth, alignment: .leading)

            macroFractionBar(fraction: fraction, tint: tint, hasMacroData: hasMacroData)
                .frame(height: macroBarHeight)
                .frame(maxWidth: .infinity)

            Group {
                if hasMacroData {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.pantryCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.pantryTextPrimary)
                } else {
                    Text("—")
                        .font(.pantryCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.pantryTextSecondary)
                }
            }
            .frame(minWidth: 38, alignment: .trailing)
            .monospacedDigit()

            Group {
                if gramsValue == "—" {
                    Text("—")
                } else {
                    (Text(gramsValue)
                        .fontWeight(.semibold)
                    + Text(" \(unit)")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary))
                }
            }
            .font(valueFont)
            .foregroundColor(.pantryTextPrimary)
            .frame(minWidth: 56, alignment: .trailing)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DesignTokens.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(macroRowAccessibility(title: title, fraction: fraction, gramsValue: gramsValue, unit: unit, hasMacroData: hasMacroData))
    }

    private func macroFractionBar(fraction: Double, tint: Color, hasMacroData: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW: CGFloat = {
                guard hasMacroData, fraction > 0, w > 0 else { return 0 }
                return min(w, max(4, w * CGFloat(fraction)))
            }()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.pantryBorderSubtle.opacity(0.4))
                if fillW > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: fillW)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func macroRowAccessibility(title: String, fraction: Double, gramsValue: String, unit: String, hasMacroData: Bool) -> String {
        if gramsValue == "—" {
            return "\(title), amount unavailable"
        }
        let pct = hasMacroData ? "\(Int((fraction * 100).rounded())) percent of calories from macros" : "percent unavailable"
        return "\(title), \(gramsValue) \(unit), \(pct)"
    }

    private var secondaryMetricsSection: some View {
        VStack(spacing: prominentEnergyAndFiberSodium ? DesignTokens.spacingXS : DesignTokens.spacingSM) {
            simpleNutrientRow(
                icon: "circle.hexagongrid.fill",
                title: "Fiber",
                tint: NutritionMacroColors.fiber,
                value: PantryNutritionFormatting.formatOptionalDouble(totals.fiberG),
                unit: "g"
            )
            simpleNutrientRow(
                icon: "flask.fill",
                title: "Sodium",
                tint: NutritionMacroColors.sodium,
                value: PantryNutritionFormatting.formatOptionalDouble(totals.sodiumMg),
                unit: "mg"
            )
        }
    }

    private func simpleNutrientRow(icon: String, title: String, tint: Color, value: String, unit: String) -> some View {
        let iconFont = prominentEnergyAndFiberSodium ? rowLeadingIconFont : .pantrySubheadline.weight(.semibold)
        let iconW: CGFloat = prominentEnergyAndFiberSodium ? leadingIconColumnWidth : 22
        let nameFont = prominentEnergyAndFiberSodium ? fiberSodiumLabelFont : labelFont.weight(.semibold)
        let amountFont = prominentEnergyAndFiberSodium ? fiberSodiumValueFont : valueFont.weight(.semibold)

        return HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
            Image(systemName: icon)
                .font(iconFont)
                .foregroundColor(tint)
                .frame(width: iconW, height: prominentEnergyAndFiberSodium ? leadingIconColumnWidth : nil, alignment: .center)

            Text(title)
                .font(nameFont)
                .foregroundColor(.pantryTextPrimary)

            Spacer(minLength: 8)

            Group {
                if value == "—" {
                    Text("—")
                } else {
                    (Text(value)
                        .fontWeight(.semibold)
                    + Text(" \(unit)")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary))
                }
            }
            .font(amountFont)
            .foregroundColor(.pantryTextPrimary)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DesignTokens.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(simpleRowAccessibility(title: title, value: value, unit: unit))
    }

    private func simpleRowAccessibility(title: String, value: String, unit: String) -> String {
        if value == "—" {
            return "\(title), unavailable"
        }
        return "\(title), \(value) \(unit)"
    }
}
