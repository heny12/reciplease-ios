//
//  FavoritesView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI

struct CookbooksView: View {
    @ObservedObject var viewModel: PantryViewModel
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @State private var showingCreateCookbook = false
    @State private var showingLimitAlert = false
    @State private var cookbookToDelete: Cookbook?
    @State private var showingDeleteCookbookConfirmation = false
    /// Drives hidden `NavigationLink` to a cookbook after generate / scan tab switch (`openCookbookDetailId`).
    @State private var pushingCookbookDetailId: UUID?
    @State private var showFreshPicks = false

    var body: some View {
        let _ = revenueCatService.isProMember
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack {
                        NavigationLink(destination: FreshPicksView(viewModel: viewModel)) {
                            CookbooksNavPillLabel(title: "Fresh Picks", tint: .pantryPrimary)
                        }
                        .buttonStyle(.plain)
                        NavigationLink(destination: CookbooksAllRecipesListView(viewModel: viewModel)) {
                            CookbooksNavPillLabel(title: "All Recipes", tint: .pantrySecondary)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, DesignTokens.spacingSM)

                    Button {
                        HapticFeedback.medium()
                        if viewModel.canCreateMoreCookbooks {
                            showingCreateCookbook = true
                        } else {
                            showingLimitAlert = true
                        }
                    } label: {
                        NewCookbookListRow()
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(Color.pantryBorder.opacity(0.45))

                    ForEach(Array(viewModel.cookbooks.enumerated()), id: \.element.id) { index, cookbook in
                        NavigationLink(
                            destination: CookbookDetailView(viewModel: viewModel, cookbookId: cookbook.id)
                        ) {
                            CookbookListRow(
                                cookbook: cookbook,
                                recipes: viewModel.recipes(for: cookbook.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !cookbook.isDefaultFavorites && !cookbook.isInbox && !cookbook.isDefaultUncategorized {
                                Button("Delete cookbook", role: .destructive) {
                                    cookbookToDelete = cookbook
                                    showingDeleteCookbookConfirmation = true
                                }
                            }
                        }

                        if index < viewModel.cookbooks.count - 1 {
                            Divider()
                                .background(Color.pantryBorder.opacity(0.45))
                        }
                    }
                }
                .padding(.horizontal, LayoutHelpers.horizontalPadding)
                .padding(.top, DesignTokens.spacingMD)
            }

            NavigationLink(
                destination: Group {
                    if let deepLinkId = viewModel.deepLinkedRecipeIdToOpen {
                        RecipeDetailView(
                            viewModel: viewModel,
                            recipeId: deepLinkId,
                            isFromFavorites: true,
                            sourceCookbookId: viewModel.uncategorizedCookbookId
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: Binding(
                    get: { viewModel.deepLinkedRecipeIdToOpen != nil },
                    set: { isActive in
                        if !isActive {
                            viewModel.deepLinkedRecipeIdToOpen = nil
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: Group {
                    if let id = pushingCookbookDetailId {
                        CookbookDetailView(viewModel: viewModel, cookbookId: id)
                    } else {
                        EmptyView()
                    }
                },
                isActive: Binding(
                    get: { pushingCookbookDetailId != nil },
                    set: { isActive in
                        if !isActive {
                            pushingCookbookDetailId = nil
                            viewModel.openCookbookDetailId = nil
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(destination: FreshPicksView(viewModel: viewModel), isActive: $showFreshPicks) {
                EmptyView()
            }
            .hidden()
        }
        .background(Color.pantryBackground)
        .onAppear {
            viewModel.reloadFavoritedRecipes()
            if let id = viewModel.openCookbookDetailId {
                pushingCookbookDetailId = id
            }
            if viewModel.openFreshPicks {
                showFreshPicks = true
                viewModel.openFreshPicks = false
            }
        }
        .onChange(of: viewModel.openFreshPicks) { _, open in
            if open {
                showFreshPicks = true
                viewModel.openFreshPicks = false
            }
        }
        .onChange(of: viewModel.openCookbookDetailId) { _, newId in
            if let newId {
                pushingCookbookDetailId = newId
            }
        }
        .sheet(isPresented: $showingCreateCookbook) {
            CreateCookbookView(viewModel: viewModel)
        }
        .alert("Cookbook limit reached", isPresented: $showingLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can create up to \(AppConfig.maxCookbooks) cookbooks on the free plan. Reciplease Pro includes unlimited cookbooks.")
        }
        .confirmationDialog(
            "Delete cookbook?",
            isPresented: $showingDeleteCookbookConfirmation,
            titleVisibility: .visible,
            presenting: cookbookToDelete
        ) { cookbook in
            Button("Delete", role: .destructive) {
                withAnimation {
                    _ = viewModel.deleteCookbook(cookbookId: cookbook.id)
                }
                cookbookToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                cookbookToDelete = nil
            }
        } message: { cookbook in
            Text("\"\(cookbook.name)\" will be deleted. Recipes stay in your library and can appear in pantry suggestions; they are not deleted.")
        }
        .mainTabRootNavigationChrome(
            title: MainTabNavigationCopy.cookbooksNavigationTitle(count: viewModel.cookbooks.count)
        )
    }
}

/// Shared bento grid size for cookbook list rows and cookbook detail header.
private enum CookbookBentoMetrics {
    static let size: CGFloat = 100
}

private struct CookbooksNavPillLabel: View {
    let title: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.pantrySubheadline)
            .fontWeight(.semibold)
            .foregroundColor(.pantryTextPrimary)
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(tint.opacity(colorScheme == .dark ? 0.26 : 0.16))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(colorScheme == .dark ? 0.45 : 0.32), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct NewCookbookListRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.pantrySecondary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: CookbookBentoMetrics.size, height: CookbookBentoMetrics.size)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.pantryBackground))
                .overlay {
                    Image(systemName: "plus")
                        .font(.pantryTitle2.weight(.medium))
                        .foregroundColor(.pantrySecondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("New Cookbook")
                    .font(.pantryBody)
                    .fontWeight(.bold)
                    .foregroundColor(.pantryTextPrimary)
                Text("Create a folder for your recipes")
                    .font(.pantryCaption)
                    .foregroundColor(.pantryTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.pantryCaption.weight(.semibold))
                .foregroundColor(.pantryTextSecondary.opacity(0.35))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct CookbookListRow: View {
    let cookbook: Cookbook
    let recipes: [Recipe]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CookbookListThumbnail(previewRecipes: Array(recipes.prefix(4)))

            VStack(alignment: .leading, spacing: 4) {
                Text(cookbook.name)
                    .font(.pantryBody)
                    .fontWeight(.bold)
                    .foregroundColor(.pantryTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(cookbook.recipeIds.count) recipe\(cookbook.recipeIds.count == 1 ? "" : "s")")
                    .font(.pantryCaption)
                    .foregroundColor(.pantryTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.pantryCaption.weight(.semibold))
                .foregroundColor(.pantryTextSecondary.opacity(0.35))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// 2×2 placeholder grid for empty cookbooks — same orange wash as `CookbookListThumbCell` partial tiles.
private struct CookbookEmptyBentoThumbnail: View {
    private var size: CGFloat { CookbookBentoMetrics.size }
    private let gap: CGFloat = 2
    private let innerCorner: CGFloat = 5

    var body: some View {
        let cell = (size - gap) / 2
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                emptyCell(side: cell, opacity: 0.12)
                emptyCell(side: cell, opacity: 0.16)
            }
            HStack(spacing: gap) {
                emptyCell(side: cell, opacity: 0.14)
                emptyCell(side: cell, opacity: 0.12)
            }
        }
        .frame(width: size, height: size)
    }

    private func emptyCell(side: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: innerCorner, style: .continuous)
            .fill(Color.pantrySecondary.opacity(opacity))
            .frame(width: side, height: side)
    }
}

private struct CookbookListThumbnail: View {
    let previewRecipes: [Recipe]
    private var size: CGFloat { CookbookBentoMetrics.size }
    private let gap: CGFloat = 2

    var body: some View {
        Group {
            if previewRecipes.isEmpty {
                CookbookEmptyBentoThumbnail()
            } else if previewRecipes.count == 1 {
                CookbookListThumbCell(recipe: previewRecipes[0], placeholderOpacity: 0.12)
                    .frame(width: size, height: size)
            } else {
                let cell = (size - gap) / 2
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        CookbookListThumbCell(recipe: previewRecipes[safe: 0], placeholderOpacity: 0.12)
                            .frame(width: cell, height: cell)
                        CookbookListThumbCell(recipe: previewRecipes[safe: 1], placeholderOpacity: 0.16)
                            .frame(width: cell, height: cell)
                    }
                    HStack(spacing: gap) {
                        CookbookListThumbCell(recipe: previewRecipes[safe: 2], placeholderOpacity: 0.14)
                            .frame(width: cell, height: cell)
                        CookbookListThumbCell(recipe: previewRecipes[safe: 3], placeholderOpacity: 0.12)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CookbookListThumbCell: View {
    let recipe: Recipe?
    var placeholderOpacity: Double = 0.12

    var body: some View {
        Group {
            if let imageURL = recipe?.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.pantrySecondary.opacity(placeholderOpacity))
                }
            } else {
                Rectangle().fill(Color.pantrySecondary.opacity(placeholderOpacity))
            }
        }
        .clipped()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct CreateCookbookView: View {
    @ObservedObject var viewModel: PantryViewModel
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCreateDisabled: Bool {
        trimmedName.isEmpty || trimmedName.count > AppConfig.maxCookbookNameLength || !viewModel.canCreateMoreCookbooks
    }

    var body: some View {
        let _ = revenueCatService.isProMember
        PantryGenerateRecipeSheetShell(minDetentHeight: 340) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.pantrySubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, DesignTokens.spacingSM)

                PantryQuickActionSheetChrome.sheetTitle("New cookbook")

                Text("Create a folder to organize saved recipes.")
                    .font(.pantryBody)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, DesignTokens.spacingMD)

                PantryQuickActionSheetChrome.generateSheetSectionDivider

                PantryGenerateSheetFormSection(
                    title: "Title",
                    subtitle: "Choose a name you'll recognize in your library",
                    showsTrailingDivider: false
                ) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.pantryBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )

                        TextField("e.g. Weeknight dinner", text: $name)
                            .font(.pantryBody)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .foregroundStyle(Color.pantryTextPrimary)
                    }

                    HStack {
                        Spacer()
                        Text("\(trimmedName.count)/\(AppConfig.maxCookbookNameLength)")
                            .font(.pantryCaption)
                            .foregroundStyle(Color.white.opacity(0.65))
                    }

                    if let validation = viewModel.cookbookValidationMessage, !validation.isEmpty {
                        Text(validation)
                            .font(.pantryCaption)
                            .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
                    }
                }

                PantryQuickActionSheetChrome.generateSheetSectionDivider

                Button {
                    HapticFeedback.medium()
                    if viewModel.createCookbook(name: trimmedName) {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "books.vertical.fill")
                            .font(.pantryCustom(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pantryPrimary)
                        Text("Create cookbook")
                            .font(.pantryHeadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.pantryPrimary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isCreateDisabled)
                .opacity(isCreateDisabled ? 0.55 : 1)
                .padding(.bottom, DesignTokens.spacingSM)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            isFocused = true
        }
    }
}

private func cookbookLibraryRecipeTotalTime(for recipe: Recipe) -> Int? {
    if let prep = recipe.prepTimeMinutes, let cook = recipe.cookTimeMinutes {
        return prep + cook
    }
    if let prep = recipe.prepTimeMinutes { return prep }
    if let cook = recipe.cookTimeMinutes { return cook }
    return nil
}

/// Flat recipe library with search/filters; opened from the cookbook index “Recipe View” pill.
private struct CookbooksAllRecipesListView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var refreshId = UUID()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var timeFilter: TimeFilter = .all
    @State private var ingredientsFilter: IngredientsFilter = .all
    @State private var difficultyFilter: DifficultyFilter = .all
    @State private var pantryMatchFilter: PantryMatchFilter = .all
    @State private var sourceTypeFilter: SourceTypeFilter = .all
    @State private var showFilters = false
    @State private var recipeForModify: Recipe?
    @State private var showingRecipeReportSheet = false
    @State private var recipePendingDelete: Recipe?
    @State private var showingDeleteRecipeConfirmation = false
    @State private var recipeIdPendingCookbookPick: UUID?
    @State private var singleRecipeForGrocery: Recipe?
    @State private var recipeForMealPlanPicker: Recipe?
    @State private var smartFilter: SmartRecipeFilter?
    @State private var librarySort: RecipeLibrarySort = .newest

    private var allLibraryRecipes: [Recipe] {
        var seen = Set<UUID>()
        return (viewModel.recipes + viewModel.favoritedRecipes)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredRecipes: [Recipe] {
        let narrowed = allLibraryRecipes.filter { recipe in
            let matchesSearch = RecipeLibraryQuery.matchesSearch(recipe, query: searchText)
            let totalTime = cookbookLibraryRecipeTotalTime(for: recipe)
            let matchesTime = timeFilter.matches(totalTime: totalTime)
            let matchesIngredients = ingredientsFilter.matches(count: recipe.ingredients.count)
            let matchesDifficulty = difficultyFilter.matches(difficulty: recipe.difficulty)
            let matchScore = viewModel.pantryMatchScore(for: recipe.id)
            let matchesPantry = pantryMatchFilter.matches(score: matchScore)
            let matchesSource = sourceTypeFilter.matches(category: recipe.sourceCategory)
            let matchesSmart = RecipeLibraryQuery.matches(recipe: recipe, smart: smartFilter, pantryScore: matchScore)
            return matchesSearch && matchesTime && matchesIngredients && matchesDifficulty && matchesPantry && matchesSource && matchesSmart
        }
        return RecipeLibraryQuery.sorted(narrowed, by: librarySort, pantryScores: viewModel.pantryMatchScores)
    }

    private var hasActiveFilters: Bool {
        timeFilter != .all || ingredientsFilter != .all || difficultyFilter != .all || pantryMatchFilter != .all || sourceTypeFilter != .all || smartFilter != nil
    }

    private var navigationTitleText: String {
        let n = allLibraryRecipes.count
        return n == 1 ? "1 Recipe" : "\(n) Recipes"
    }

    private func clearFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            timeFilter = .all
            ingredientsFilter = .all
            difficultyFilter = .all
            pantryMatchFilter = .all
            sourceTypeFilter = .all
        }
        HapticFeedback.light()
    }

    private var allRecipesSearchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.pantryCustom(size: 16))
                    .foregroundColor(.pantryTextSecondary)

                TextField("Search recipes...", text: $searchText)
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = false
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pantryCustom(size: 16))
                            .foregroundColor(.pantryTextSecondary)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showFilters.toggle()
                    }
                    HapticFeedback.light()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.pantryCustom(size: 16, weight: .medium))
                            .foregroundColor(hasActiveFilters ? .pantryPrimary : .pantryTextSecondary)

                        if hasActiveFilters {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.pantrySurface)
            .cornerRadius(12)

            smartAndSortControls

            if showFilters {
                VStack(alignment: .leading, spacing: 6) {
                    FilterRow(title: "Time", icon: "clock.fill", options: TimeFilter.allCases, selected: $timeFilter)
                    FilterRow(title: "Ingredients", icon: "basket.fill", options: IngredientsFilter.allCases, selected: $ingredientsFilter)
                    FilterRow(title: "Difficulty", icon: "speedometer", options: DifficultyFilter.allCases, selected: $difficultyFilter)
                    FilterRow(title: "Pantry match", icon: "gauge.with.needle", options: PantryMatchFilter.allCases, selected: $pantryMatchFilter)
                    FilterRow(title: "Source", icon: "square.on.square.intersection.dashed", options: SourceTypeFilter.allCases, selected: $sourceTypeFilter)
                    if hasActiveFilters {
                        Button {
                            clearFilters()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.pantryCustom(size: 12))
                                Text("Clear filters")
                                    .font(.pantryCaption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.pantryPrimary)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !searchText.isEmpty || hasActiveFilters {
                HStack {
                    Text("\(filteredRecipes.count) recipe\(filteredRecipes.count == 1 ? "" : "s") found")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var smartAndSortControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SmartRecipeFilter.allCases) { filter in
                        Button {
                            smartFilter = smartFilter == filter ? nil : filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.pantryCaption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(smartFilter == filter ? Color.pantryPrimary : Color.pantrySurface))
                                .foregroundStyle(smartFilter == filter ? Color.white : Color.pantryTextPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Menu {
                ForEach(RecipeLibrarySort.allCases) { sort in
                    Button(sort.rawValue) { librarySort = sort }
                }
            } label: {
                Label("Sort: \(librarySort.rawValue)", systemImage: "arrow.up.arrow.down")
                    .font(.pantryCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantryPrimary)
            }
        }
    }

    private var listHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            cookbooksRecipeViewHeaderPills

            allRecipesSearchAndFilters
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    /// Cookbook View + Generate / Scan / Import; wraps to the next line when the row is too narrow.
    private var cookbooksRecipeViewHeaderPills: some View {
        FlowLayout(spacing: 8) {
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                CookbooksNavPillLabel(title: "Cookbook View", tint: .pantryPrimary)
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.light()
                viewModel.shouldOpenRecipeGeneratePrompt = true
            } label: {
                CookbooksNavPillLabel(title: "Generate", tint: .pantryPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Generate recipes")

            Button {
                HapticFeedback.light()
                viewModel.shouldOpenCookbookRecipeScan = true
            } label: {
                CookbooksNavPillLabel(title: "Scan", tint: .pantrySecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan cookbook")

            Button {
                HapticFeedback.light()
                viewModel.shouldOpenWebRecipeScan = true
            } label: {
                CookbooksNavPillLabel(title: "Import", tint: .pantryPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Import recipe from web")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredEmptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.pantryCustom(size: 48, weight: .bold))
                .foregroundColor(.pantryTextSecondary.opacity(0.5))

            Text("No recipes found")
                .font(.pantryTitle3)
                .fontWeight(.semibold)
                .foregroundColor(.pantryTextPrimary)

            Text("Try adjusting your search or filters")
                .font(.pantrySubheadline)
                .foregroundColor(.pantryTextSecondary)

            if hasActiveFilters {
                Button {
                    clearFilters()
                } label: {
                    Text("Clear filters")
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pantryPrimary)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXL)
    }

    var body: some View {
        ZStack {
            Group {
            if allLibraryRecipes.isEmpty {
                VStack(spacing: DesignTokens.spacingMD) {
                    cookbooksRecipeViewHeaderPills

                    Spacer(minLength: 0)

                    Image(systemName: "book.closed")
                        .font(.pantryCustom(size: 48, weight: .semibold))
                        .foregroundColor(.pantryTextSecondary.opacity(0.4))

                    Text("No recipes yet")
                        .font(.pantryTitle3)
                        .foregroundColor(.pantryTextPrimary)

                    Text("Generate or bookmark recipes to see them here.")
                        .font(.pantrySubheadline)
                        .foregroundColor(.pantryTextSecondary)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, LayoutHelpers.horizontalPadding)
                .padding(.top, DesignTokens.spacingMD)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        listHeaderSection
                            .listRowInsets(EdgeInsets(top: 8, leading: LayoutHelpers.horizontalPadding, bottom: 8, trailing: LayoutHelpers.horizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.pantryBackground)
                    }

                    if filteredRecipes.isEmpty {
                        Section {
                            filteredEmptyContent
                                .listRowInsets(EdgeInsets(top: 0, leading: LayoutHelpers.horizontalPadding, bottom: 0, trailing: LayoutHelpers.horizontalPadding))
                                .listRowBackground(Color.pantryBackground)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        Section {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(
                                    destination: RecipeDetailView(
                                        viewModel: viewModel,
                                        recipeId: recipe.id,
                                        isFromFavorites: true,
                                        sourceCookbookId: viewModel.cookbookContainingRecipe(recipeId: recipe.id)?.id
                                    )
                                ) {
                                    RecipeRowContent(
                                        recipe: recipe,
                                        pantryMatchScore: viewModel.pantryMatchScore(for: recipe.id)
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: LayoutHelpers.horizontalPadding, bottom: 0, trailing: LayoutHelpers.horizontalPadding))
                                .listRowBackground(Color.pantryBackground)
                                .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        HapticFeedback.medium()
                                        recipeIdPendingCookbookPick = recipe.id
                                    } label: {
                                        Label("Bookmark", systemImage: "bookmark.fill")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        HapticFeedback.medium()
                                        viewModel.deleteRecipe(recipeId: recipe.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        HapticFeedback.light()
                                        singleRecipeForGrocery = recipe
                                    } label: {
                                        Label("Add to Grocery List", systemImage: "cart.badge.plus")
                                    }
                                    Button {
                                        HapticFeedback.light()
                                        recipeForMealPlanPicker = recipe
                                    } label: {
                                        Label("Add to Meal Plan", systemImage: "calendar")
                                    }
                                    Button {
                                        HapticFeedback.medium()
                                        recipeIdPendingCookbookPick = recipe.id
                                    } label: {
                                        Label("Bookmark", systemImage: "bookmark.fill")
                                    }
                                    if let url = URL(string: "https://reciplease.info/recipes/shared/\(recipe.id.uuidString.lowercased())") {
                                        ShareLink(item: url, subject: Text(recipe.name), message: Text(recipe.name)) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    Button {
                                        recipeForModify = recipe
                                    } label: {
                                        Label("Modify", systemImage: "wand.and.stars")
                                    }
                                    Button {
                                        showingRecipeReportSheet = true
                                    } label: {
                                        Label("Report Issue", systemImage: "exclamationmark.triangle")
                                    }
                                    Button(role: .destructive) {
                                        recipePendingDelete = recipe
                                        showingDeleteRecipeConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .navigationLinkIndicatorVisibility(.hidden)
                .contentMargins(.bottom, DesignTokens.spacingMD, for: .scrollContent)
                .id(refreshId)
            }
            }

            if let planRecipe = recipeForMealPlanPicker {
                RecipePlanPickerBubble(
                    viewModel: viewModel,
                    recipeId: planRecipe.id,
                    recipeName: planRecipe.name,
                    onDismiss: { recipeForMealPlanPicker = nil }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.22), value: recipeForMealPlanPicker != nil)
        .background(Color.pantryBackground)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshId = UUID()
            let urls = allLibraryRecipes.compactMap { $0.imageURL }
            ImagePreloadService.shared.preloadImages(for: urls)
        }
        .confirmationDialog(
            "Choose a cookbook",
            isPresented: Binding(
                get: { recipeIdPendingCookbookPick != nil },
                set: { if !$0 { recipeIdPendingCookbookPick = nil } }
            ),
            titleVisibility: .visible,
            presenting: recipeIdPendingCookbookPick
        ) { recipeId in
            ForEach(viewModel.cookbooks) { cookbook in
                Button(cookbook.name) {
                    viewModel.addRecipeToCookbook(
                        recipeId: recipeId,
                        cookbookId: cookbook.id,
                        navigateToCookbooksTab: false
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Pick where this bookmarked recipe should be stored.")
        }
        .sheet(item: $singleRecipeForGrocery, onDismiss: { singleRecipeForGrocery = nil }) { recipe in
            SingleRecipeAddToGrocerySheet(recipe: recipe, viewModel: viewModel)
        }
        .sheet(item: $recipeForModify) { recipe in
            ModifyRecipeView(
                viewModel: viewModel,
                recipe: recipe,
                isPresented: Binding(
                    get: { recipeForModify != nil },
                    set: { if !$0 { recipeForModify = nil } }
                )
            )
        }
        .sheet(isPresented: $showingRecipeReportSheet) {
            FeedbackFormView(feedbackType: .bug)
        }
        .confirmationDialog(
            "Delete recipe?",
            isPresented: $showingDeleteRecipeConfirmation,
            titleVisibility: .visible,
            presenting: recipePendingDelete
        ) { _ in
            Button("Delete", role: .destructive) {
                if let recipe = recipePendingDelete {
                    viewModel.deleteRecipe(recipeId: recipe.id)
                }
                recipePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                recipePendingDelete = nil
            }
        } message: { _ in
            Text("This removes the recipe from all cookbooks and your library.")
        }
    }
}

private struct CookbookDetailView: View {
    @ObservedObject var viewModel: PantryViewModel
    let cookbookId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteCookbookAlert = false

    @State private var refreshId = UUID()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var timeFilter: TimeFilter = .all
    @State private var ingredientsFilter: IngredientsFilter = .all
    @State private var difficultyFilter: DifficultyFilter = .all
    @State private var pantryMatchFilter: PantryMatchFilter = .all
    @State private var sourceTypeFilter: SourceTypeFilter = .all
    @State private var showFilters = false
    @State private var recipeForModify: Recipe?
    @State private var showingRecipeReportSheet = false
    @State private var recipePendingDelete: Recipe?
    @State private var showingDeleteRecipeConfirmation = false
    @State private var recipeIdPendingCookbookPick: UUID?
    @State private var singleRecipeForGrocery: Recipe?
    @State private var recipeForMealPlanPicker: Recipe?
    @State private var smartFilter: SmartRecipeFilter?
    @State private var librarySort: RecipeLibrarySort = .newest

    private var cookbook: Cookbook? {
        viewModel.cookbooks.first(where: { $0.id == cookbookId })
    }

    private var recipes: [Recipe] {
        viewModel.recipes(for: cookbookId)
    }

    private var filteredRecipes: [Recipe] {
        let narrowed = recipes.filter { recipe in
            let matchesSearch = RecipeLibraryQuery.matchesSearch(recipe, query: searchText)
            let totalTime = cookbookRecipeTotalTime(for: recipe)
            let matchesTime = timeFilter.matches(totalTime: totalTime)
            let matchesIngredients = ingredientsFilter.matches(count: recipe.ingredients.count)
            let matchesDifficulty = difficultyFilter.matches(difficulty: recipe.difficulty)
            let matchScore = viewModel.pantryMatchScore(for: recipe.id)
            let matchesPantry = pantryMatchFilter.matches(score: matchScore)
            let matchesSource = sourceTypeFilter.matches(category: recipe.sourceCategory)
            let matchesSmart = RecipeLibraryQuery.matches(recipe: recipe, smart: smartFilter, pantryScore: matchScore)
            return matchesSearch && matchesTime && matchesIngredients && matchesDifficulty && matchesPantry && matchesSource && matchesSmart
        }
        return RecipeLibraryQuery.sorted(narrowed, by: librarySort, pantryScores: viewModel.pantryMatchScores)
    }

    private var hasActiveFilters: Bool {
        timeFilter != .all || ingredientsFilter != .all || difficultyFilter != .all || pantryMatchFilter != .all || sourceTypeFilter != .all || smartFilter != nil
    }

    private var cookbookSmartAndSort: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SmartRecipeFilter.allCases) { filter in
                        Button {
                            smartFilter = smartFilter == filter ? nil : filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.pantryCaption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(smartFilter == filter ? Color.pantryPrimary : Color.pantrySurface))
                                .foregroundStyle(smartFilter == filter ? Color.white : Color.pantryTextPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Menu {
                ForEach(RecipeLibrarySort.allCases) { sort in
                    Button(sort.rawValue) { librarySort = sort }
                }
            } label: {
                Label("Sort: \(librarySort.rawValue)", systemImage: "arrow.up.arrow.down")
                    .font(.pantryCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantryPrimary)
            }
        }
    }

    private var cookbookNavigationTitle: String {
        cookbook?.name ?? "Cookbook"
    }

    /// Count of recipes in this cookbook (from metadata, not filtered list).
    private var cookbookRecipeCountSubtitle: String {
        let n = cookbook?.recipeIds.count ?? 0
        return n == 1 ? "1 recipe" : "\(n) recipes"
    }

    private func cookbookRecipeTotalTime(for recipe: Recipe) -> Int? {
        if let prep = recipe.prepTimeMinutes, let cook = recipe.cookTimeMinutes {
            return prep + cook
        }
        if let prep = recipe.prepTimeMinutes { return prep }
        if let cook = recipe.cookTimeMinutes { return cook }
        return nil
    }

    private func clearFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            timeFilter = .all
            ingredientsFilter = .all
            difficultyFilter = .all
            pantryMatchFilter = .all
            sourceTypeFilter = .all
        }
        HapticFeedback.light()
    }

    /// Search field + filter chips + result count.
    private var cookbookDetailSearchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.pantryCustom(size: 16))
                    .foregroundColor(.pantryTextSecondary)

                TextField("Search recipes...", text: $searchText)
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = false
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pantryCustom(size: 16))
                            .foregroundColor(.pantryTextSecondary)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showFilters.toggle()
                    }
                    HapticFeedback.light()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.pantryCustom(size: 16, weight: .medium))
                            .foregroundColor(hasActiveFilters ? .pantryPrimary : .pantryTextSecondary)

                        if hasActiveFilters {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.pantrySurface)
            .cornerRadius(12)

            cookbookSmartAndSort

            if showFilters {
                VStack(alignment: .leading, spacing: 6) {
                    FilterRow(
                        title: "Time",
                        icon: "clock.fill",
                        options: TimeFilter.allCases,
                        selected: $timeFilter
                    )
                    FilterRow(
                        title: "Ingredients",
                        icon: "basket.fill",
                        options: IngredientsFilter.allCases,
                        selected: $ingredientsFilter
                    )
                    FilterRow(
                        title: "Difficulty",
                        icon: "speedometer",
                        options: DifficultyFilter.allCases,
                        selected: $difficultyFilter
                    )
                    FilterRow(
                        title: "Pantry match",
                        icon: "gauge.with.needle",
                        options: PantryMatchFilter.allCases,
                        selected: $pantryMatchFilter
                    )
                    FilterRow(
                        title: "Source",
                        icon: "square.on.square.intersection.dashed",
                        options: SourceTypeFilter.allCases,
                        selected: $sourceTypeFilter
                    )
                    if hasActiveFilters {
                        Button {
                            clearFilters()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.pantryCustom(size: 12))
                                Text("Clear filters")
                                    .font(.pantryCaption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.pantryPrimary)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !searchText.isEmpty || hasActiveFilters {
                HStack {
                    Text("\(filteredRecipes.count) recipe\(filteredRecipes.count == 1 ? "" : "s") found")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    /// Header: bento + title, search, filters — scrolls with the list (name also in the nav bar).
    private var cookbookDetailHeaderSectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                CookbookListThumbnail(previewRecipes: Array(recipes.prefix(4)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(cookbook?.name ?? "Cookbook")
                        .font(.pantryTitle3)
                        .fontWeight(.bold)
                        .foregroundColor(.pantryTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(cookbookRecipeCountSubtitle)
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }

                Spacer(minLength: 0)
            }

            cookbookDetailSearchAndFilters
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var cookbookFilteredEmptyListContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.pantryCustom(size: 48, weight: .bold))
                .foregroundColor(.pantryTextSecondary.opacity(0.5))

            Text("No recipes found")
                .font(.pantryTitle3)
                .fontWeight(.semibold)
                .foregroundColor(.pantryTextPrimary)

            Text("Try adjusting your search or filters")
                .font(.pantrySubheadline)
                .foregroundColor(.pantryTextSecondary)

            if hasActiveFilters {
                Button {
                    clearFilters()
                } label: {
                    Text("Clear filters")
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pantryPrimary)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXL)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            if recipes.isEmpty {
                ScrollView {
                    VStack(spacing: DesignTokens.spacingMD) {
                        Image(systemName: "books.vertical")
                            .font(.pantryCustom(size: 48, weight: .semibold))
                            .foregroundColor(.pantryTextSecondary.opacity(0.4))

                        Text("No recipes in this cookbook")
                            .font(.pantryTitle3)
                            .foregroundColor(.pantryTextPrimary)

                        Text("Bookmark recipes and choose this cookbook to organize them.")
                            .font(.pantrySubheadline)
                            .foregroundColor(.pantryTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignTokens.spacingXL)
                    .padding(.horizontal, LayoutHelpers.horizontalPadding)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 100)
                }
            } else {
                List {
                    Section {
                        cookbookDetailHeaderSectionContent
                            .listRowInsets(EdgeInsets(top: 8, leading: LayoutHelpers.horizontalPadding, bottom: 8, trailing: LayoutHelpers.horizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.pantryBackground)
                    }

                    if filteredRecipes.isEmpty {
                        Section {
                            cookbookFilteredEmptyListContent
                                .listRowInsets(EdgeInsets(top: 0, leading: LayoutHelpers.horizontalPadding, bottom: 0, trailing: LayoutHelpers.horizontalPadding))
                                .listRowBackground(Color.pantryBackground)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        Section {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(
                                    destination: RecipeDetailView(
                                        viewModel: viewModel,
                                        recipeId: recipe.id,
                                        isFromFavorites: true,
                                        sourceCookbookId: cookbookId
                                    )
                                ) {
                                    RecipeRowContent(
                                        recipe: recipe,
                                        pantryMatchScore: viewModel.pantryMatchScore(for: recipe.id)
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: LayoutHelpers.horizontalPadding, bottom: 0, trailing: LayoutHelpers.horizontalPadding))
                                .listRowBackground(Color.pantryBackground)
                                .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        HapticFeedback.medium()
                                        recipeIdPendingCookbookPick = recipe.id
                                    } label: {
                                        Label("Bookmark", systemImage: "bookmark.fill")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        HapticFeedback.medium()
                                        viewModel.deleteRecipe(recipeId: recipe.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        HapticFeedback.light()
                                        singleRecipeForGrocery = recipe
                                    } label: {
                                        Label("Add to Grocery List", systemImage: "cart.badge.plus")
                                    }
                                    Button {
                                        HapticFeedback.light()
                                        recipeForMealPlanPicker = recipe
                                    } label: {
                                        Label("Add to Meal Plan", systemImage: "calendar")
                                    }
                                    Button {
                                        HapticFeedback.medium()
                                        recipeIdPendingCookbookPick = recipe.id
                                    } label: {
                                        Label("Bookmark", systemImage: "bookmark.fill")
                                    }
                                    if let url = URL(string: "https://reciplease.info/recipes/shared/\(recipe.id.uuidString.lowercased())") {
                                        ShareLink(item: url, subject: Text(recipe.name), message: Text(recipe.name)) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    Button {
                                        recipeForModify = recipe
                                    } label: {
                                        Label("Modify", systemImage: "wand.and.stars")
                                    }
                                    Button {
                                        showingRecipeReportSheet = true
                                    } label: {
                                        Label("Report Issue", systemImage: "exclamationmark.triangle")
                                    }
                                    Button(role: .destructive) {
                                        recipePendingDelete = recipe
                                        showingDeleteRecipeConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .navigationLinkIndicatorVisibility(.hidden)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 24) }
                .id(refreshId)
            }
            }

            if let planRecipe = recipeForMealPlanPicker {
                RecipePlanPickerBubble(
                    viewModel: viewModel,
                    recipeId: planRecipe.id,
                    recipeName: planRecipe.name,
                    onDismiss: { recipeForMealPlanPicker = nil }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.22), value: recipeForMealPlanPicker != nil)
        .background(Color.pantryBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshId = UUID()
            let imageURLs = recipes.compactMap { $0.imageURL }
            ImagePreloadService.shared.preloadImages(for: imageURLs)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(cookbookNavigationTitle)
                        .font(.pantryHeadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.pantryTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(cookbookRecipeCountSubtitle)
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            if let cookbook, !cookbook.isDefaultFavorites {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteCookbookAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert("Delete cookbook?", isPresented: $showingDeleteCookbookAlert) {
            Button("Delete", role: .destructive) {
                if viewModel.deleteCookbook(cookbookId: cookbookId) {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the cookbook only. Recipes remain in your library and are not deleted.")
        }
        .confirmationDialog(
            "Choose a cookbook",
            isPresented: Binding(
                get: { recipeIdPendingCookbookPick != nil },
                set: { if !$0 { recipeIdPendingCookbookPick = nil } }
            ),
            titleVisibility: .visible,
            presenting: recipeIdPendingCookbookPick
        ) { recipeId in
            ForEach(viewModel.cookbooks) { cookbook in
                Button(cookbook.name) {
                    viewModel.addRecipeToCookbook(
                        recipeId: recipeId,
                        cookbookId: cookbook.id,
                        navigateToCookbooksTab: false
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Pick where this bookmarked recipe should be stored.")
        }
        .sheet(item: $singleRecipeForGrocery, onDismiss: { singleRecipeForGrocery = nil }) { recipe in
            SingleRecipeAddToGrocerySheet(recipe: recipe, viewModel: viewModel)
        }
        .sheet(item: $recipeForModify) { recipe in
            ModifyRecipeView(
                viewModel: viewModel,
                recipe: recipe,
                isPresented: Binding(
                    get: { recipeForModify != nil },
                    set: { if !$0 { recipeForModify = nil } }
                )
            )
        }
        .sheet(isPresented: $showingRecipeReportSheet) {
            FeedbackFormView(feedbackType: .bug)
        }
        .confirmationDialog(
            "Delete recipe?",
            isPresented: $showingDeleteRecipeConfirmation,
            titleVisibility: .visible,
            presenting: recipePendingDelete
        ) { _ in
            Button("Delete", role: .destructive) {
                if let recipe = recipePendingDelete {
                    viewModel.deleteRecipe(recipeId: recipe.id)
                }
                recipePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                recipePendingDelete = nil
            }
        } message: { _ in
            Text("This removes the recipe from all cookbooks and your library.")
        }
    }
}

#Preview {
    NavigationStack {
        CookbooksView(viewModel: PantryViewModel())
    }
}
