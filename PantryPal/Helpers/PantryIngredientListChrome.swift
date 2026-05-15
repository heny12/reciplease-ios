//
//  PantryIngredientListChrome.swift
//  Shared metrics and leading emoji/icon column for pantry-style ingredient rows.
//

import SwiftUI

enum PantryIngredientListMetrics {
    static let rowHPadding: CGFloat = 12
    static let textVSpacing: CGFloat = 5
    static let rowVPadding: CGFloat = 12
    static let iconColumnWidth: CGFloat = 42
    static let emojiSize: CGFloat = 26
    /// Pantry status (in pantry / staple / need) column to the left of the ingredient emoji on recipe detail.
    static let recipePantryStatusColumnWidth: CGFloat = 30
}

struct IngredientPantryLeadingIcon: View {
    let icon: String
    /// When non-`nil` (e.g. green sheet), tints the symbol or emoji.
    var tint: Color? = nil

    var body: some View {
        let w = PantryIngredientListMetrics.iconColumnWidth
        let sz = PantryIngredientListMetrics.emojiSize
        Group {
            if icon.count == 1 {
                Text(icon)
                    .font(.pantryCustom(size: sz))
                    .foregroundStyle(tint ?? Color.primary)
            } else {
                Image(systemName: icon)
                    .font(.pantryTitle3.weight(.medium))
                    .foregroundStyle(tint ?? Color.pantryPrimary)
            }
        }
        .frame(width: w, alignment: .center)
    }
}
