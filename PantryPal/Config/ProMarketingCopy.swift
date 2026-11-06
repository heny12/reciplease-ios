//
//  ProMarketingCopy.swift
//  PantryPal
//
//  Single source of truth for Pro tier marketing (paywall + customer center).
//  Enforcement of limits is separate; this is advertising copy only.
//

import SwiftUI

/// Pro benefits shown on paywall and subscription management screens.
enum ProMarketingBenefit: CaseIterable, Identifiable {
    case scansAndGenerationsMonthly
    case unlimitedCookbooks
    case smartRecipeModification
    case perServingNutritionEstimates
    case higherMealPlanRecipeLimits

    var id: Self { self }

    var sfSymbolName: String {
        switch self {
        case .scansAndGenerationsMonthly:
            return "camera.viewfinder"
        case .unlimitedCookbooks:
            return "books.vertical.fill"
        case .smartRecipeModification:
            return "wand.and.stars"
        case .perServingNutritionEstimates:
            return "chart.bar.doc.horizontal"
        case .higherMealPlanRecipeLimits:
            return "calendar.badge.plus"
        }
    }

    var title: String {
        switch self {
        case .scansAndGenerationsMonthly:
            return ProMarketingCopy.proGenerationsAndImportsPerBillingPeriod
        case .unlimitedCookbooks:
            return "Unlimited Cookbooks"
        case .smartRecipeModification:
            return "Smart Recipe Modification"
        case .perServingNutritionEstimates:
            return ProMarketingCopy.perServingNutritionTitle
        case .higherMealPlanRecipeLimits:
            return ProMarketingCopy.higherMealPlanRecipeLimitsTitle
        }
    }

    /// Secondary line for benefits that need a short explanation.
    var subtitle: String? {
        switch self {
        case .smartRecipeModification:
            return "Servings, swaps, and tweaks tailored to what you have."
        case .scansAndGenerationsMonthly, .unlimitedCookbooks,
                .perServingNutritionEstimates, .higherMealPlanRecipeLimits:
            return nil
        }
    }
}

enum ProMarketingCopy {
    static let benefitsSectionTitle = "What's included with Pro"
    static let monthlyResetFootnote = "Generation limits reset each subscription billing period. Fridge and pantry scans stay free."

    /// Onboarding “Cook for Free” body; weekly cap from `TRIAL_MAX_INTERACTIONS` (e.g. 5 tokens).
    static var onboardingCookForFreeBody: String {
        let n = AppConfig.trialMaxInteractions
        return "Every week you get \(n) tokens for recipe generation, scanning cookbook pages, and importing recipes from the web. Scanning ingredients into your fridge or pantry is unlimited and always free."
    }

    static let onboardingRecipleaseProSectionTitle = "Reciplease Pro"

    static let onboardingUpgradeBridge =
        "For the full experience, upgrading to:"

    static let perServingNutritionTitle = "Per-Serving Nutrition Information"

    static var higherMealPlanRecipeLimitsTitle: String {
        let pro = AppConfig.maxMealPlanGenerateSlotsPro
        let free = AppConfig.maxMealPlanGenerateSlotsFree
        return "Higher Meal Planning Limits"
    }

    static let customerCenterIncludedTitle = "What's included"
    static let customerCenterUpgradeTitle = "Pro includes"

    // MARK: - Pro limit line (matches first row in “What’s included with Pro”; avoid duplicating the full list elsewhere)

    /// Pantry generate, cookbook scan, and web recipe import — cap from `PRO_MAX_INTERACTIONS`.
    static var proGenerationsAndImportsPerBillingPeriod: String {
        "Up to \(AppConfig.proMaxInteractions) recipe generations and imports per month"
    }
}

/// Shared benefit row: icon + title + optional caption (used by Paywall + Customer Center).
struct ProMarketingBenefitRow: View {
    let benefit: ProMarketingBenefit

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
            Image(systemName: benefit.sfSymbolName)
                .font(.pantryTitle3.weight(.semibold))
                .foregroundStyle(Color.pantryPrimary)
                .frame(minWidth: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(benefit.title)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = benefit.subtitle {
                    Text(subtitle)
                        .font(.pantrySubheadline)
                        .foregroundColor(.pantryTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Checkmark + title rows matching the paywall “Included” block (white on green sheets).
struct ProMarketingPaywallStyleBenefitsList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            ForEach(ProMarketingBenefit.allCases) { benefit in
                HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.pantryTitle3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .frame(minWidth: 28, alignment: .center)
                        .padding(.top, 2)
                    Text(benefit.title)
                        .font(.pantryBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Vertical list of all Pro benefits with dividers between items.
struct ProMarketingBenefitsList: View {
    var showFootnote: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ProMarketingBenefit.allCases.enumerated()), id: \.offset) { index, benefit in
                if index > 0 {
                    Divider()
                        .background(Color.pantryTextSecondary.opacity(0.15))
                        .padding(.vertical, DesignTokens.spacingSM)
                }
                ProMarketingBenefitRow(benefit: benefit)
            }

            if showFootnote {
                Text(ProMarketingCopy.monthlyResetFootnote)
                    .font(.pantryCaption)
                    .foregroundColor(.pantryTextSecondary.opacity(0.9))
                    .padding(.top, DesignTokens.spacingMD)
            }
        }
    }
}
