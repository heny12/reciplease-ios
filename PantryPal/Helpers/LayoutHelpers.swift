//
//  LayoutHelpers.swift
//  PantryPal
//
//  Created by Henry Chipman on 2/12/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Helper struct for iPad-adaptive layout values
/// Now uses DesignTokens for consistency
struct LayoutHelpers {
    /// Horizontal padding that adapts to device type
    static var horizontalPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return DesignTokens.spacingXL // More padding on iPad
        }
        #endif
        return DesignTokens.spacingLG // Standard padding on iPhone
    }

    /// Wider side inset for orange slide-up sheets (Actions / Settings / Trial).
    static var quickActionSheetHorizontalPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 40
        }
        #endif
        return 28
    }
    
    /// Section spacing that adapts to device type
    static var sectionSpacing: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return DesignTokens.spacingXXL // More spacing on iPad
        }
        #endif
        return DesignTokens.spacingXL // Increased spacing on iPhone for better breathing room
    }
    
    /// Maximum content width for readability on iPad
    static var maxContentWidth: CGFloat? {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 700 // Constrain width on iPad for readability
        }
        #endif
        return nil // Full width on iPhone
    }
    
    /// Card padding that adapts to device type
    static var cardPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return DesignTokens.spacingLG
        }
        #endif
        return DesignTokens.spacingLG
    }
    
    /// Button spacing that adapts to device type
    static var buttonSpacing: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return DesignTokens.spacingMD
        }
        #endif
        return DesignTokens.spacingMD
    }
    
    /// Recipe tile image height that adapts to device type
    static var recipeTileImageHeight: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 240 // Larger on iPad for better visibility
        }
        #endif
        return 160 // Default for iPhone
    }
    
    /// Width of one column in the Recipes tab grid (16pt side padding, 12pt between columns).
    static func recipeGridTileWidth(containerWidth: CGFloat) -> CGFloat {
        let sideInset: CGFloat = 16
        let columnGap: CGFloat = 12
        return max(140, (containerWidth - 2 * sideInset - columnGap) / 2)
    }
    
    /// Same as ``recipeGridTileWidth(containerWidth:)`` using the main screen width (carousels).
    static var recipeGridTileWidthForScreen: CGFloat {
        #if canImport(UIKit)
        recipeGridTileWidth(containerWidth: UIScreen.main.bounds.width)
        #else
        200
        #endif
    }
    
    /// Recipe detail header image height that adapts to device type
    static var recipeDetailHeaderHeight: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 500 // Taller on iPad for more visual impact
        }
        #endif
        return 400 // Default for iPhone
    }
    
    /// Recipe detail content padding (smaller than general horizontal padding)
    static var recipeDetailContentPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 40 // More padding on iPad
        }
        #endif
        return 8 // Less padding on iPhone for more content space
    }
}
