//
//  SkeletonView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/27/26.
//

import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

struct SkeletonRectangle: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.pantryTextSecondary.opacity(0.15))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color.pantryTextSecondary.opacity(0.15))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Recipe Card Skeleton

struct RecipeCardSkeleton: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Image placeholder
            SkeletonRectangle(width: 90, height: 90, cornerRadius: 12)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonRectangle(height: 18, cornerRadius: 4)
                
                // Description lines
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonRectangle(height: 14, cornerRadius: 4)
                    SkeletonRectangle(width: 180, height: 14, cornerRadius: 4)
                }
                
                // Metadata badges
                HStack(spacing: 10) {
                    SkeletonRectangle(width: 50, height: 24, cornerRadius: 8)
                    SkeletonRectangle(width: 50, height: 24, cornerRadius: 8)
                    SkeletonRectangle(width: 55, height: 24, cornerRadius: 8)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.pantrySurface)
        .cornerRadius(16)
        .shadow(color: Color.pantryShadow.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Recipe List Skeleton

struct RecipeListSkeleton: View {
    var count: Int = 4
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                RecipeCardSkeleton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Ingredient Row Skeleton

struct IngredientRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            SkeletonCircle(size: 48)
            
            // Name and details
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRectangle(width: 120, height: 16, cornerRadius: 4)
                SkeletonRectangle(width: 80, height: 12, cornerRadius: 4)
            }
            
            Spacer()
            
            // Quantity badge
            SkeletonRectangle(width: 60, height: 28, cornerRadius: 10)
            
            // Chevron placeholder
            SkeletonRectangle(width: 8, height: 14, cornerRadius: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.pantrySurface)
        .cornerRadius(14)
    }
}

// MARK: - Ingredient List Skeleton

struct IngredientListSkeleton: View {
    var count: Int = 5
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                IngredientRowSkeleton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Photo Grid Skeleton

struct PhotoGridSkeleton: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonRectangle(height: 150, cornerRadius: 12)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Recipe Detail Skeleton

struct RecipeDetailSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header image
            SkeletonRectangle(height: 300, cornerRadius: 0)
            
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title and description
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRectangle(width: 250, height: 28, cornerRadius: 6)
                    SkeletonRectangle(height: 16, cornerRadius: 4)
                    SkeletonRectangle(width: 200, height: 16, cornerRadius: 4)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Stats row
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(spacing: 8) {
                            SkeletonCircle(size: 44)
                            SkeletonRectangle(width: 40, height: 12, cornerRadius: 4)
                            SkeletonRectangle(width: 60, height: 10, cornerRadius: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.pantrySurface)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Ingredients section
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRectangle(width: 120, height: 24, cornerRadius: 4)
                        .padding(.horizontal)
                    
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 12) {
                            SkeletonCircle(size: 28)
                            SkeletonRectangle(width: 150, height: 16, cornerRadius: 4)
                            Spacer()
                            SkeletonRectangle(width: 60, height: 24, cornerRadius: 8)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Steps section
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRectangle(width: 100, height: 24, cornerRadius: 4)
                        .padding(.horizontal)
                    
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(alignment: .top, spacing: 16) {
                            SkeletonCircle(size: 32)
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonRectangle(height: 16, cornerRadius: 4)
                                SkeletonRectangle(width: 200, height: 16, cornerRadius: 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color.pantryBackground)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
            )
            .offset(y: -24)
        }
    }
}

// MARK: - Loading State Wrapper

struct SkeletonLoadingView<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let skeleton: () -> Skeleton
    
    init(
        isLoading: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder skeleton: @escaping () -> Skeleton
    ) {
        self.isLoading = isLoading
        self.content = content
        self.skeleton = skeleton
    }
    
    var body: some View {
        if isLoading {
            skeleton()
        } else {
            content()
        }
    }
}

// MARK: - Previews

#Preview("Recipe Card Skeleton") {
    VStack {
        RecipeCardSkeleton()
        RecipeCardSkeleton()
    }
    .padding()
}

#Preview("Recipe List Skeleton") {
    ScrollView {
        RecipeListSkeleton()
    }
}

#Preview("Ingredient Row Skeleton") {
    VStack {
        IngredientRowSkeleton()
        IngredientRowSkeleton()
        IngredientRowSkeleton()
    }
    .padding()
}

#Preview("Recipe Detail Skeleton") {
    ScrollView {
        RecipeDetailSkeleton()
    }
}
