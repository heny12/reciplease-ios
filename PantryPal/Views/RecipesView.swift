//
//  RecipesView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI

// MARK: - Filter Types

enum TimeFilter: String, CaseIterable {
    case all = "All"
    case quick = "<15m"
    case medium = "15-30m"
    case long = ">30m"
    
    func matches(totalTime: Int?) -> Bool {
        guard let time = totalTime else { return self == .all }
        switch self {
        case .all: return true
        case .quick: return time < 15
        case .medium: return time >= 15 && time <= 30
        case .long: return time > 30
        }
    }
}

enum IngredientsFilter: String, CaseIterable {
    case all = "All"
    case few = "≤5"
    case medium = "6-10"
    case many = ">10"
    
    func matches(count: Int) -> Bool {
        switch self {
        case .all: return true
        case .few: return count <= 5
        case .medium: return count >= 6 && count <= 10
        case .many: return count > 10
        }
    }
}

enum DifficultyFilter: String, CaseIterable {
    case all = "All"
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    func matches(difficulty: Int?) -> Bool {
        guard let diff = difficulty else { return self == .all }
        switch self {
        case .all: return true
        case .easy: return diff <= 2
        case .medium: return diff == 3
        case .hard: return diff >= 4
        }
    }
}

/// Filters recipes by pantry match score (0.0–1.0). Buckets are non-overlapping except `.all`.
enum PantryMatchFilter: String, CaseIterable {
    case all = "All"
    case high = "75%+"
    case medium = "50–74%"
    case fair = "25–49%"
    case low = "<25%"
    
    func matches(score: Double) -> Bool {
        let s = min(max(score, 0), 1)
        switch self {
        case .all: return true
        case .high: return s >= 0.75
        case .medium: return s >= 0.5 && s < 0.75
        case .fair: return s >= 0.25 && s < 0.5
        case .low: return s < 0.25
        }
    }
}

enum SourceTypeFilter: String, CaseIterable {
    case all = "All"
    case reciplease = "Reciplease"
    case cookbook = "Cookbook"
    case web = "Web"
    case other = "Other"
    
    func matches(category: RecipeSourceCategory) -> Bool {
        switch self {
        case .all: return true
        case .reciplease: return category == .reciplease
        case .cookbook: return category == .cookbook
        case .web: return category == .web
        case .other: return category == .other
        }
    }
}

// MARK: - Recipe grid layout (Recipes tab + onboarding demo)

enum RecipeGridLayout {
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 8

    /// `minimum: 0` keeps two columns correct when the grid is inside a narrow container (e.g. onboarding demo card).
    static var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: columnSpacing),
            GridItem(.flexible(minimum: 0), spacing: columnSpacing)
        ]
    }
}

// MARK: - Filter Row

