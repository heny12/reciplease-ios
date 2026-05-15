//
//  DesignTokens.swift
//  Reciplease
//
//  Created by Henry Chipman on 2/13/26.
//

import SwiftUI

/// Centralized design token system for consistent spacing, sizing, and styling
struct DesignTokens {
    // MARK: - Spacing
    
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    
    // MARK: - Border Radius
    
    static let radiusSmall: CGFloat = 12
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 20
    static let radiusXLarge: CGFloat = 24
    
    // MARK: - Shadows
    
    static let shadowSmall = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.1)
    static let shadowLarge = Color.black.opacity(0.15)
    
    static let shadowRadiusSmall: CGFloat = 4
    static let shadowRadiusMedium: CGFloat = 8
    static let shadowRadiusLarge: CGFloat = 12
    static let shadowRadiusXLarge: CGFloat = 16
    
    static let shadowOffsetSmall: CGFloat = 2
    static let shadowOffsetMedium: CGFloat = 4
    static let shadowOffsetLarge: CGFloat = 8
    
    // MARK: - Icon Sizes
    
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
    static let iconXLarge: CGFloat = 28
    
    // MARK: - Button Heights
    
    static let buttonHeightSmall: CGFloat = 40
    static let buttonHeightMedium: CGFloat = 48
    static let buttonHeightLarge: CGFloat = 56
    
    // MARK: - Animation
    
    static let animationFast: Double = 0.2
    static let animationMedium: Double = 0.3
    static let animationSlow: Double = 0.5
    
    static let springResponse: Double = 0.6
    static let springDamping: Double = 0.8
}
