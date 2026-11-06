//
//  IngredientsView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI

/// Used with `navigationDestination(item:)` so pantry match rows push recipe detail on the main Pantry stack.
private struct PantryMatchListNavigationItem: Hashable {
    let id: UUID
}

struct IngredientsView: View {
    @ObservedObject var viewModel: PantryViewModel
    @ObservedObject private var generationCredits = GenerationCreditsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    /// Presents the same pantry photo scan flow as the top bar quick actions (+) button.
    var onRequestIngredientScan: () -> Void
    /// Parent presents the destructive confirmation dialog.
    var onRequestClearIngredients: () -> Void

    init(
        viewModel: PantryViewModel,
        onRequestClearIngredients: @escaping () -> Void = {},
        onRequestIngredientScan: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onRequestClearIngredients = onRequestClearIngredients
        self.onRequestIngredientScan = onRequestIngredientScan
    }

    @State private var showingRecipePrompt = false
    @State private var searchText = ""
    @State private var insightsPillExpanded = false
    @State private var suggestedRecipesPillExpanded = false
    /// Pushes `RecipeDetailView` on the main Pantry `NavigationStack` (not inside the matches popover).
    @State private var pantryMatchDetailNavigationItem: PantryMatchListNavigationItem?

    private let pantryMatchesListLimit = 5

    /// Expand/collapse only — avoid animating insights/match *content* (score resorting was retriggering springs).
    private var pantryPillEaseAnimation: Animation {
        if accessibilityReduceMotion {
            return .easeInOut(duration: 0.16)
        }
        return .easeInOut(duration: 0.22)
    }

    // Filtered ingredients based on search
    private var filteredIngredients: [Ingredient] {
        if searchText.isEmpty {
            return viewModel.ingredients.sorted(by: { $0.generalName < $1.generalName })
        } else {
            return viewModel.ingredients.filter { ingredient in
                ingredient.generalName.localizedCaseInsensitiveContains(searchText) ||
                ingredient.specificName?.localizedCaseInsensitiveContains(searchText) ?? false
            }.sorted(by: { $0.generalName < $1.generalName })
        }
    }

    private var sortedPantryMatchRecipes: [Recipe] {
        viewModel.pantryMatchRecipesSortedByScore
    }

    private var visiblePantryMatchRecipes: [Recipe] {
        Array(sortedPantryMatchRecipes.prefix(pantryMatchesListLimit))
    }