struct FilterRow<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String {
    let title: String
    let icon: String
    let options: [T]
    @Binding var selected: T
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.pantryCaption2)
                    .foregroundColor(.pantryTextSecondary)
                Text(title)
                    .font(.pantryCaption)
                    .fontWeight(.medium)
                    .foregroundColor(.pantryTextSecondary)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    FilterChip(
                        title: option.rawValue,
                        isSelected: selected == option
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = option
                        }
                        HapticFeedback.light()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pantryCaption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .pantryTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ?
                    AnyShapeStyle(LinearGradient(colors: [Color.pantryPrimary, Color.pantryPrimary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)) :
                    AnyShapeStyle(Color.pantrySurface)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color.pantryTextSecondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recipe Grid Card

struct RecipeGridCard: View {
    let recipe: Recipe
    let pantryMatchScore: Double
    let isFavorite: Bool
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    /// When false, only the pantry match ring is shown on the image (for carousels / navigation-only tiles).
    var showsOverlayActions: Bool = true
    
    // Calculate total time
    private var totalTime: Int? {
        if let prep = recipe.prepTimeMinutes, let cook = recipe.cookTimeMinutes {
            return prep + cook
        } else if let prep = recipe.prepTimeMinutes {
            return prep
        } else if let cook = recipe.cookTimeMinutes {
            return cook
        }
        return nil
    }
    
    private var recipeTileImageHeight: CGFloat {
        LayoutHelpers.recipeTileImageHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay buttons — fixed cell footprint so async decode can't widen the tile.
            ZStack(alignment: .topLeading) {
                Group {
                    if recipe.isGeneratingImage {
                        RecipeGridImageSkeleton()
                    } else if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: recipeTileImageHeight, maxHeight: recipeTileImageHeight)
                                .clipped()
                        } placeholder: {
                            RecipeGridImageSkeleton()
                        }
                    } else {
                        RecipeGridPlaceholderImage()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: recipeTileImageHeight, maxHeight: recipeTileImageHeight)
                .clipped()
                
                // Overlay: match score + optional delete / bookmark
                VStack {
                    HStack {
                        PantryMatchScoreBadge(score: pantryMatchScore)
                        Spacer()
                        if showsOverlayActions {
                            Button(action: {
                                HapticFeedback.light()
                                onDelete()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                        )
                                        .frame(width: DesignTokens.iconLarge, height: DesignTokens.iconLarge)
                                    
                                    Image(systemName: "xmark")
                                        .font(.pantryCustom(size: DesignTokens.iconSmall, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(8)
                        }
                    }
                    
                    Spacer()
                    
                    if showsOverlayActions {
                        HStack {
                            Spacer()
                            Button(action: {
                                HapticFeedback.light()
                                onToggleFavorite()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .fill(isFavorite ? Color.pantrySecondary.opacity(0.8) : Color.black.opacity(0.5))
                                        )
                                        .frame(width: DesignTokens.iconLarge, height: DesignTokens.iconLarge)
                                    
                                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                                        .font(.pantryCustom(size: DesignTokens.iconSmall, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: recipeTileImageHeight, maxHeight: recipeTileImageHeight)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: DesignTokens.radiusMedium, topTrailingRadius: DesignTokens.radiusMedium))

            if let indicatorColor = recipe.sourceBorderColor {
                Rectangle()
                    .fill(indicatorColor)
                    .frame(height: 3)
            }
            
            // Content below image
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Title
                Text(recipe.name)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata icons
                HStack(spacing: DesignTokens.spacingSM) {
                    MetadataIcon(icon: "basket.fill", text: "\(recipe.ingredients.count)", color: .pantryPrimary)
                    MetadataIcon(icon: "list.number", text: "\(recipe.steps.count)", color: .pantrySecondary)
                    
                    if let time = totalTime {
                        MetadataIcon(icon: "clock.fill", text: "\(time)m", color: .orange)
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.pantrySurface)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 16
        ))
        .shadow(color: Color.pantryShadow.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private struct PantryMatchScoreBadge: View {
    let score: Double

    private var clampedScore: Double {
        min(max(score, 0), 1)
    }

    private var percentageText: String {
        String(Int((clampedScore * 100).rounded()))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 34, height: 34)

            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                .frame(width: 34, height: 34)

            Circle()
                .trim(from: 0, to: clampedScore)
                .stroke(
                    Color.pantryPrimary,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 34, height: 34)

            Text(percentageText)
                .font(.pantryCustom(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(8)
    }
}

// MARK: - Recipe list row (minimal vertical list)

private enum RecipeListRowMetrics {
    static let thumbnail: CGFloat = 84
    static let cornerRadius: CGFloat = 8
    static let spacing: CGFloat = 12
}

struct RecipeRowContent: View {
    let recipe: Recipe
    /// List `NavigationLink` rows use the system indicator; keep false to avoid a duplicate chevron.
    var showChevron: Bool = false
    /// When set (e.g. pantry matches), shown as the metadata line instead of time | source.
    var pantryMatchMetadataLine: String? = nil
    /// When set (and `pantryMatchMetadataLine` is nil), third line shows ingredient count and this pantry match score.
    var pantryMatchScore: Double? = nil

    private var totalTime: Int? {
        if let prep = recipe.prepTimeMinutes, let cook = recipe.cookTimeMinutes {
            return prep + cook
        } else if let prep = recipe.prepTimeMinutes {
            return prep
        } else if let cook = recipe.cookTimeMinutes {
            return cook
        }
        return nil
    }

    private var sourceDisplay: String? {
        if let urlStr = recipe.source?.url,
           let url = URL(string: urlStr) {
            let host = url.host?
                .replacingOccurrences(of: "www.", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let host, !host.isEmpty {
                return host
            }
        }
        let name = recipe.source?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return nil
    }

    private var fallbackSourceLabel: String {
        switch recipe.sourceCategory {
        case .reciplease: return "Reciplease"
        case .cookbook: return "Cookbook"
        case .web: return "Web"
        case .other: return "Recipe"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: RecipeListRowMetrics.spacing) {
            recipeThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.pantryBody)
                    .fontWeight(.regular)
                    .foregroundColor(.pantryTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                metadataRow

                if pantryMatchMetadataLine == nil {
                    recipeSummaryLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.pantryCaption.weight(.semibold))
                    .foregroundColor(.pantryTextSecondary.opacity(0.35))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func pantryMatchPercent(for score: Double) -> Int {
        Int((min(max(score, 0), 1) * 100).rounded())
    }

    @ViewBuilder
    private var recipeSummaryLine: some View {
        let count = recipe.ingredients.count
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "basket.fill")
                    .font(.pantryCaption2.weight(.medium))
                Text("\(count)")
            }
            if let score = pantryMatchScore {
                Text("·")
                    .foregroundColor(.pantryTextSecondary.opacity(0.45))
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle")
                        .font(.pantryCaption2.weight(.medium))
                    Text("\(pantryMatchPercent(for: score))% pantry match")
                }
            }
        }
        .font(.pantryCaption)
        .foregroundColor(.pantryTextSecondary.opacity(0.92))
        .lineLimit(1)
    }

    @ViewBuilder
    private var recipeThumbnail: some View {
        let s = RecipeListRowMetrics.thumbnail
        let r = RecipeListRowMetrics.cornerRadius
        Group {
            if recipe.isGeneratingImage {
                RecipeImageSkeleton(size: s, cornerRadius: r)
            } else if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: s, height: s)
                        .clipShape(RoundedRectangle(cornerRadius: r))
                } placeholder: {
                    RecipeImageSkeleton(size: s, cornerRadius: r)
                }
            } else {
                RecipePlaceholderImage(size: s, cornerRadius: r)
            }
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder
    private var metadataRow: some View {
        if let pantryLine = pantryMatchMetadataLine, !pantryLine.isEmpty {
            Text(pantryLine)
                .font(.pantryCaption)
                .foregroundColor(.pantryTextSecondary)
                .lineLimit(1)
        } else {
            HStack(spacing: 6) {
                if let time = totalTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.pantryCaption2.weight(.medium))
                        Text("\(time) min")
                    }

                    Text("|")
                        .font(.pantryCaption2)
                        .foregroundColor(.pantryTextSecondary.opacity(0.45))
                }

                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.pantryCaption2.weight(.medium))
                    Text(sourceDisplay ?? fallbackSourceLabel)
                        .lineLimit(1)
                }
            }
            .font(.pantryCaption)
            .foregroundColor(.pantryTextSecondary)
        }
    }
}

// MARK: - Supporting Views

struct RecipePlaceholderImage: View {
    var size: CGFloat = 90
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.pantryPrimary.opacity(0.1), Color.pantrySecondary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: "fork.knife")
                .font(.pantryCustom(size: max(22, size * 0.35), weight: .medium))
                .foregroundColor(.pantryPrimary.opacity(0.4))
        }
    }
}

