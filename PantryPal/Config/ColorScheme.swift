//
//  ColorScheme.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI

extension Color {
    // Primary brand color - warm green (fresh produce)
    static let pantryPrimary = Color(red: 0.18, green: 0.62, blue: 0.38)
    
    // Secondary accent - warm orange (cooking energy)
    static let pantrySecondary = Color(red: 0.95, green: 0.55, blue: 0.18)

    /// Solid fill for quick-action (+) and more/settings menu sheets — same as brand orange.
    static let pantryQuickActionSheet = Color.pantrySecondary

    /// Solid fill for Generate Recipes slide-up sheet (brand green).
    static let pantryGenerateRecipeSheet = Color.pantryPrimary

    // Background - adapts to light/dark mode
    static let pantryBackground = Color(UIColor.systemBackground)
    
    // Surface - card/container backgrounds, adapts to light/dark mode
    static let pantrySurface = Color(UIColor.secondarySystemBackground)
    
    // Text colors - adaptive for light/dark mode
    static let pantryTextPrimary = Color(UIColor.label)
    static let pantryTextSecondary = Color(UIColor.secondaryLabel)

    /// Muted text on **fixed white** buttons (e.g. generate CTAs on green sheets). `secondaryLabel` tracks the system background, so in Dark Appearance it stays light and is nearly invisible on white.
    static let pantryOnWhiteCardSecondaryText = Color(red: 0.34, green: 0.37, blue: 0.41)
    
    // Success/Positive actions
    static let pantrySuccess = Color(red: 0.18, green: 0.65, blue: 0.38)
    
    // Warning/Attention
    static let pantryWarning = Color(red: 0.95, green: 0.7, blue: 0.0)
    
    // Error
    static let pantryError = Color(red: 0.85, green: 0.25, blue: 0.25)
    
    // Card shadow - adaptive
    static let pantryShadow = Color(UIColor.label).opacity(0.1)
    
    // Icon background - warm beige, adapts in dark mode
    static let pantryIconBackground = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.18, blue: 0.12, alpha: 1.0)
                : UIColor(red: 0.961, green: 0.941, blue: 0.820, alpha: 1.0)
        }
    )
    
    // Border colors for cards - adaptive
    static let pantryBorder = Color(UIColor.separator)
    static let pantryBorderSubtle = Color.pantryPrimary.opacity(0.08)
}

// MARK: - Shared full-screen backgrounds (paywall, cooking mode, splash, onboarding)

/// Layered cream + green + amber wash that stays on-brand but feels less flat than a single diagonal.
struct PantryImmersiveScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 1.05

            ZStack {
                // Base: warm field with a gentle shift from cream toward brand hues
                LinearGradient(
                    stops: [
                        .init(color: .pantryIconBackground, location: 0),
                        .init(color: Color.pantryIconBackground.opacity(isDark ? 0.95 : 0.99), location: 0.28),
                        .init(color: Color.pantryPrimary.opacity(isDark ? 0.08 : 0.045), location: 0.48),
                        .init(color: Color.pantrySecondary.opacity(isDark ? 0.055 : 0.035), location: 0.68),
                        .init(color: Color.pantryPrimary.opacity(isDark ? 0.12 : 0.08), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Soft “window light” — fresh green from upper leading
                RadialGradient(
                    colors: [
                        Color.pantryPrimary.opacity(isDark ? 0.22 : 0.14),
                        Color.pantryPrimary.opacity(isDark ? 0.07 : 0.045),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.08, y: 0.06),
                    startRadius: 4,
                    endRadius: r * 0.72
                )

                // Warm counter-light — secondary from lower trailing (kitchen / stove warmth)
                RadialGradient(
                    colors: [
                        Color.pantrySecondary.opacity(isDark ? 0.16 : 0.11),
                        Color.pantrySecondary.opacity(isDark ? 0.045 : 0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.92, y: 0.94),
                    startRadius: 8,
                    endRadius: r * 0.65
                )

                // Subtle depth: dark mode uses a soft black vignette; light mode uses a whisper of brand tint at edges
                LinearGradient(
                    stops: [
                        .init(color: isDark ? Color.black.opacity(0.22) : Color.pantryPrimary.opacity(0.035), location: 0),
                        .init(color: Color.clear, location: 0.4),
                        .init(color: Color.clear, location: 0.6),
                        .init(color: isDark ? Color.black.opacity(0.3) : Color.pantrySecondary.opacity(0.04), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

extension Recipe {
    var sourceBorderColor: Color? {
        switch sourceCategory {
        case .reciplease: return .pantryPrimary
        case .cookbook: return .pantrySecondary
        case .web: return .blue
        case .other: return nil
        }
    }
}

// MARK: - Typography System
//
// Standard: **SF Pro** (system default design) everywhere (SwiftUI + UIKit navigation bar).
// Use only `Font.pantry*` and `Font.pantryCustom` in views—avoid `.font(.body)`, `.title2`, raw `.system`, etc.

extension Font {
    static let pantryLargeTitle = Font.system(.largeTitle, design: .default)

    static let pantryTitle = Font.system(.title, design: .default)
    static let pantryTitle2 = Font.system(.title2, design: .default)
    static let pantryTitle3 = Font.system(.title3, design: .default)

    static let pantryHeadline = Font.system(.headline, design: .default)

    static let pantryBody = Font.system(.body, design: .default)

    static let pantrySubheadline = Font.system(.subheadline, design: .default)

    static let pantryCaption = Font.system(.caption, design: .default)
    static let pantryCaption2 = Font.system(.caption2, design: .default)

    static func pantryCustom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}