    var body: some View {
        List {
            pantryInsightsMatchesPillsHeader
                .padding(.top, 4)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            pantryIngredientSearchBar
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Button {
                HapticFeedback.light()
                onRequestIngredientScan()
            } label: {
                ScanIngredientsPantryRow()
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 4, trailing: 14))
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
            .listRowBackground(Color.clear)

            AddIngredientInPlaceRow(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                .listRowBackground(Color.clear)

            ForEach(filteredIngredients) { ingredient in
                IngredientInPlaceRow(viewModel: viewModel, ingredient: ingredient)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowSeparator(.visible, edges: .bottom)
                    .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticFeedback.medium()
                            withAnimation {
                                viewModel.removeIngredient(ingredient)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .mainTabRootNavigationChrome(
            title: MainTabNavigationCopy.pantryNavigationTitle(ingredientCount: viewModel.ingredients.count)
        )
        .navigationDestination(item: $pantryMatchDetailNavigationItem) { item in
            RecipeDetailView(viewModel: viewModel, recipeId: item.id, isFromFavorites: false)
        }
        .background(Color.pantryBackground)
        .sheet(isPresented: $showingRecipePrompt) {
            TonightMenuSheet(viewModel: viewModel, isPresented: $showingRecipePrompt, onScanPantry: onRequestIngredientScan)
                .onAppear { viewModel.isShowingRecipePrompt = true }
                .onDisappear { viewModel.isShowingRecipePrompt = false }
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
        .alert("No Recipes Generated", isPresented: $viewModel.showNoRecipesAlert) {
            Button("Try Again") {
                viewModel.showNoRecipesAlert = false
            }
        } message: {
            Text("We were unable to create any recipes with your current preferences. Please try again with different preferences or ingredients.")
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isGeneratingRecipes },
            set: { _ in }
        )) {
            RecipeGenerationLoadingView()
                .background(Color.pantryPrimary.ignoresSafeArea())
        }
        .onChange(of: insightsPillExpanded) { _, expanded in
            guard expanded else { return }
            guard !viewModel.ingredients.isEmpty else { return }
            guard viewModel.pantryInsights.isEmpty else { return }
            viewModel.fetchPantryInsights()
        }
    }

    /// Ingredient-only field (not `.searchable`) so it lives in the list with pills and scrolls away with the page.
    private var pantryIngredientSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.pantryBody.weight(.medium))
                .foregroundColor(.pantryTextSecondary)

            TextField("Search ingredients…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.pantryBody)
                .foregroundColor(.pantryTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    HapticFeedback.light()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.pantryBody)
                        .foregroundColor(.pantryTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.pantrySurface.opacity(colorScheme == .dark ? 0.55 : 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.pantryBorder.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search ingredients")
    }

    private var pantryInsightsMatchesPillsHeader: some View {
        FlowLayout(spacing: 8) {
            PantryPillButton(title: "Insights", tint: .pantryPrimary, isExpanded: insightsPillExpanded) {
                HapticFeedback.light()
                withAnimation(pantryPillEaseAnimation) {
                    if insightsPillExpanded {
                        insightsPillExpanded = false
                    } else {
                        insightsPillExpanded = true
                        suggestedRecipesPillExpanded = false
                    }
                }
            }
            .popover(isPresented: $insightsPillExpanded, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                pantryInsightsPopoverBody
                    .presentationCompactAdaptation(.popover)
            }

            pantryClearIngredientsPill

            PantryPillButton(title: "Recipe Matches", tint: .pantrySecondary, isExpanded: suggestedRecipesPillExpanded) {
                HapticFeedback.light()
                withAnimation(pantryPillEaseAnimation) {
                    if suggestedRecipesPillExpanded {
                        suggestedRecipesPillExpanded = false
                    } else {
                        suggestedRecipesPillExpanded = true
                        insightsPillExpanded = false
                    }
                }
            }
            .popover(isPresented: $suggestedRecipesPillExpanded, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                pantryMatchesPopoverBody
                    .presentationCompactAdaptation(.popover)
            }

            PantryPillButton(title: "What sounds good?", tint: .pantryPrimary, isExpanded: false) {
                HapticFeedback.medium()
                showingRecipePrompt = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasIngredients: Bool {
        !viewModel.ingredients.isEmpty
    }

    private var pantryClearIngredientsPill: some View {
        let fillOpacity = colorScheme == .dark ? 0.26 : 0.16
        let strokeOpacity = colorScheme == .dark ? 0.45 : 0.32
        let enabled = hasIngredients

        return Button {
            guard enabled else { return }
            HapticFeedback.light()
            onRequestClearIngredients()
        } label: {
            Text("Clear")
                .font(.pantrySubheadline)
                .fontWeight(.semibold)
                .foregroundColor(enabled ? Color.pantryTextPrimary : Color.pantryTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.pantryError.opacity(enabled ? fillOpacity : fillOpacity * 0.35))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.pantryError.opacity(enabled ? strokeOpacity : strokeOpacity * 0.4), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Clear pantry")
    }

    /// Bubble content for Insights (popover).
    private var pantryInsightsPopoverBody: some View {
        ScrollView {
            pantryInsightsDropdownContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: min(300, UIScreen.main.bounds.width - 40), idealWidth: 320, maxHeight: 380)
        .padding(DesignTokens.spacingMD)
        .background(Color.pantrySurface)
    }

    /// Bubble content for Suggested Recipes (popover). Taps push recipe detail on the main navigation stack.
    private var pantryMatchesPopoverBody: some View {
        ScrollView {
            pantryMatchesDropdownContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: min(300, UIScreen.main.bounds.width - 40), idealWidth: 340, maxHeight: 420)
        .padding(DesignTokens.spacingMD)
        .background(Color.pantrySurface)
    }



    private var pantryInsightsDropdownContent: some View {
        Group {
            if viewModel.isLoadingInsights && viewModel.pantryInsights.isEmpty {
                HStack(spacing: DesignTokens.spacingSM) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.pantryTextSecondary)
                    Text("Analyzing your pantry…")
                        .font(.pantrySubheadline)
                        .foregroundColor(.pantryTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            } else if viewModel.pantryInsights.isEmpty {
                Text("Insights will appear here as your pantry changes.")
                    .font(.pantrySubheadline)
                    .foregroundColor(.pantryTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.pantryInsights.enumerated()), id: \.offset) { index, insight in
                        pantryInsightRowLikeIngredient(text: insight, index: index)
                        if index < viewModel.pantryInsights.count - 1 {
                            Divider()
                                .background(Color.pantryBorder.opacity(0.35))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func pantryInsightRowLikeIngredient(text: String, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PantryIngredientListMetrics.rowHPadding) {
            Image(systemName: insightIconSystemName(for: index))
                .font(.pantryTitle3.weight(.medium))
                .foregroundColor(.pantryPrimary)
                .frame(width: PantryIngredientListMetrics.iconColumnWidth, alignment: .center)

            Text(text)
                .font(.pantryBody)
                .foregroundColor(.pantryTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    /// Cycles cuisine → nutrition → brain for insight rows (and repeats for additional insights).
    private func insightIconSystemName(for index: Int) -> String {
        switch index % 3 {
        case 0: return "fork.knife"
        case 1: return "leaf.fill"
        default: return "brain.head.profile"
        }
    }

    private var pantryMatchesDropdownContent: some View {
        Group {
            if sortedPantryMatchRecipes.isEmpty {
                Text("Generate recipes or add cookbooks to see suggestions here.")
                    .font(.pantrySubheadline)
                    .foregroundColor(.pantryTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visiblePantryMatchRecipes.enumerated()), id: \.element.id) { index, recipe in
                        Button {
                            HapticFeedback.light()
                            suggestedRecipesPillExpanded = false
                            pantryMatchDetailNavigationItem = PantryMatchListNavigationItem(id: recipe.id)
                        } label: {
                            pantryMatchRow(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        if index < visiblePantryMatchRecipes.count - 1 {
                            Divider()
                                .background(Color.pantryBorder.opacity(0.45))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func pantryMatchRow(recipe: Recipe) -> some View {
        let score = min(max(viewModel.pantryMatchScore(for: recipe.id), 0), 1)
        let pct = Int((score * 100).rounded())
        let breakdown = viewModel.pantryMatchBreakdown(for: recipe)
        let meta = "On hand: \(breakdown.matchedIngredientCount)/\(breakdown.totalIngredientCount) | \(pct)% match"

        return RecipeRowContent(recipe: recipe, showChevron: false, pantryMatchMetadataLine: meta)
    }
}

struct AddIngredientView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var generalName = ""
    @State private var specificName = ""
    @State private var quantity = ""
    @State private var errorMessage: String?
    
    private var generalNameBinding: Binding<String> {
        Binding(
            get: { generalName },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    generalName = newValue
                }
            }
        )
    }
    
    private var specificNameBinding: Binding<String> {
        Binding(
            get: { specificName },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    specificName = newValue
                }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ingredient Details")) {
                    TextField("General Name (e.g., Milk)", text: generalNameBinding)
                    if generalName.count >= AppConfig.maxIngredientNameLength {
                        Text("\(AppConfig.maxIngredientNameLength) character limit")
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Specific Name (optional, e.g., Whole Milk)", text: specificNameBinding)
                    if specificName.count >= AppConfig.maxIngredientNameLength {
                        Text("\(AppConfig.maxIngredientNameLength) character limit")
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Quantity (e.g., 1 carton)", text: $quantity)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        do {
                            try viewModel.addIngredient(
                                generalName: generalName,
                                specificName: specificName.isEmpty ? nil : specificName,
                                quantity: quantity.isEmpty ? "1" : quantity
                            )
                            dismiss()
                        } catch let error as ValidationError {
                            errorMessage = error.localizedDescription
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(generalName.isEmpty)
                }
            }
        }
    }
}

struct EditIngredientView: View {
    @ObservedObject var viewModel: PantryViewModel
    let ingredient: Ingredient
    @Environment(\.dismiss) var dismiss
    
    @State private var generalName: String
    @State private var specificName: String
    @State private var quantity: String
    @State private var errorMessage: String?
    
    init(viewModel: PantryViewModel, ingredient: Ingredient) {
        self.viewModel = viewModel
        self.ingredient = ingredient
        _generalName = State(initialValue: ingredient.generalName)
        _specificName = State(initialValue: ingredient.specificName ?? "")
        _quantity = State(initialValue: ingredient.quantity ?? "")
    }
    
    private var generalNameBinding: Binding<String> {
        Binding(
            get: { generalName },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    generalName = newValue
                }
            }
        )
    }
    
    private var specificNameBinding: Binding<String> {
        Binding(
            get: { specificName },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    specificName = newValue
                }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ingredient Details")) {
                    TextField("General Name", text: generalNameBinding)
                    if generalName.count >= AppConfig.maxIngredientNameLength {
                        Text("\(AppConfig.maxIngredientNameLength) character limit")
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Specific Name (optional)", text: specificNameBinding)
                    if specificName.count >= AppConfig.maxIngredientNameLength {
                        Text("\(AppConfig.maxIngredientNameLength) character limit")
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Quantity", text: $quantity)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.pantryCaption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try viewModel.updateIngredient(
                                ingredient,
                                generalName: generalName,
                                specificName: specificName.isEmpty ? nil : specificName,
                                quantity: quantity.isEmpty ? "1" : quantity
                            )
                            HapticFeedback.success()
                            dismiss()
                        } catch let error as ValidationError {
                            errorMessage = error.localizedDescription
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(generalName.isEmpty)
                }
            }
        }
    }
}

private enum IngredientInPlaceField: Hashable {
    case general, quantity
}

private struct AddIngredientInPlaceRow: View {
    @ObservedObject var viewModel: PantryViewModel

    @State private var general = ""
    @State private var quantity = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: IngredientInPlaceField?

    private var trimmedGeneral: String {
        general.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var generalBinding: Binding<String> {
        Binding(
            get: { general },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    general = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: PantryIngredientListMetrics.rowHPadding) {
                Group {
                    if trimmedGeneral.isEmpty {
                        Image(systemName: "plus")
                            .font(.pantryCustom(size: 22, weight: .regular))
                            .foregroundColor(.pantryTextSecondary)
                            .frame(width: PantryIngredientListMetrics.iconColumnWidth, alignment: .center)
                    } else {
                        IngredientPantryLeadingIcon(icon: getIngredientIcon(for: trimmedGeneral))
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Ingredient name", text: generalBinding)
                        .textFieldStyle(.plain)
                        .font(.pantryBody)
                        .fontWeight(.bold)
                        .foregroundColor(.pantryTextPrimary)
                        .lineLimit(1)
                        .focused($focusedField, equals: .general)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .quantity }

                    TextField("Quantity", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pantrySecondary)
                        .lineLimit(1)
                        .padding(.top, -4)
                        .focused($focusedField, equals: .quantity)
                        .submitLabel(.done)
                        .onSubmit { commitAdd() }
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.pantryCaption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .onChange(of: focusedField) { _, new in
            if new == nil {
                attemptCommitAddOnBlur()
            }
        }
    }

    private func attemptCommitAddOnBlur() {
        let g = general.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else { return }
        commitAdd()
    }

    private func commitAdd() {
        errorMessage = nil
        let g = general.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else { return }
        do {
            try viewModel.addIngredient(
                generalName: g,
                specificName: nil,
                quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : quantity
            )
            HapticFeedback.success()
            general = ""
            quantity = ""
            focusedField = nil
        } catch let error as ValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IngredientInPlaceRow: View {
    @ObservedObject var viewModel: PantryViewModel
    let ingredient: Ingredient

    @State private var general: String
    @State private var quantity: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: IngredientInPlaceField?

    init(viewModel: PantryViewModel, ingredient: Ingredient) {
        self.viewModel = viewModel
        self.ingredient = ingredient
        _general = State(initialValue: ingredient.generalName)
        _quantity = State(initialValue: ingredient.quantity ?? "")
    }

    private var generalBinding: Binding<String> {
        Binding(
            get: { general },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    general = newValue
                }
            }
        )
    }

    private var leadingIcon: String {
        let key = general.trimmingCharacters(in: .whitespacesAndNewlines)
        return getIngredientIcon(for: key.isEmpty ? ingredient.generalName : key)
    }

    /// Preserved when saving from the pantry row (not shown or edited here).
    private var preservedSpecificName: String? {
        let trimmed = ingredient.specificName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return ingredient.specificName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: PantryIngredientListMetrics.rowHPadding) {
                IngredientPantryLeadingIcon(icon: leadingIcon)

                VStack(alignment: .leading, spacing: PantryIngredientListMetrics.textVSpacing) {
                    TextField("Ingredient name", text: generalBinding)
                        .textFieldStyle(.plain)
                        .font(.pantryBody)
                        .fontWeight(.bold)
                        .foregroundColor(.pantryTextPrimary)
                        .focused($focusedField, equals: .general)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .quantity }

                    TextField("Quantity", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pantrySecondary)
                        .focused($focusedField, equals: .quantity)
                        .submitLabel(.done)
                        .onSubmit { commitIfDirty() }
                    if ingredient.useSoon {
                        Text("Use Soon")
                            .font(.pantryCaption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(Color.orange)
                    }
                }
                Button {
                    viewModel.setIngredientPinned(id: ingredient.id, pinned: !ingredient.pinned)
                } label: {
                    Image(systemName: ingredient.pinned ? "star.fill" : "star")
                        .foregroundStyle(ingredient.pinned ? Color.pantryPrimary : Color.pantryTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ingredient.pinned ? "Unpin ingredient" : "Use this first")
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.pantryCaption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .contextMenu {
            Button("Use within 2 days") {
                let date = Calendar.current.date(byAdding: .day, value: 2, to: Date())
                viewModel.setIngredientExpiration(id: ingredient.id, date: date)
            }
            Button("Clear use-by date") {
                viewModel.setIngredientExpiration(id: ingredient.id, date: nil)
            }
        }
        .onChange(of: ingredient) { _, new in
            guard focusedField == nil else { return }
            general = new.generalName
            quantity = new.quantity ?? ""
        }
        .onChange(of: focusedField) { _, new in
            if new == nil {
                commitIfDirty()
            }
        }
    }

    private func normalizedQuantityInput() -> String {
        let q = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? "1" : q
    }

    private func commitIfDirty() {
        errorMessage = nil
        let g = general.trimmingCharacters(in: .whitespacesAndNewlines)
        if g.isEmpty {
            general = ingredient.generalName
            quantity = ingredient.quantity ?? ""
            return
        }

        let qtyFinal = normalizedQuantityInput()
        let priorQty = (ingredient.quantity?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "1"

        if g == ingredient.generalName,
           qtyFinal == priorQty {
            return
        }

        do {
            try viewModel.updateIngredient(
                ingredient,
                generalName: g,
                specificName: preservedSpecificName,
                quantity: qtyFinal
            )
            HapticFeedback.success()
        } catch let error as ValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Row content for List-based ingredient display (supports swipe actions)
struct IngredientRowContent: View {
    let ingredient: Ingredient
    var isExpanded: Bool = false
    var showsDisclosure: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                let icon = getIngredientIcon(for: ingredient.generalName)
                Group {
                    if icon.count == 1 {
                        Text(icon)
                            .font(.pantryCustom(size: 28))
                    } else {
                        Image(systemName: icon)
                            .font(.pantryTitle3)
                            .foregroundColor(.pantryPrimary)
                    }
                }
                .frame(width: 40, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    nameLine
                        .font(.pantryBody)
                        .foregroundColor(.pantryTextPrimary)
                        .multilineTextAlignment(.leading)

                    if let q = ingredient.quantity?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                        Text(q)
                            .font(.pantryBody)
                            .foregroundColor(.pantrySecondary)
                    }
                }

                Spacer(minLength: 8)

                if showsDisclosure {
                    Image(systemName: "chevron.down")
                        .font(.pantryCaption.weight(.semibold))
                        .foregroundColor(.pantryTextSecondary.opacity(0.55))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var nameLine: some View {
        if let spec = ingredient.specificName?.trimmingCharacters(in: .whitespacesAndNewlines), !spec.isEmpty {
            Text(ingredient.generalName).fontWeight(.bold)
                + Text(", ")
                + Text(spec).italic().foregroundColor(.pantryTextSecondary)
        } else {
            Text(ingredient.generalName).fontWeight(.bold)
        }
    }
}

// Legacy row view (keeping for reference)
struct IngredientRow: View {
    let ingredient: Ingredient
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        IngredientRowContent(ingredient: ingredient, onTap: onTap)
            .contextMenu {
                Button(action: onTap) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

// Legacy chip-based ingredient display (keeping for reference)
struct IngredientChip: View {
    let ingredient: Ingredient
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    let icon = getIngredientIcon(for: ingredient.generalName)
                    if icon.count == 1 {
                        // Emoji icon
                        Text(icon)
                            .font(.pantrySubheadline)
                    } else {
                        // SF Symbol icon
                        Image(systemName: icon)
                            .font(.pantryCaption)
                            .foregroundColor(.pantryPrimary)
                    }
                    
                    Text(ingredient.generalName)
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                if let quantity = ingredient.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(.pantryCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.pantrySecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.pantrySurface, Color.pantrySurface],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(Color.pantryTextPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.pantryShadow, lineWidth: 1)
            )
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// Reusable loading views with dynamic messages
struct RecipeGenerationLoadingView: View {
    var body: some View {
        EnhancedLoadingView(
            progressStages: LoadingMessages.generateRecipesStages,
            funFacts: LoadingMessages.allFunFacts,
            loadingImageName: "avi_pan_animated"
        )
    }
}


