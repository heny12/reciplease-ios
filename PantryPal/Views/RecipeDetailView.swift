//
//  RecipeDetailView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI

struct RecipeDetailView: View {
    @ObservedObject var viewModel: PantryViewModel
    /// Observed so `shouldShowPaywall` updates dismiss the modify paywall when the user taps Close.
    @ObservedObject private var usageTracker = UsageTracker.shared
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    let recipeId: UUID
    var isFromFavorites: Bool = false
    var sourceCookbookId: UUID? = nil
    
    @State private var showingModifySheet = false
    @State private var showingFullImage = false
    @State private var showingReportSheet = false
    @State private var showingRecipePlanBubble = false
    @State private var showingAddToGrocerySheet = false
    @State private var showStepFocusMode = false
    @AppStorage("Reciplease.KeepScreenAwake") private var keepScreenAwakePreference = false
    @State private var hasAppliedWakeLock = false
    @State private var selectedServingsOverride: Int = 0
    /// Nutrition estimate for this recipe (from `/api/recipe/nutrition` using recipe ingredients).
    @State private var recipeNutrition: PantryNutritionResult?
    @State private var recipeNutritionLoading = false
    @State private var recipeNutritionError: String?
    @State private var showingChefTipsSheet = false
    @State private var showingNutritionSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var headerHeight: CGFloat {
        isLandscape ? 300 : LayoutHelpers.recipeDetailHeaderHeight
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var landscapeHorizontalPadding: CGFloat {
        isLandscape ? DesignTokens.spacingXXL * 2 : 0
    }
    
    private var recipeDetailPaywallBinding: Binding<Bool> {
        Binding(
            get: { usageTracker.shouldShowPaywall },
            set: { newValue in
                if !newValue {
                    usageTracker.onPaywallDismissed()
                }
            }
        )
    }
    
    // Get the current recipe from viewModel to ensure we always show the latest version
    // Check both recipes and favoritedRecipes arrays
    // Access both arrays to ensure observation triggers updates
    private var recipe: Recipe? {
        let recipes = viewModel.recipes
        let favoritedRecipes = viewModel.favoritedRecipes
        return recipes.first { $0.id == recipeId } ?? 
               favoritedRecipes.first { $0.id == recipeId }
    }

    /// Cookbook that currently holds this recipe (single membership). Ignores stale navigation `sourceCookbookId` when membership differs.
    private var currentCookbook: Cookbook? {
        viewModel.cookbookContainingRecipe(recipeId: recipeId)
    }

    private func recipeNutritionFetchSignature(for recipe: Recipe) -> String {
        recipe.id.uuidString + "|" + recipe.ingredients.map { "\($0.name)|\($0.quantity)" }.joined(separator: "\u{1e}")
    }

    private func fetchRecipeNutrition(for recipe: Recipe) async {
        guard !recipe.nonEmptyRecipeIngredientLines.isEmpty else {
            await MainActor.run {
                recipeNutrition = nil
                recipeNutritionError = nil
                recipeNutritionLoading = false
            }
            return
        }

        guard RevenueCatService.shared.isProMember else {
            await MainActor.run {
                recipeNutrition = nil
                recipeNutritionError = nil
                recipeNutritionLoading = false
            }
            return
        }

        if let validationMessage = RecipeAPIService.shared.validateRecipeForNutritionRequest(recipe) {
            await MainActor.run {
                recipeNutritionError = validationMessage
                recipeNutrition = nil
                recipeNutritionLoading = false
            }
            return
        }

        await MainActor.run {
            recipeNutritionLoading = true
            recipeNutritionError = nil
            recipeNutrition = nil
        }

        do {
            let result = try await RecipeAPIService.shared.fetchNutritionTotals(recipe: recipe)
            await MainActor.run {
                recipeNutrition = result
                recipeNutritionLoading = false
            }
        } catch let error as APIError {
            await MainActor.run {
                recipeNutritionError = error.localizedDescription
                recipeNutrition = nil
                recipeNutritionLoading = false
            }
        } catch {
            await MainActor.run {
                recipeNutritionError = "We couldn't load nutrition for this recipe."
                recipeNutrition = nil
                recipeNutritionLoading = false
            }
        }
    }

    private func currentServings(for recipe: Recipe) -> Int {
        let base = recipe.servings ?? 1
        return selectedServingsOverride == 0 ? base : selectedServingsOverride
    }

    private func servingsBinding(for recipe: Recipe) -> Binding<Int> {
        Binding(
            get: { currentServings(for: recipe) },
            set: { newValue in
                let clamped = min(max(newValue, 1), 20)
                selectedServingsOverride = clamped
            }
        )
    }

    /// Nutrition from the API is for the **full recipe**. Divide by yield to show **per serving** (one portion of `recipe.servings`).
    private func nutritionPerServingScaleFactor(for recipe: Recipe) -> Double {
        let base = max(recipe.servings ?? 1, 1)
        return 1.0 / Double(base)
    }

    /// Quantities that are never scaled and never get a "× N" or "/ N" indicator (e.g. "to taste").
    private static let nonScalableQuantityWhitelist: Set<String> = [
        "to taste",
        "a pinch"
    ]

    private static func isNonScalableQuantity(_ quantity: String) -> Bool {
        nonScalableQuantityWhitelist.contains(quantity.trimmingCharacters(in: .whitespaces).lowercased())
    }

    /// Given a servings factor (current / base), returns an integer indicator:
    /// - positive N means "× N"
    /// - negative N means "/ N"
    /// - nil means "no indicator"
    private static func scaleIndicator(for factor: Double) -> Int? {
        let epsilon = 0.05
        if abs(factor - 1.0) < epsilon {
            return nil
        } else if factor > 1.0 {
            let up = Int(round(factor))
            return up >= 2 ? up : nil
        } else {
            let down = Int(round(1.0 / factor))
            return down >= 2 ? -down : nil
        }
    }

    /// Returns (displayText, scaleFactorToShow). When scaleFactorToShow is non-nil, the quantity couldn't be parsed so we show the original text and "× scaleFactorToShow" so the user can scale manually.
    private func scaledQuantity(_ quantity: String, recipeServings: Int?, currentServings: Int) -> (text: String, scaleFactorToShow: Int?) {
        guard !quantity.isEmpty else { return (quantity, nil) }

        let baseServings = max(recipeServings ?? 1, 1)
        let factor = Double(currentServings) / Double(baseServings)
        guard baseServings != currentServings else { return (quantity, nil) }

        if Self.isNonScalableQuantity(quantity) { return (quantity, nil) }

        let parts = quantity.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else {
            return (quantity, Self.scaleIndicator(for: factor))
        }

        let numberPart = String(first)
        let rest = parts.count > 1 ? " " + parts[1] : ""

        let numericValue: Double?

        if numberPart.contains("/") {
            let fractionParts = numberPart.split(separator: "/")
            if fractionParts.count == 2,
               let num = Double(fractionParts[0]),
               let den = Double(fractionParts[1]),
               den != 0 {
                numericValue = num / den
            } else {
                numericValue = nil
            }
        } else {
            numericValue = Double(numberPart)
        }

        guard let value = numericValue else {
            return (quantity, Self.scaleIndicator(for: factor))
        }

        let scaled = value * factor
        let formatted = formatQuantityValue(scaled)
        return (formatted + rest, nil)
    }

    private func formatQuantityValue(_ value: Double) -> String {
        let isNegative = value < 0
        let absValue = abs(value)
        let whole = Int(absValue.rounded(.towardZero))
        let fraction = absValue - Double(whole)
        let epsilon = 0.01

        let denominators = [2, 3, 4, 8, 16]
        var bestNumerator = 0
        var bestDenominator = 1
        var bestDiff = epsilon

        for denom in denominators {
            let rawNumerator = fraction * Double(denom)
            let roundedNumerator = rawNumerator.rounded()
            guard roundedNumerator > 0 else { continue }
            let approx = roundedNumerator / Double(denom)
            let diff = abs(approx - fraction)
            if diff < bestDiff {
                bestDiff = diff
                bestNumerator = Int(roundedNumerator)
                bestDenominator = denom
            }
        }

        let sign = isNegative ? "-" : ""

        if bestNumerator > 0 {
            let fractionString = "\(bestNumerator)/\(bestDenominator)"
            if whole == 0 {
                return sign + fractionString
            } else {
                return "\(sign)\(whole) \(fractionString)"
            }
        }

        if abs(absValue.rounded() - absValue) < 0.01 {
            let intString = String(Int(absValue.rounded()))
            return sign + intString
        } else {
            let decimalString = trimTrailingZeros(String(format: "%.2f", absValue))
            return sign + decimalString
        }
    }

    private func trimTrailingZeros(_ string: String) -> String {
        var s = string
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            s.removeLast()
        }
        return s
    }

