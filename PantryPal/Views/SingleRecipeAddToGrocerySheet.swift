//
//  SingleRecipeAddToGrocerySheet.swift
//  PantryPal
//
//  Add scaled ingredient lines from one recipe to the grocery list (no plan-day chrome).
//

import SwiftUI

struct SingleRecipeAddToGrocerySheet: View {
    let recipe: Recipe
    @ObservedObject var viewModel: PantryViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var servings: Int = 1
    @State private var includeIngredient: [String: Bool] = [:]
    @State private var didLoad = false
    @State private var showingReplaceOrAddDialog = false
    @State private var pendingItemsForDialog: [(name: String, quantity: String)] = []

    private let maxServings = 99

    private var rowId: String { recipe.id.uuidString }

    var body: some View {
        PantryGenerateRecipeSheetShell(minDetentHeight: 520, sheetBackground: Color.pantryBackground) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.pantrySubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.pantryPrimary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, DesignTokens.spacingSM)

                Text("Add to Grocery List")
                    .font(.pantryTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.pantryTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, DesignTokens.spacingMD)

                lightSheetSectionDivider

                let lines = recipe.nonEmptyRecipeIngredientLines
                if lines.isEmpty {
                    emptyState
                } else {
                    recipeHeaderBlock(lines: lines)

                    lightSheetSectionDivider

                    addButton
                        .padding(.bottom, DesignTokens.spacingSM)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if !didLoad {
                reloadFromRecipe()
                didLoad = true
            }
        }
        .confirmationDialog(
            "What would you like to do with your grocery list?",
            isPresented: $showingReplaceOrAddDialog,
            titleVisibility: .visible
        ) {
            Button("Add to Grocery List") {
                HapticFeedback.medium()
                performAdd(pending: pendingItemsForDialog)
            }
            Button("Replace Grocery List") {
                HapticFeedback.medium()
                performReplace(pending: pendingItemsForDialog)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(viewModel.groceryItems.count) item\(viewModel.groceryItems.count == 1 ? "" : "s") in your grocery list. Would you like to add to it or replace it?")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }

    private var lightSheetSectionDivider: some View {
        Rectangle()
            .fill(Color.pantryBorder.opacity(0.45))
            .frame(height: 1)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingSM)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Image(systemName: "list.bullet.rectangle")
                .font(.pantryLargeTitle)
                .foregroundStyle(Color.pantryTextSecondary.opacity(0.45))
            Text("Nothing to add")
                .font(.pantryHeadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pantryTextPrimary)
            Text("This recipe has no ingredient lines to add.")
                .font(.pantrySubheadline)
                .foregroundStyle(Color.pantryTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.spacingMD)
    }

    private var selectedGroceryLineCount: Int {
        buildPendingGroceryLines().count
    }

    private var addToGroceryListButtonTitle: String {
        let n = selectedGroceryLineCount
        if n == 1 { return "Add 1 Item to Grocery List" }
        return "Add \(n) Items to Grocery List"
    }

    private var addButton: some View {
        Button {
            commitAdds()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cart.badge.plus")
                    .font(.pantryCustom(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                Text(addToGroceryListButtonTitle)
                    .font(.pantryHeadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(Color.pantryPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedGroceryLineCount == 0)
        .opacity(selectedGroceryLineCount == 0 ? 0.45 : 1)
    }

    private func recipeHeaderBlock(lines: [RecipeIngredient]) -> some View {
        let servingsBinding = Binding(
            get: { max(1, min(servings, maxServings)) },
            set: { servings = min(max(1, $0), maxServings) }
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                PlanSmallRecipeThumbnail(recipe: recipe, size: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.pantryBorder.opacity(0.35), lineWidth: 1)
                    )

                Text(recipe.name)
                    .font(.pantryBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantryTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                servingsStepperTrailing(binding: servingsBinding)
            }
            .padding(.vertical, 8)
            .padding(.leading, SingleRecipeGrocerySheetMetrics.recipeRowLeading)

            ForEach(sortedIngredientLineIndices(lines: lines), id: \.self) { index in
                ingredientRow(
                    index: index,
                    ingredient: lines[index],
                    lines: lines,
                    servings: servingsBinding.wrappedValue
                )
            }

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.35))
                .frame(height: 1)
                .padding(.leading, SingleRecipeGrocerySheetMetrics.recipeRowLeading)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }

    private func servingsStepperTrailing(binding: Binding<Int>) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text("Servings")
                .font(.pantryCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pantryTextSecondary)

            HStack(spacing: 4) {
                Button {
                    HapticFeedback.light()
                    binding.wrappedValue = max(1, binding.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.pantryTitle3)
                        .foregroundStyle(binding.wrappedValue <= 1 ? Color.pantryTextSecondary.opacity(0.35) : Color.pantryPrimary)
                }
                .buttonStyle(.plain)
                .disabled(binding.wrappedValue <= 1)

                Text("\(binding.wrappedValue)")
                    .font(.pantryBody.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantryTextPrimary)
                    .frame(minWidth: 24)

                Button {
                    HapticFeedback.light()
                    binding.wrappedValue = min(maxServings, binding.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.pantryTitle3)
                        .foregroundStyle(binding.wrappedValue >= maxServings ? Color.pantryTextSecondary.opacity(0.35) : Color.pantryPrimary)
                }
                .buttonStyle(.plain)
                .disabled(binding.wrappedValue >= maxServings)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.trailing, 4)
    }

    private func sortedIngredientLineIndices(lines: [RecipeIngredient]) -> [Int] {
        lines.indices.sorted { a, b in
            let onA = lineIsIncludedForGrocery(lineIndex: a, lines: lines)
            let onB = lineIsIncludedForGrocery(lineIndex: b, lines: lines)
            if onA != onB { return onA && !onB }
            return a < b
        }
    }

    private func lineIsIncludedForGrocery(lineIndex: Int, lines: [RecipeIngredient]) -> Bool {
        let ing = lines[lineIndex]
        let key = ingredientToggleKey(index: lineIndex)
        let inPantry = viewModel.recipeIngredientInUserPantry(ing.name)
        let isStaple = viewModel.recipeIngredientIsPantryStaple(ing.name)
        let defaultOn = !inPantry && !isStaple
        return includeIngredient[key] ?? defaultOn
    }

    private func ingredientRow(
        index: Int,
        ingredient: RecipeIngredient,
        lines: [RecipeIngredient],
        servings: Int
    ) -> some View {
        let key = ingredientToggleKey(index: index)
        let inPantry = viewModel.recipeIngredientInUserPantry(ingredient.name)
        let isStaple = viewModel.recipeIngredientIsPantryStaple(ingredient.name)
        let defaultIncluded = !inPantry && !isStaple
        let qty = RecipeQuantityScaling.scaledDisplay(
            quantity: ingredient.quantity,
            recipeServings: recipe.servings,
            currentServings: servings
        )
        let checkedBinding = Binding(
            get: { includeIngredient[key] ?? defaultIncluded },
            set: { includeIngredient[key] = $0 }
        )

        return HStack(alignment: .center, spacing: SingleRecipeGrocerySheetMetrics.checkboxToIconSpacing) {
            Button {
                HapticFeedback.light()
                checkedBinding.wrappedValue.toggle()
            } label: {
                Image(systemName: checkedBinding.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.pantryTitle3)
                    .foregroundStyle(Color.pantryPrimary)
                    .frame(width: PantryIngredientListMetrics.iconColumnWidth, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkedBinding.wrappedValue ? "Will add to grocery list" : "Will not add")

            IngredientPantryLeadingIcon(icon: getIngredientIcon(for: ingredient.name))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ingredient.name)
                        .font(.pantryBody)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pantryTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if inPantry {
                        statusCapsule(text: "In pantry", systemImage: "checkmark.circle.fill", foreground: Color.green)
                    } else if isStaple {
                        statusCapsule(text: "Staple", systemImage: "leaf.fill", foreground: Color.pantryPrimary)
                    }
                }

                if !ingredient.quantity.isEmpty {
                    HStack(spacing: 4) {
                        Text(qty.text)
                            .font(.pantrySubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.pantryTextSecondary)
                        if let factor = qty.scaleFactorToShow {
                            if factor > 0 {
                                Text("× \(factor)")
                                    .font(.pantryCaption)
                                    .foregroundStyle(Color.pantryTextSecondary)
                            } else {
                                Text("/ \(-factor)")
                                    .font(.pantryCaption)
                                    .foregroundStyle(Color.pantryTextSecondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .padding(.leading, SingleRecipeGrocerySheetMetrics.ingredientListLeading)
    }

    private func statusCapsule(text: String, systemImage: String, foreground: Color) -> some View {
        let fillOpacity = colorScheme == .dark ? 0.32 : 0.12
        return HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.pantryCaption2)
                .foregroundStyle(foreground)
            Text(text)
                .font(.pantryCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pantryTextPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(foreground.opacity(fillOpacity)))
    }

    private func ingredientToggleKey(index: Int) -> String {
        "\(rowId)#\(index)"
    }

    private func reloadFromRecipe() {
        let base = max(recipe.servings ?? 1, 1)
        servings = base
        let lines = recipe.nonEmptyRecipeIngredientLines
        var i: [String: Bool] = [:]
        for idx in lines.indices {
            let ing = lines[idx]
            let inPantry = viewModel.recipeIngredientInUserPantry(ing.name)
            let isStaple = viewModel.recipeIngredientIsPantryStaple(ing.name)
            i[ingredientToggleKey(index: idx)] = !inPantry && !isStaple
        }
        includeIngredient = i
    }

    private func buildPendingGroceryLines() -> [(name: String, quantity: String)] {
        let lines = recipe.nonEmptyRecipeIngredientLines
        let s = max(1, min(servings, maxServings))
        var pending: [(name: String, quantity: String)] = []
        for idx in lines.indices {
            let key = ingredientToggleKey(index: idx)
            let inPantry = viewModel.recipeIngredientInUserPantry(lines[idx].name)
            let isStaple = viewModel.recipeIngredientIsPantryStaple(lines[idx].name)
            let defaultOn = !inPantry && !isStaple
            guard includeIngredient[key] ?? defaultOn else { continue }
            let ing = lines[idx]
            let qty = RecipeQuantityScaling.scaledDisplay(
                quantity: ing.quantity,
                recipeServings: recipe.servings,
                currentServings: s
            )
            var quantityLine = qty.text
            if let factor = qty.scaleFactorToShow {
                if factor > 0 {
                    quantityLine = quantityLine.isEmpty ? "× \(factor)" : "\(quantityLine) × \(factor)"
                } else {
                    quantityLine = quantityLine.isEmpty ? "/ \(-factor)" : "\(quantityLine) / \(-factor)"
                }
            }
            pending.append((ing.name, quantityLine))
        }
        return pending
    }

    private func commitAdds() {
        let pending = buildPendingGroceryLines()

        guard !pending.isEmpty else {
            dismiss()
            return
        }

        if !viewModel.groceryItems.isEmpty {
            pendingItemsForDialog = pending
            showingReplaceOrAddDialog = true
            return
        }

        performAdd(pending: pending)
    }

    private func performAdd(pending: [(name: String, quantity: String)]) {
        let newRowsNeeded = PantryViewModel.additionalGroceryRowsIfAppending(
            existing: viewModel.groceryItems,
            pending: pending
        )
        let remaining = max(0, AppConfig.maxIngredients - viewModel.groceryItems.count)
        guard newRowsNeeded <= remaining else {
            if remaining == 0 {
                viewModel.errorMessage = "Your grocery list is full. Remove items on the Grocery List tab to add more."
            } else {
                viewModel.errorMessage = "Your grocery list can only fit \(remaining) more line\(remaining == 1 ? "" : "s") (merges use an existing line). Uncheck some items or clear space."
            }
            return
        }

        for item in pending {
            viewModel.addGroceryItem(name: item.name, quantity: item.quantity)
        }
        HapticFeedback.success()
        viewModel.shouldNavigateToGroceryList = true
        dismiss()
    }

    private func performReplace(pending: [(name: String, quantity: String)]) {
        viewModel.replaceGroceryItems(with: pending)
        HapticFeedback.success()
        viewModel.shouldNavigateToGroceryList = true
        dismiss()
    }
}

private enum SingleRecipeGrocerySheetMetrics {
    static let recipeRowLeading: CGFloat = 0
    static let ingredientListLeading: CGFloat = DesignTokens.spacingXS
    static let checkboxToIconSpacing: CGFloat = 6
}

#Preview {
    SingleRecipeAddToGrocerySheet(
        recipe: Recipe(
            name: "Test",
            description: "",
            ingredients: [
                RecipeIngredient(name: "Flour", quantity: "2 cups"),
                RecipeIngredient(name: "Eggs", quantity: "2")
            ],
            steps: [],
            servings: 4
        ),
        viewModel: PantryViewModel()
    )
}
