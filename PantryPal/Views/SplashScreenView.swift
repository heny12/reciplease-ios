//
//  SplashScreenView.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.pantryPrimary
                .ignoresSafeArea()

            RecipleaseSplashHero()
        }
    }
}

/// GIF + title + subtitle — shared by splash and onboarding welcome so layout matches across the transition.
struct RecipleaseSplashHero: View {
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            GIFView(name: "avi_camera_animated")
                .frame(width: 140, height: 140)

            VStack(spacing: DesignTokens.spacingSM) {
                Text("Reciplease")
                    .font(.pantryLargeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                Text("Your personal kitchen companion")
                    .font(.pantrySubheadline)
                    .foregroundColor(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignTokens.spacingXL)
    }
}