    // MARK: - Distraction-free cooking mode

    struct StepByStepCookingView: View {
        let recipe: Recipe
        let servings: Int
        @Binding var isPresented: Bool
        
        @State private var currentStepIndex: Int = 0
        
        private var steps: [String] {
            recipe.steps
        }
        
        private func ingredients(for step: String) -> [RecipeIngredient] {
            let lowercasedStep = step.lowercased()

            // Words "claimed" by ingredients that matched by full name (e.g. "chicken" from "Chicken Thighs").
            // We won't include another ingredient on a word-only match for a claimed word (e.g. exclude "Chicken Bouillon").
            let fullNameMatchedWords: Set<String> = {
                var claimed = Set<String>()
                for ingredient in recipe.ingredients {
                    let name = ingredient.name.lowercased()
                    guard lowercasedStep.contains(name) else { continue }
                    let words = name.split(separator: " ").filter { $0.count > 3 }
                    for word in words {
                        claimed.insert(String(word).lowercased())
                    }
                }
                return claimed
            }()

            let matched = recipe.ingredients.filter { ingredient in
                let name = ingredient.name.lowercased()
                if lowercasedStep.contains(name) {
                    return true
                }
                let words = name.split(separator: " ").filter { $0.count > 3 }
                let matchingWords = words.filter { lowercasedStep.contains(String($0).lowercased()) }
                guard !matchingWords.isEmpty else { return false }
                // Don't include if every word that caused this match is already claimed by a full-name match (e.g. exclude "Chicken Bouillon" when "Chicken Thighs" matched).
                let allMatchingWordsClaimed = matchingWords.allSatisfy { fullNameMatchedWords.contains(String($0).lowercased()) }
                return !allMatchingWordsClaimed
            }
            return matched
        }
        
