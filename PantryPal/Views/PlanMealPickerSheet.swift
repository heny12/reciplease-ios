//
//  PlanMealPickerSheet.swift
//  Cookbook → recipe picker as a centered “bubble” over the Plan tab.
//

import SwiftUI

// MARK: - Shared thumbnails

struct PlanSmallRecipeThumbnail: View {
    let recipe: Recipe
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.pantrySurface)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary.opacity(0.5))
                        }
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.pantrySurface)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.pantryTitle3)
                            .foregroundColor(.pantryTextSecondary.opacity(0.45))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlanCookbookPickerThumbnail: View {
    @ObservedObject var viewModel: PantryViewModel
    let cookbook: Cookbook
    var size: CGFloat = 52

    private var previewRecipes: [Recipe] {
        Array(viewModel.recipes(for: cookbook.id).prefix(4))
    }

    var body: some View {
        Group {
            if previewRecipes.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.pantrySurface)
                    .overlay {
                        Image(systemName: "books.vertical")
                            .font(.pantryTitle3)
                            .foregroundColor(.pantryTextSecondary.opacity(0.45))
                    }
            } else if previewRecipes.count == 1 {
                PlanSmallRecipeThumbnail(recipe: previewRecipes[0], size: size)
            } else {
                let gap: CGFloat = 2
                let cell = (size - gap) / 2
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        thumbCell(previewRecipes[safe: 0], cell: cell)
                        thumbCell(previewRecipes[safe: 1], cell: cell)
                    }
                    HStack(spacing: gap) {
                        thumbCell(previewRecipes[safe: 2], cell: cell)
                        thumbCell(previewRecipes[safe: 3], cell: cell)
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func thumbCell(_ recipe: Recipe?, cell: CGFloat) -> some View {
        if let recipe {
            if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.pantrySecondary.opacity(0.12))
                }
                .frame(width: cell, height: cell)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.pantrySecondary.opacity(0.12))
                    .frame(width: cell, height: cell)
            }
        } else {
            Rectangle()
                .fill(Color.pantrySecondary.opacity(0.08))
                .frame(width: cell, height: cell)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Bubble overlay picker

struct PlanMealPickerBubble: View {
    @ObservedObject var viewModel: PantryViewModel
    let dayKey: String
    let slot: MealPlanSlot
    var onDismiss: () -> Void

    @State private var selectedCookbookId: UUID?

    private var selectedCookbookName: String {
        viewModel.cookbooks.first(where: { $0.id == selectedCookbookId })?.name ?? ""
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                        Button {
                            onDismiss()
                        } label: {
                            Text("Cancel")
                                .font(.pantrySubheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.pantryPrimary)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 8)

                        VStack(spacing: 2) {
                            Text(selectedCookbookId == nil ? "Cookbooks" : selectedCookbookName)
                                .font(.pantryHeadline)
                                .foregroundColor(.pantryTextPrimary)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                            Text(slot.label)
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: 8)

                        if selectedCookbookId != nil {
                            Button {
                                HapticFeedback.light()
                                selectedCookbookId = nil
                            } label: {
                                Image(systemName: "chevron.backward.circle.fill")
                                    .font(.pantryTitle2)
                                    .foregroundStyle(Color.pantrySecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back to cookbooks")
                        } else {
                            Color.clear
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)

                    Rectangle()
                        .fill(Color.pantryBorder.opacity(0.45))
                        .frame(height: 1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let cookbookId = selectedCookbookId {
                                recipeList(cookbookId: cookbookId)
                            } else {
                                cookbookList
                            }
                        }
                        .padding(.vertical, DesignTokens.spacingXS)
                    }
                    .frame(maxHeight: geo.size.height * 0.52)
                }
                .frame(maxWidth: min(360, geo.size.width - 32))
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous)
                        .fill(Color.pantrySurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous)
                        .stroke(Color.pantryBorderSubtle, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var cookbookList: some View {
        ForEach(viewModel.cookbooks) { cookbook in
            Button {
                HapticFeedback.light()
                selectedCookbookId = cookbook.id
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                    PlanCookbookPickerThumbnail(viewModel: viewModel, cookbook: cookbook, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cookbook.name)
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantryTextPrimary)
                            .multilineTextAlignment(.leading)
                        Text("\(cookbook.recipeIds.count) recipe\(cookbook.recipeIds.count == 1 ? "" : "s")")
                            .font(.pantryCaption)
                            .foregroundColor(.pantryTextSecondary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, DesignTokens.spacingMD)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.35))
                .frame(height: 1)
                .padding(.leading, DesignTokens.spacingMD + 52 + DesignTokens.spacingSM)
        }
    }

    @ViewBuilder
    private func recipeList(cookbookId: UUID) -> some View {
        let recipes = viewModel.recipes(for: cookbookId)
        if recipes.isEmpty {
            Text("No recipes in this cookbook.")
                .font(.pantrySubheadline)
                .foregroundColor(.pantryTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.spacingLG)
        } else {
            ForEach(recipes) { recipe in
                Button {
                    HapticFeedback.medium()
                    viewModel.setPlannedRecipe(dayKey: dayKey, slot: slot, recipeId: recipe.id)
                    onDismiss()
                } label: {
                    HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                        PlanSmallRecipeThumbnail(recipe: recipe, size: 52)
                        Text(recipe.name)
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantryTextPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.pantryBorder.opacity(0.35))
                    .frame(height: 1)
                    .padding(.leading, DesignTokens.spacingMD + 52 + DesignTokens.spacingSM)
            }
        }
    }
}
