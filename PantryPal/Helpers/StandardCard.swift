//
//  StandardCard.swift
//  Reciplease
//
//  Created by Henry Chipman on 2/13/26.
//

import SwiftUI

/// Standardized card component for consistent design across the app
struct StandardCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = DesignTokens.spacingLG
    var cornerRadius: CGFloat = DesignTokens.radiusLarge
    var showBorder: Bool = true
    var shadowStyle: ShadowStyle = .medium
    
    enum ShadowStyle {
        case none
        case small
        case medium
        case large
    }
    
    init(
        padding: CGFloat = DesignTokens.spacingLG,
        cornerRadius: CGFloat = DesignTokens.radiusLarge,
        showBorder: Bool = true,
        shadowStyle: ShadowStyle = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.shadowStyle = shadowStyle
        self.content = content()
    }
    
    private var shadowColor: Color {
        switch shadowStyle {
        case .none:
            return .clear
        case .small:
            return DesignTokens.shadowSmall
        case .medium:
            return DesignTokens.shadowMedium
        case .large:
            return DesignTokens.shadowLarge
        }
    }
    
    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .none:
            return 0
        case .small:
            return DesignTokens.shadowRadiusSmall
        case .medium:
            return DesignTokens.shadowRadiusMedium
        case .large:
            return DesignTokens.shadowRadiusLarge
        }
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color.pantrySurface)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: DesignTokens.shadowOffsetSmall
            )
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.pantryBorderSubtle, lineWidth: 1)
                    }
                }
            )
    }
}

/// Glassmorphism card variant
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = DesignTokens.spacingLG
    var cornerRadius: CGFloat = DesignTokens.radiusLarge
    
    init(
        padding: CGFloat = DesignTokens.spacingLG,
        cornerRadius: CGFloat = DesignTokens.radiusLarge,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.pantryPrimary.opacity(0.06),
                                        Color.pantrySecondary.opacity(0.04),
                                        Color.pantryPrimary.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.pantryPrimary.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: Color.pantryPrimary.opacity(0.12),
                radius: DesignTokens.shadowRadiusLarge,
                x: 0,
                y: DesignTokens.shadowOffsetMedium
            )
            .shadow(
                color: DesignTokens.shadowSmall,
                radius: DesignTokens.shadowRadiusSmall,
                x: 0,
                y: DesignTokens.shadowOffsetSmall
            )
    }
}