        /// Returns (displayText, scaleFactorToShow). When scaleFactorToShow is non-nil, show "× scaleFactorToShow" so the user can scale manually.
        private func scaledQuantity(for ingredient: RecipeIngredient) -> (text: String, scaleFactorToShow: Int?) {
            let quantity = ingredient.quantity
            guard !quantity.isEmpty else { return (quantity, nil) }
            
            let baseServings = max(recipe.servings ?? 1, 1)
            let factor = Double(servings) / Double(baseServings)
            guard baseServings != servings else { return (quantity, nil) }
            
            if RecipeDetailView.isNonScalableQuantity(quantity) { return (quantity, nil) }
            
            let parts = quantity.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let first = parts.first else {
                return (quantity, RecipeDetailView.scaleIndicator(for: factor))
            }
            
            let numberPart = String(first)
            let rest = parts.count > 1 ? " " + parts[1] : ""
            
            let numericValue: Double?
            if numberPart.contains("/") {
                let fractionParts = numberPart.split(separator: "/")
                if fractionParts.count == 2,
                   let num = Double(fractionParts[0]),
                   let den = Double(fractionParts[1]),
                   den != 0 {
                    numericValue = num / den
                } else {
                    numericValue = nil
                }
            } else {
                numericValue = Double(numberPart)
            }
            
            guard let value = numericValue else {
                return (quantity, RecipeDetailView.scaleIndicator(for: factor))
            }
            
            let scaled = value * factor
            let formatted = formatQuantityValue(scaled)
            return (formatted + rest, nil)
        }
        
        private func formatQuantityValue(_ value: Double) -> String {
            let isNegative = value < 0
            let absValue = abs(value)
            let whole = Int(absValue.rounded(.towardZero))
            let fraction = absValue - Double(whole)
            let epsilon = 0.01
            
            let denominators = [2, 3, 4, 8, 16]
            var bestNumerator = 0
            var bestDenominator = 1
            var bestDiff = epsilon
            
            for denom in denominators {
                let rawNumerator = fraction * Double(denom)
                let roundedNumerator = rawNumerator.rounded()
                guard roundedNumerator > 0 else { continue }
                let approx = roundedNumerator / Double(denom)
                let diff = abs(approx - fraction)
                if diff < bestDiff {
                    bestDiff = diff
                    bestNumerator = Int(roundedNumerator)
                    bestDenominator = denom
                }
            }
            
            let sign = isNegative ? "-" : ""
            
            if bestNumerator > 0 {
                let fractionString = "\(bestNumerator)/\(bestDenominator)"
                if whole == 0 {
                    return sign + fractionString
                } else {
                    return "\(sign)\(whole) \(fractionString)"
                }
            }
            
            if abs(absValue.rounded() - absValue) < 0.01 {
                let intString = String(Int(absValue.rounded()))
                return sign + intString
            } else {
                let decimalString = trimTrailingZeros(String(format: "%.2f", absValue))
                return sign + decimalString
            }
        }
        
        private func trimTrailingZeros(_ string: String) -> String {
            var s = string
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
                s.removeLast()
            }
            return s
        }
        