struct RecipeImageSkeleton: View {
    var size: CGFloat = 90
    var cornerRadius: CGFloat = 12

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.pantryTextSecondary.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: -size + (phase * size * 2))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

struct MetadataBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.pantryCaption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(text)
                .font(.pantryCaption2)
                .fontWeight(.medium)
                .foregroundColor(.pantryTextSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Grid Card Supporting Views

struct RecipeGridImageSkeleton: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.pantryTextSecondary.opacity(0.12))
            .frame(maxWidth: .infinity, minHeight: LayoutHelpers.recipeTileImageHeight, maxHeight: LayoutHelpers.recipeTileImageHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: -200 + (phase * 400))
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

struct RecipeGridPlaceholderImage: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [Color.pantryPrimary.opacity(0.1), Color.pantrySecondary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, minHeight: LayoutHelpers.recipeTileImageHeight, maxHeight: LayoutHelpers.recipeTileImageHeight)
            
            Image(systemName: "fork.knife")
                .font(.pantryTitle)
                .foregroundColor(.pantryPrimary.opacity(0.4))
        }
    }
}

struct MetadataIcon: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.pantryCaption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(text)
                .font(.pantryCaption2)
                .fontWeight(.medium)
                .foregroundColor(.pantryTextSecondary)
        }
    }
}

struct RecipeStepRow: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.pantryCaption)
                .foregroundColor(.pantryPrimary)
                .frame(width: 20)
            
            Text("\(title): \(description)")
                            .font(.pantrySubheadline)
                .foregroundColor(.pantryTextSecondary)
        }
    }
}

// Legacy compatibility
struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        RecipeRowContent(recipe: recipe)
    }
}

struct SourceLegendPill: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 4)

            Text(label)
                .font(.pantryCaption2)
                .foregroundColor(.pantryTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.pantrySurface)
        .clipShape(Capsule())
    }
}

/// Source color key used on Recipes and cookbook detail grids.
struct RecipeSourceIndicatorLegend: View {
    var horizontalPadding: CGFloat = 16

    var body: some View {
        FlowLayout(spacing: 10) {
            SourceLegendPill(color: .pantryPrimary, label: "Reciplease")
            SourceLegendPill(color: .pantrySecondary, label: "Cookbook")
            SourceLegendPill(color: .blue, label: "Web")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        CookbooksView(viewModel: PantryViewModel())
    }
}
