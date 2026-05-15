//
//  StandardButtons.swift
//  Reciplease
//
//  Created by Henry Chipman on 2/13/26.
//

import SwiftUI

/// Primary button with gradient background
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                isPressed = true
            }
            HapticFeedback.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + DesignTokens.animationFast) {
                withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: DesignTokens.spacingSM) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.pantryCustom(size: DesignTokens.iconMedium, weight: .semibold))
                }
                Text(title)
                    .font(.pantryHeadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.buttonHeightMedium)
            .background(
                LinearGradient(
                    colors: [Color.pantryPrimary, Color.pantrySecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignTokens.radiusMedium)
            .shadow(
                color: Color.pantryPrimary.opacity(0.3),
                radius: DesignTokens.shadowRadiusMedium,
                x: 0,
                y: DesignTokens.shadowOffsetSmall
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Secondary button with subtle background
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, color: Color = .pantryPrimary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                isPressed = true
            }
            HapticFeedback.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + DesignTokens.animationFast) {
                withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: DesignTokens.spacingSM) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.pantryCustom(size: DesignTokens.iconMedium, weight: .medium))
                }
                Text(title)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.buttonHeightMedium)
            .background(color.opacity(0.08))
            .cornerRadius(DesignTokens.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Tertiary text-only button
struct TertiaryButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                isPressed = true
            }
            HapticFeedback.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + DesignTokens.animationFast) {
                withAnimation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Text(title)
                .font(.pantrySubheadline)
                .fontWeight(.medium)
                .foregroundColor(.pantryPrimary)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