        var body: some View {
            ZStack {
                Color.pantrySecondary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            HapticFeedback.light()
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.pantryHeadline)
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.22)))
                        }
                        
                        Spacer()
                        
                        Text("Step \(currentStepIndex + 1) of \(steps.count)")
                            .font(.pantrySubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, DesignTokens.spacingLG)
                    .padding(.bottom, DesignTokens.spacingMD)
                    
                    TabView(selection: $currentStepIndex) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            ScrollView {
                                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                                    Text(step)
                                        .font(.pantryTitle2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.white)
                                        .lineSpacing(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    let stepIngredients = ingredients(for: step)
                                    
                                    if !stepIngredients.isEmpty {
                                        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                            Text("Ingredients")
                                                .font(.pantrySubheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.white.opacity(0.78))
                                            
                                            ForEach(stepIngredients) { ingredient in
                                                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingSM) {
                                                    if !ingredient.quantity.isEmpty {
                                                        let q = scaledQuantity(for: ingredient)
                                                        HStack(spacing: 6) {
                                                            Text(q.text)
                                                                .font(.pantryTitle3)
                                                                .fontWeight(.semibold)
                                                                .foregroundStyle(Color.white)
                                                            if let factor = q.scaleFactorToShow {
                                                                if factor > 0 {
                                                                    Text("× \(factor)")
                                                                        .font(.pantrySubheadline)
                                                                        .fontWeight(.semibold)
                                                                        .foregroundStyle(Color.white.opacity(0.88))
                                                                } else {
                                                                    Text("/ \(-factor)")
                                                                        .font(.pantrySubheadline)
                                                                        .fontWeight(.semibold)
                                                                        .foregroundStyle(Color.white.opacity(0.88))
                                                                }
                                                            }
                                                        }
                                                    }
                                                    Text(ingredient.name)
                                                        .font(.pantryTitle3)
                                                        .fontWeight(.regular)
                                                        .foregroundStyle(Color.white.opacity(0.95))
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, DesignTokens.spacingXL)
                                .padding(.top, DesignTokens.spacingXL)
                                .padding(.bottom, DesignTokens.spacingXL)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    .tint(.white)
                }
            }
        }
    }
    
    var body: some View {
        if let recipe = recipe {
            ZStack {
                Color.pantryBackground
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            headerImageSection(recipe: recipe)
                            contentCard(recipe: recipe)
                        }
                        .frame(width: geometry.size.width - (landscapeHorizontalPadding * 2))
                        .padding(.horizontal, landscapeHorizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .clipped()
                }

                if showingRecipePlanBubble {
                    RecipePlanPickerBubble(
                        viewModel: viewModel,
                        recipeId: recipe.id,
                        recipeName: recipe.name,
                        onDismiss: { showingRecipePlanBubble = false }
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .animation(.easeOut(duration: 0.22), value: showingRecipePlanBubble)
            .id("\(recipe.id)-\(recipe.isGeneratingImage)-\(recipe.imageURL ?? "no-image")") // Force refresh when recipe state changes
            .background(Color.pantryBackground.ignoresSafeArea()) // Ensure background covers everything
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar) // Hide tab bar for full screen experience
            .ignoresSafeArea(edges: .top) // Extend to top edge
            .background(Color.pantryBackground.ignoresSafeArea()) // Ensure background covers everything
            .task(id: recipeNutritionFetchSignature(for: recipe) + "|pro:\(revenueCatService.isProMember)") {
                if revenueCatService.isProMember {
                    await fetchRecipeNutrition(for: recipe)
                } else {
                    await MainActor.run {
                        recipeNutrition = nil
                        recipeNutritionError = nil
                        recipeNutritionLoading = false
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                // Floating back button
                Button {
                    HapticFeedback.light()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.pantryHeadline)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.42)))
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }
            .sheet(isPresented: $showingModifySheet) {
                ModifyRecipeView(viewModel: viewModel, recipe: recipe, isPresented: $showingModifySheet)
            }
            .sheet(isPresented: $showingReportSheet) {
                FeedbackFormView(feedbackType: .bug)
            }
            .sheet(isPresented: $showingAddToGrocerySheet) {
                SingleRecipeAddToGrocerySheet(recipe: recipe, viewModel: viewModel)
            }
            .sheet(isPresented: $showingChefTipsSheet) {
                if let tips = recipe.tips, !tips.isEmpty {
                    ChefTipsSheet(tips: tips)
                }
            }
            .sheet(isPresented: $showingNutritionSheet) {
                NutritionSheet(recipe: recipe, recipeNutrition: recipeNutrition, recipeNutritionLoading: recipeNutritionLoading, recipeNutritionError: recipeNutritionError, nutritionPerServingScaleFactor: nutritionPerServingScaleFactor(for: recipe))
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if viewModel.isModifyingRecipe {
                    RecipeModifyLoadingView()
                }
            }
            .fullScreenCover(isPresented: $showingFullImage) {
                FullScreenImageView(imageURL: recipe.imageURL, isPresented: $showingFullImage)
            }
            .sheet(isPresented: recipeDetailPaywallBinding) {
                PaywallView(scenario: .upgrade, isPresented: recipeDetailPaywallBinding)
            }
            .fullScreenCover(isPresented: $showStepFocusMode) {
                StepByStepCookingView(
                    recipe: recipe,
                    servings: currentServings(for: recipe),
                    isPresented: $showStepFocusMode
                )
            }
            .onAppear {
                viewModel.isShowingRecipeDetail = true
                
                if keepScreenAwakePreference && !hasAppliedWakeLock {
                    ScreenWakeLockManager.shared.acquire()
                    hasAppliedWakeLock = true
                }
                
                AppAnalytics.log(.recipeViewed, parameters: [
                    "recipe_name": recipe.name,
                    "is_from_favorites": isFromFavorites
                ])
            }
            .onDisappear {
                viewModel.isShowingRecipeDetail = false
                
                if hasAppliedWakeLock {
                    ScreenWakeLockManager.shared.release()
                    hasAppliedWakeLock = false
                }
            }
            .onChange(of: keepScreenAwakePreference) { newValue in
                if newValue {
                    if !hasAppliedWakeLock {
                        ScreenWakeLockManager.shared.acquire()
                        hasAppliedWakeLock = true
                    }
                } else if hasAppliedWakeLock {
                    ScreenWakeLockManager.shared.release()
                    hasAppliedWakeLock = false
                }
            }
        } else {
            VStack {
                Text("Recipe not found")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - View Components
    
    private func headerImageSection(recipe: Recipe) -> some View {
        GeometryReader { geometry in
            let scrollOffset = geometry.frame(in: .global).minY
            let parallaxSpeed: CGFloat = 0.3
            let parallaxOffset = scrollOffset < 0 ? abs(scrollOffset) * (1 - parallaxSpeed) : 0
            let stretchHeight = scrollOffset > 0 ? headerHeight + scrollOffset : headerHeight
            let offsetY = scrollOffset < 0 ? parallaxOffset : 0
            
            Group {
                if recipe.isGeneratingImage {
                    RecipeDetailImageSkeleton(message: "Generating image...")
                } else if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .onTapGesture {
                                HapticFeedback.light()
                                showingFullImage = true
                            }
                    } placeholder: {
                        RecipeDetailImageSkeleton(message: nil)
                    }
                } else {
                    Button {
                        HapticFeedback.medium()
                        Task {
                            await viewModel.generateRecipeImage(recipeId: recipe.id)
                        }
                    } label: {
                        Rectangle()
                            .fill(Color.pantrySurface)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.pantryTitle)
                                        .foregroundColor(.pantryPrimary)
                                    Text("Tap to Generate Image")
                                        .font(.pantrySubheadline)
                                        .foregroundColor(.pantryPrimary)
                                }
                                .padding(.top, 60)
                            }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: geometry.size.width, height: stretchHeight)
            .clipped()
            .offset(y: offsetY)
        }
        .frame(height: headerHeight)
    }
    
    private func contentCard(recipe: Recipe) -> some View {
        return VStack(alignment: .leading, spacing: LayoutHelpers.sectionSpacing) {
            headerSection(recipe: recipe)
            recipeTimeSection(recipe: recipe, servings: servingsBinding(for: recipe))
            recipeCookbookContextRow(recipe: recipe)
            actionPillsRow(recipe: recipe)
            Divider().background(Color.pantryBorder.opacity(0.45))
            pantryMatchScoreSection(recipe: recipe)
            ingredientsSection(recipe: recipe, servings: servingsBinding(for: recipe))
            Divider().background(Color.pantryBorder.opacity(0.45))
            stepsSection(recipe: recipe)
            Divider().background(Color.pantryBorder.opacity(0.45))
            if let sourceMessage = recipeSourceMessage(for: recipe) {
                sourceMessage
                    .padding(.horizontal)
                    .padding(.vertical, DesignTokens.spacingSM)
            }
            Button {
                HapticFeedback.light()
                showingReportSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.pantrySubheadline)
                    Text("Report Issue")
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.pantryTextSecondary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, LayoutHelpers.recipeDetailContentPadding)
        .padding(.bottom, LayoutHelpers.cardPadding)
        .background(Color.pantryBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: DesignTokens.radiusLarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DesignTokens.radiusLarge
            )
        )
        .offset(y: -20)
        .frame(maxWidth: .infinity)
    }
    
    private func headerSection(recipe: Recipe) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(recipe.name)
                .font(.pantryLargeTitle)
                .fontWeight(.bold)
                .foregroundColor(.pantryPrimary)
                .multilineTextAlignment(.center)
            
            Text(recipe.description)
                .font(.pantryBody)
                .foregroundColor(.pantryTextSecondary)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity) // Ensure it takes full width to center properly
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    private func recipeTimeSection(recipe: Recipe, servings: Binding<Int>) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 0) {
                if let prep = recipe.prepTimeMinutes {
                    StatView(icon: "timer", value: "\(prep)m", label: "Prep Time", color: .pantryPrimary)
                }
                
                if let cook = recipe.cookTimeMinutes {
                    StatView(icon: "flame.fill", value: "\(cook)m", label: "Cook Time", color: .pantrySecondary)
                }
                
                if let prep = recipe.prepTimeMinutes, let cook = recipe.cookTimeMinutes {
                    StatView(icon: "clock.fill", value: "\(prep + cook)m", label: "Total Time", color: .pantryPrimary)
                } else if let prep = recipe.prepTimeMinutes {
                    StatView(icon: "clock.fill", value: "\(prep)m", label: "Total Time", color: .pantryPrimary)
                } else if let cook = recipe.cookTimeMinutes {
                    StatView(icon: "clock.fill", value: "\(cook)m", label: "Total Time", color: .pantryPrimary)
                }
            }
            
            Divider()
                .background(Color.pantryBorder.opacity(0.45))
                .padding(.horizontal)
            
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.pantryHeadline)
                        .foregroundColor(.pantrySecondary)

                    Text("\(servings.wrappedValue)")
                        .font(.pantryHeadline)
                        .foregroundColor(.pantryTextPrimary)

                    Text("Servings")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }
                .frame(maxWidth: .infinity)

                if let difficulty = recipe.difficulty {
                    StatView(icon: "star.fill", value: "\(difficulty)/5", label: "Difficulty", color: .orange)
                }
                
                StatView(icon: "cart.fill", value: "\(recipe.ingredients.count)", label: "Ingredients", color: .pantryPrimary)
            }
        }
        .padding(.vertical, DesignTokens.spacingMD)
        .padding(.horizontal)
    }

    private func recipeCookbookContextRow(recipe: Recipe) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
            Image(systemName: "books.vertical.fill")
                .font(.pantryTitle3)
                .foregroundColor(.pantrySecondary)
                .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cookbook")
                    .font(.pantryCaption2)
                    .fontWeight(.medium)
                    .foregroundColor(.pantryTextSecondary)
                Text(currentCookbook?.name ?? "Not in a cookbook")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                if let current = currentCookbook {
                    ForEach(viewModel.cookbooks.filter { $0.id != current.id }) { cookbook in
                        Button(cookbook.name) {
                            HapticFeedback.light()
                            viewModel.moveRecipeToCookbook(
                                recipeId: recipe.id,
                                fromCookbookId: current.id,
                                toCookbookId: cookbook.id
                            )
                        }
                    }
                    Divider()
                    Button("Discard Recipe", role: .destructive) {
                        HapticFeedback.medium()
                        viewModel.removeRecipeFromCookbook(recipeId: recipe.id, cookbookId: current.id)
                        if isFromFavorites {
                            dismiss()
                        }
                    }
                } else {
                    ForEach(viewModel.cookbooks) { cookbook in
                        Button(cookbook.name) {
                            HapticFeedback.medium()
                            viewModel.addRecipeToCookbook(
                                recipeId: recipe.id,
                                cookbookId: cookbook.id,
                                navigateToCookbooksTab: false
                            )
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentCookbook != nil ? "Change" : "Add")
                        .font(.pantryCaption)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.pantryCaption2.weight(.semibold))
                }
                .foregroundColor(.pantryPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.pantryPrimary.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.pantryPrimary.opacity(0.28), lineWidth: 1)
                )
            }
            .accessibilityLabel(currentCookbook != nil ? "Change cookbook" : "Add to cookbook")
        }
        .padding(.horizontal)
        .padding(.top, DesignTokens.spacingMD)
    }

    private func actionPillsRow(recipe: Recipe) -> some View {
        let shareURL = URL(string: "https://reciplease.info/recipes/shared/\(recipe.id.uuidString.lowercased())")!
        let hasTips = !(recipe.tips ?? []).isEmpty
        let hasNutrition = !recipe.nonEmptyRecipeIngredientLines.isEmpty

        return FlowLayout(spacing: 8) {
            // Modify
            Button {
                HapticFeedback.light()
                showingModifySheet = true
            } label: {
                actionPillLabel(icon: "pencil", text: "Modify", tint: .pantryPrimary)
            }
            .buttonStyle(.plain)

            // Share
            ShareLink(item: shareURL) {
                actionPillLabel(icon: "square.and.arrow.up", text: "Share", tint: .pantryTextPrimary, background: Color.pantrySurface, stroke: Color.pantryBorderSubtle)
            }
            .buttonStyle(.plain)

            // Add to Meal Plan
            Button {
                HapticFeedback.light()
                showingRecipePlanBubble = true
            } label: {
                actionPillLabel(icon: "calendar", text: "Add to Meal Plan", tint: .pantrySecondary)
            }
            .buttonStyle(.plain)

            if hasTips {
                Button {
                    HapticFeedback.light()
                    showingChefTipsSheet = true
                } label: {
                    actionPillLabel(icon: "lightbulb.fill", text: "Chef Tips", tint: .pantryPrimary)
                }
                .buttonStyle(.plain)
            }

            if hasNutrition {
                Button {
                    HapticFeedback.light()
                    showingNutritionSheet = true
                } label: {
                    actionPillLabel(icon: "chart.bar.fill", text: "Nutritional Info", tint: .pantrySecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LayoutHelpers.recipeDetailContentPadding)
        .padding(.top, DesignTokens.spacingMD)
    }

    private func actionPillLabel(icon: String, text: String, tint: Color, background: Color? = nil, stroke: Color? = nil) -> some View {
        let bg = background ?? tint.opacity(0.12)
        let str = stroke ?? tint.opacity(0.28)
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.pantrySubheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(bg))
        .overlay(Capsule().stroke(str, lineWidth: 1))
    }
    
    private func recipeSourceMessage(for recipe: Recipe) -> AnyView? {
        guard let normalizedSourceName = recipe.source?.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !normalizedSourceName.isEmpty else {
            return nil
        }

        if normalizedSourceName.contains("web") || normalizedSourceName.contains("url") {
            if let sourceURLString = recipe.source?.url,
               let sourceURL = URL(string: sourceURLString),
               let sourceHost = sourceURL.host,
               !sourceHost.isEmpty {
                return AnyView(
                    (
                        Text("This recipe was scanned from a web page: ")
                            .foregroundColor(.pantryTextSecondary)
                        +
                        Text(.init("[\(sourceHost)](\(sourceURL.absoluteString))"))
                            .foregroundColor(.pantryPrimary)
                    )
                    .font(.pantrySubheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                )
            } else {
                return AnyView(
                    Text("This recipe was scanned from a web page.")
                        .font(.pantrySubheadline)
                        .foregroundColor(.pantryTextSecondary)
                        .multilineTextAlignment(.leading)
                )
            }
        } else if normalizedSourceName.contains("cookbook") {
            return AnyView(
                Text("This recipe was scanned from a cookbook.")
                    .font(.pantrySubheadline)
                    .foregroundColor(.pantryTextSecondary)
                    .multilineTextAlignment(.leading)
            )
        } else {
            return nil
        }
    }
    
    private func ingredientsSection(recipe: Recipe, servings: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .center, spacing: 8) {
                Text("Ingredients")
                    .font(.pantryTitle)
                    .foregroundColor(.pantryTextPrimary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // Servings stepper (left) + meal plan & grocery actions (right)
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        let newValue = max(servings.wrappedValue - 1, 1)
                        servings.wrappedValue = newValue
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.pantryCustom(size: 24, weight: .semibold))
                            .foregroundColor(.pantryPrimary)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 4) {
                        Text("\(servings.wrappedValue)")
                            .font(.pantryHeadline)
                            .foregroundColor(.pantryTextPrimary)

                        Text("servings")
                            .font(.pantryBody)
                            .foregroundColor(.pantryTextSecondary)
                    }

                    Button {
                        let newValue = min(servings.wrappedValue + 1, 20)
                        servings.wrappedValue = newValue
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.pantryCustom(size: 24, weight: .semibold))
                            .foregroundColor(.pantryPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    showingAddToGrocerySheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add to Grocery List")
                            .font(.pantryCaption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundColor(.pantryPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.pantryPrimary.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.pantryPrimary.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.pantryCaption2)
                        .foregroundColor(.green)
                    Text("In pantry")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Staple")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "cart.badge.plus")
                        .font(.pantryCaption2)
                        .foregroundColor(.orange)
                    Text("Need")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    let quantityResult = scaledQuantity(
                        ingredient.quantity,
                        recipeServings: recipe.servings,
                        currentServings: servings.wrappedValue
                    )
                    RecipeDetailPantryStyleIngredientRow(
                        ingredient: ingredient,
                        quantityResult: quantityResult,
                        inPantry: viewModel.recipeIngredientInUserPantry(ingredient.name),
                        staple: viewModel.recipeIngredientIsPantryStaple(ingredient.name)
                    )
                    if index < recipe.ingredients.count - 1 {
                        Divider()
                            .background(Color.pantryBorder.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func pantryMatchScoreSection(recipe: Recipe) -> some View {
        let breakdown = viewModel.pantryMatchBreakdown(for: recipe)
        let percent = Int((breakdown.score * 100).rounded())

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.pantryBorderSubtle, lineWidth: 8)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: breakdown.score)
                    .stroke(
                        Color.pantryPrimary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)

                Text("\(percent)")
                    .font(.pantryHeadline)
                    .fontWeight(.bold)
                    .foregroundColor(.pantryTextPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pantry Match Score")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)

                Text("\(breakdown.matchedIngredientCount) of \(breakdown.totalIngredientCount) ingredients match your pantry or staples.")
                    .font(.pantryCaption)
                    .foregroundColor(.pantryTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, LayoutHelpers.recipeDetailContentPadding)
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private func stepsSection(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.pantryTitle)
                .foregroundColor(.pantryTextPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Keep Screen Awake toggle
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "display.sleep")
                    .font(.pantryHeadline)
                    .foregroundColor(.pantryPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Screen Awake")
                        .font(.pantryBody)
                        .foregroundColor(.pantryTextPrimary)
                    Text("Prevent the display from sleeping while cooking.")
                        .font(.pantryCaption)
                        .foregroundColor(.pantryTextSecondary)
                }

                Spacer()

                Toggle("", isOn: $keepScreenAwakePreference)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .pantryPrimary))
            }
            .padding(.horizontal)

            HStack {
                Button {
                    HapticFeedback.light()
                    showStepFocusMode = true
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.pantryCustom(size: DesignTokens.iconMedium, weight: .semibold))
                        Text("Cooking Mode")
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(Color.pantrySurface)
                    .foregroundColor(.pantryPrimary)
                    .cornerRadius(DesignTokens.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .stroke(Color.pantryPrimary.opacity(0.35), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, LayoutHelpers.recipeDetailContentPadding)
            
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.pantryPrimary)
                            .frame(width: 36, height: 36)

                        Text("\(index + 1)")
                            .font(.pantryHeadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text(step)
                        .font(.pantryBody)
                        .foregroundColor(.pantryTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
        }
    }

}

// MARK: - Chef Tips Sheet

private struct ChefTipsSheet: View {
    let tips: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.pantrySubheadline)
                                .foregroundColor(.pantryPrimary)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.pantryBody)
                                .foregroundColor(.pantryTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal)
                        if index < tips.count - 1 {
                            Divider()
                                .background(Color.pantryBorder.opacity(0.45))
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Chef Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color.pantryBackground)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Nutrition Sheet

private struct NutritionSheet: View {
    let recipe: Recipe
    let recipeNutrition: PantryNutritionResult?
    let recipeNutritionLoading: Bool
    let recipeNutritionError: String?
    let nutritionPerServingScaleFactor: Double
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var usageTracker = UsageTracker.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if revenueCatService.isProMember {
                        if recipeNutritionLoading && recipeNutrition == nil && recipeNutritionError == nil {
                            NutritionEstimateLoadingPlaceholder(
                                compact: false,
                                heroSubtitle: "Per serving",
                                prominentEnergyAndFiberSodium: true
                            )
                            .padding(.horizontal)
                        }

                        if let err = recipeNutritionError, !err.isEmpty {
                            Text(err)
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal)
                        }

                        if let nutrition = recipeNutrition {
                            let perServing = nutrition.scaled(by: nutritionPerServingScaleFactor)
                            NutritionEstimateRichLayout(
                                result: perServing,
                                compact: false,
                                heroSubtitle: "Per serving",
                                prominentEnergyAndFiberSodium: true
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        NutritionEstimateProLockedCard(compact: false) {
                            usageTracker.shouldShowPaywall = true
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Nutritional Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color.pantryBackground)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Recipe ingredient row (read-only pantry layout)

private struct RecipeIngredientPantryStatusDot: View {
    let inPantry: Bool
    let staple: Bool

    private var accessibilityDescription: String {
        if inPantry { return "In pantry" }
        if staple { return "Staple" }
        return "Need"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    inPantry ? Color.green.opacity(0.15) :
                        staple ? Color.green.opacity(0.15) :
                        Color.orange.opacity(0.15)
                )
                .frame(width: 28, height: 28)

            if inPantry {
                Image(systemName: "checkmark.circle.fill")
                    .font(.pantryCaption)
                    .foregroundColor(.green)
            } else if staple {
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "cart.badge.plus")
                    .font(.pantryCaption)
                    .foregroundColor(.orange)
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }
}

private struct RecipeDetailPantryStyleIngredientRow: View {
    let ingredient: RecipeIngredient
    let quantityResult: (text: String, scaleFactorToShow: Int?)
    let inPantry: Bool
    let staple: Bool

    private var needsGrocery: Bool {
        !inPantry && !staple
    }

    var body: some View {
        HStack(alignment: .center, spacing: PantryIngredientListMetrics.rowHPadding) {
            RecipeIngredientPantryStatusDot(inPantry: inPantry, staple: staple)
                .frame(width: PantryIngredientListMetrics.recipePantryStatusColumnWidth, alignment: .center)

            IngredientPantryLeadingIcon(icon: getIngredientIcon(for: ingredient.name))

            VStack(alignment: .leading, spacing: PantryIngredientListMetrics.textVSpacing) {
                Text(ingredient.name)
                    .font(.pantryBody)
                    .fontWeight(.bold)
                    .foregroundColor(.pantryTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                secondLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var secondLine: some View {
        if !ingredient.quantity.isEmpty {
            HStack(spacing: 4) {
                Text(quantityResult.text)
                if let factor = quantityResult.scaleFactorToShow {
                    if factor > 0 {
                        Text("× \(factor)")
                    } else {
                        Text("/ \(-factor)")
                    }
                }
            }
            .font(.pantrySubheadline)
            .fontWeight(.medium)
            .foregroundColor(.pantrySecondary)
        } else if needsGrocery {
            Text("Not in pantry")
                .font(.pantryCaption2)
                .foregroundColor(.orange)
        }
    }
}

// MARK: - Recipe Detail Image Skeleton

struct RecipeDetailImageSkeleton: View {
    var message: String?
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base color
            Rectangle()
                .fill(Color.pantryTextSecondary.opacity(0.1))
            
            // Shimmer overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.25),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: phase * 600 - 300)
            
            // Optional message
            if let message = message {
                VStack(spacing: 12) {
                    // Pulsing icon
                    Image(systemName: "sparkles")
                        .font(.pantryTitle)
                        .foregroundColor(.pantryPrimary.opacity(0.6))
                        .symbolEffect(.pulse)
                    
                    Text(message)
                        .font(.pantrySubheadline)
                        .foregroundColor(.pantryTextSecondary)
                }
                .padding(.top, 60) // Match the "Tap to Generate" button positioning
            }
        }
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

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.pantryHeadline)
                .foregroundColor(color)
            Text(value)
                .font(.pantryHeadline)
                .foregroundColor(.pantryTextPrimary)
            Text(label)
                .font(.pantryCaption)
                .foregroundColor(.pantryTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ModifyRecipeView: View {
    @ObservedObject var viewModel: PantryViewModel
    let recipe: Recipe
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var promptText = ""
    @State private var errorMessage: String?

    private var promptTextBinding: Binding<String> {
        Binding(
            get: { promptText },
            set: { newValue in
                if newValue.count <= AppConfig.maxModifyPromptLength {
                    promptText = newValue
                    errorMessage = nil
                }
            }
        )
    }

    private var isPromptValid: Bool {
        promptText.count <= AppConfig.maxModifyPromptLength
    }

    private var trimmedPrompt: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitModify: Bool {
        !trimmedPrompt.isEmpty && isPromptValid && !viewModel.isModifyingRecipe
    }

    var body: some View {
        PantryQuickActionSheetShell(minDetentHeight: 460) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
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
                .padding(.bottom, DesignTokens.spacingXS)

                PantryQuickActionSheetChrome.sheetTitle("Modify Recipe")

                PantryQuickActionSheetChrome.sectionHeader("Your request", isFirst: true)

                Text("Describe how you'd like to change this recipe. For example: make it vegetarian, reduce cooking time, or add more spice.")
                    .font(.pantryCaption)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, DesignTokens.spacingSM)

                TextEditor(text: promptTextBinding)
                    .frame(minHeight: 168)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color.pantryTextPrimary)
                    .background(Color.pantryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.32), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Text("\(promptText.count)/\(AppConfig.maxModifyPromptLength)")
                        .font(.pantryCaption)
                        .foregroundStyle(isPromptValid ? Color.white.opacity(0.65) : Color(red: 1, green: 0.88, blue: 0.86))
                }
                .padding(.top, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.pantryCaption)
                        .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }

                Button {
                    guard isPromptValid else {
                        errorMessage = ValidationError.modifyPromptTooLong(maxLength: AppConfig.maxModifyPromptLength).localizedDescription
                        return
                    }
                    HapticFeedback.medium()
                    Task {
                        await viewModel.modifyRecipe(recipeId: recipe.id, prompt: trimmedPrompt)
                    }
                    dismiss()
                } label: {
                    Text("Modify recipe")
                        .font(.pantryHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(canSubmitModify ? Color.pantryPrimary : Color.gray.opacity(0.35))
                        .cornerRadius(14)
                }
                .disabled(!canSubmitModify)
                .padding(.top, DesignTokens.spacingMD)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecipeModifyLoadingView: View {
    var body: some View {
        EnhancedLoadingView(
            progressStages: LoadingMessages.modifyRecipeStages,
            funFacts: LoadingMessages.allFunFacts,
            estimatedDuration: 5.0,
            loadingImageName: "avi_pan_animated"
        )
    }
}

// Full screen image viewer
struct FullScreenImageView: View {
    let imageURL: String?
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let loadedImage):
                        loadedImage
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                        // Snap back if too small
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .font(.pantryLargeTitle)
                                .foregroundColor(.pantryTextSecondary)
                            Text("Failed to load image")
                                .foregroundColor(.pantryTextSecondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticFeedback.light()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.pantryTitle)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .statusBar(hidden: true)
    }
}
