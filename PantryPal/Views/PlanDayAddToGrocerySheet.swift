//
//  PlanDayAddToGrocerySheet.swift
//  PantryPal
//
//  Pick scaled ingredient lines from one or more plan days to append to the grocery list.
//

import SwiftUI

private struct PlanPlannedMealRow: Identifiable {
    let dayKey: String
    let slot: MealPlanSlot
    let recipe: Recipe
    var id: String { "\(dayKey)|\(slot.rawValue)|\(recipe.id.uuidString)" }
}

private struct GrocerySheetDayBlock: Identifiable {
    let dayKey: String
    let rows: [PlanPlannedMealRow]
    var id: String { dayKey }
}

struct PlanDayAddToGrocerySheet: View {
    /// Calendar day keys (`yyyy-MM-dd`) to include, in any order; shown sorted by date.
    let dayKeys: [String]
    @ObservedObject var viewModel: PantryViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var dayBlocks: [GrocerySheetDayBlock] = []
    @State private var servingsByRowId: [String: Int] = [:]
    @State private var includeIngredient: [String: Bool] = [:]
    @State private var didLoad = false
    @State private var showingReplaceOrAddDialog = false
    @State private var pendingItemsForDialog: [(name: String, quantity: String)] = []

    private let calendar = Calendar.current
    private let maxServings = 99

    init(dayKeys: [String], viewModel: PantryViewModel) {
        self.dayKeys = dayKeys
        self.viewModel = viewModel
    }

    /// Single-day convenience (Plan row + menu).
    init(dayKey: String, viewModel: PantryViewModel) {
        self.dayKeys = [dayKey]
        self.viewModel = viewModel
    }

    private var isMultiDay: Bool {
        dayKeys.count > 1
    }

    private var sheetMinHeight: CGFloat {
        isMultiDay ? 580 : 520
    }

    var body: some View {
        PantryGenerateRecipeSheetShell(minDetentHeight: sheetMinHeight, sheetBackground: Color.pantryBackground) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        HapticFeedback.light()
                        dismissSheet()
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

                if dayBlocks.isEmpty {
                    emptyState
                } else {
                    ForEach(dayBlocks) { block in
                        dayHeaderBlock(dayKey: block.dayKey)
                            .padding(.bottom, isMultiDay ? 10 : 12)

                        ForEach(block.rows) { row in
                            recipeBlock(row)
                        }

                        if block.id != dayBlocks.last?.id {
                            Rectangle()
                                .fill(Color.pantryBorder.opacity(0.25))
                                .frame(height: 1)
                                .padding(.vertical, DesignTokens.spacingSM)
                        }
                    }

                    lightSheetSectionDivider

                    addButton
                        .padding(.bottom, DesignTokens.spacingSM)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if !didLoad {
                reloadFromPlan()
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

    // MARK: - Upcoming days (Actions menu)

    /// Sorted `yyyy-MM-dd` keys for today and future days that have at least one planned meal.
    static func upcomingDayKeysWithPlannedMeals(viewModel: PantryViewModel, calendar: Calendar = .current) -> [String] {
        let today = calendar.startOfDay(for: Date())
        return viewModel.mealPlanByDay.keys.compactMap { key -> (String, Date)? in
            guard let date = Self.parseMealPlanDayKey(key, calendar: calendar), date >= today else { return nil }
            let hasMeal = MealPlanSlot.allCases.contains { viewModel.plannedRecipe(dayKey: key, slot: $0) != nil }
            guard hasMeal else { return nil }
            return (key, date)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    static func parseMealPlanDayKey(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return calendar.date(from: c).map { calendar.startOfDay(for: $0) }
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
            Image(systemName: "calendar")
                .font(.pantryLargeTitle)
                .foregroundStyle(Color.pantryTextSecondary.opacity(0.45))
            Text("Nothing to add")
                .font(.pantryHeadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pantryTextPrimary)
            Text("No planned recipes for the selected day\(isMultiDay ? "s" : "").")
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

    private func dismissSheet() {
        dismiss()
    }

    private func dayDate(for dayKey: String) -> Date? {
        Self.parseMealPlanDayKey(dayKey, calendar: calendar)
    }

    private func dayHeaderBlock(dayKey: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
                if let dayDate = dayDate(for: dayKey) {
                    Text(String(calendar.component(.day, from: dayDate)))
                        .font(.pantryLargeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pantryPrimary)
                        .monospacedDigit()
                        .frame(width: PlanDayGrocerySheetMetrics.dayNumberColumnWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayUppercased(dayDate))
                            .font(.pantryCaption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.pantryPrimary)
                        Text(monthUppercased(dayDate))
                            .font(.pantryCaption)
                            .fontWeight(.regular)
                            .foregroundStyle(Color.pantryTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(dayKey)
                        .font(.pantryTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pantryTextPrimary)
                }
            }
            .padding(.vertical, DesignTokens.spacingXS)

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.45))
                .frame(height: 1)
        }
    }

    private func recipeBlock(_ row: PlanPlannedMealRow) -> some View {
        let rowId = row.id
        let lines = row.recipe.nonEmptyRecipeIngredientLines
        let servingsBinding = Binding(
            get: { max(1, servingsByRowId[rowId] ?? max(row.recipe.servings ?? 1, 1)) },
            set: { servingsByRowId[rowId] = min(max(1, $0), maxServings) }
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                PlanSmallRecipeThumbnail(recipe: row.recipe, size: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.pantryBorder.opacity(0.35), lineWidth: 1)
                    )

                Text(row.recipe.name)
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
            .padding(.leading, PlanDayGrocerySheetMetrics.recipeRowLeading)

            ForEach(sortedIngredientLineIndices(row: row, lines: lines), id: \.self) { index in
                ingredientRow(
                    row: row,
                    index: index,
                    ingredient: lines[index],
                    servings: servingsBinding.wrappedValue
                )
            }

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.35))
                .frame(height: 1)
                .padding(.leading, PlanDayGrocerySheetMetrics.recipeRowLeading)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }

    /// Label centered over the stepper row so it lines up with the number control cluster.
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

    /// Checked (will add) lines first; within each group, original recipe order.
    private func sortedIngredientLineIndices(row: PlanPlannedMealRow, lines: [RecipeIngredient]) -> [Int] {
        lines.indices.sorted { a, b in
            let onA = lineIsIncludedForGrocery(row: row, lineIndex: a, lines: lines)
            let onB = lineIsIncludedForGrocery(row: row, lineIndex: b, lines: lines)
            if onA != onB { return onA && !onB }
            return a < b
        }
    }

    private func lineIsIncludedForGrocery(row: PlanPlannedMealRow, lineIndex: Int, lines: [RecipeIngredient]) -> Bool {
        let ing = lines[lineIndex]
        let key = ingredientToggleKey(rowId: row.id, index: lineIndex)
        let inPantry = viewModel.recipeIngredientInUserPantry(ing.name)
        let isStaple = viewModel.recipeIngredientIsPantryStaple(ing.name)
        let defaultOn = !inPantry && !isStaple
        return includeIngredient[key] ?? defaultOn
    }

    private func ingredientRow(
        row: PlanPlannedMealRow,
        index: Int,
        ingredient: RecipeIngredient,
        servings: Int
    ) -> some View {
        let key = ingredientToggleKey(rowId: row.id, index: index)
        let inPantry = viewModel.recipeIngredientInUserPantry(ingredient.name)
        let isStaple = viewModel.recipeIngredientIsPantryStaple(ingredient.name)
        let defaultIncluded = !inPantry && !isStaple
        let qty = RecipeQuantityScaling.scaledDisplay(
            quantity: ingredient.quantity,
            recipeServings: row.recipe.servings,
            currentServings: servings
        )
        let checkedBinding = Binding(
            get: { includeIngredient[key] ?? defaultIncluded },
            set: { includeIngredient[key] = $0 }
        )

        return HStack(alignment: .center, spacing: PlanDayGrocerySheetMetrics.checkboxToIconSpacing) {
            Button {
                HapticFeedback.light()
                checkedBinding.wrappedValue.toggle()
            } label: {
                Image(systemName: checkedBinding.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.pantryTitle3)
                    .foregroundStyle(
                        checkedBinding.wrappedValue
                            ? Color.pantryPrimary
                            : Color.pantryPrimary
                    )
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
        .padding(.leading, PlanDayGrocerySheetMetrics.ingredientListLeading)
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

    private func ingredientToggleKey(rowId: String, index: Int) -> String {
        "\(rowId)#\(index)"
    }

    private func reloadFromPlan() {
        var blocks: [GrocerySheetDayBlock] = []
        let orderedKeys = dayKeys.sorted {
            let d0 = Self.parseMealPlanDayKey($0, calendar: calendar) ?? .distantPast
            let d1 = Self.parseMealPlanDayKey($1, calendar: calendar) ?? .distantPast
            return d0 < d1
        }
        for dayKey in orderedKeys {
            let slotRows: [PlanPlannedMealRow] = MealPlanSlot.allCases.compactMap { slot in
                guard let recipe = viewModel.plannedRecipe(dayKey: dayKey, slot: slot) else { return nil }
                return PlanPlannedMealRow(dayKey: dayKey, slot: slot, recipe: recipe)
            }
            guard !slotRows.isEmpty else { continue }
            blocks.append(GrocerySheetDayBlock(dayKey: dayKey, rows: slotRows))
        }
        dayBlocks = blocks

        var s: [String: Int] = [:]
        var i: [String: Bool] = [:]
        for block in blocks {
            for row in block.rows {
                let base = max(row.recipe.servings ?? 1, 1)
                s[row.id] = base
                let lines = row.recipe.nonEmptyRecipeIngredientLines
                for idx in lines.indices {
                    let ing = lines[idx]
                    let inPantry = viewModel.recipeIngredientInUserPantry(ing.name)
                    let isStaple = viewModel.recipeIngredientIsPantryStaple(ing.name)
                    i[ingredientToggleKey(rowId: row.id, index: idx)] = !inPantry && !isStaple
                }
            }
        }
        servingsByRowId = s
        includeIngredient = i
    }

    /// Ingredient lines that will be appended (same rules as `commitAdds`).
    private func buildPendingGroceryLines() -> [(name: String, quantity: String)] {
        var pending: [(name: String, quantity: String)] = []
        for block in dayBlocks {
            for row in block.rows {
                let rowId = row.id
                let servings = max(1, servingsByRowId[rowId] ?? max(row.recipe.servings ?? 1, 1))
                let lines = row.recipe.nonEmptyRecipeIngredientLines
                for idx in lines.indices {
                    let key = ingredientToggleKey(rowId: rowId, index: idx)
                    let inPantry = viewModel.recipeIngredientInUserPantry(lines[idx].name)
                    let isStaple = viewModel.recipeIngredientIsPantryStaple(lines[idx].name)
                    let defaultOn = !inPantry && !isStaple
                    guard includeIngredient[key] ?? defaultOn else { continue }
                    let ing = lines[idx]
                    let qty = RecipeQuantityScaling.scaledDisplay(
                        quantity: ing.quantity,
                        recipeServings: row.recipe.servings,
                        currentServings: servings
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
            }
        }
        return pending
    }

    private func commitAdds() {
        let pending = buildPendingGroceryLines()

        guard !pending.isEmpty else {
            dismissSheet()
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
        dismissSheet()
    }

    private func performReplace(pending: [(name: String, quantity: String)]) {
        viewModel.replaceGroceryItems(with: pending)
        HapticFeedback.success()
        viewModel.shouldNavigateToGroceryList = true
        dismissSheet()
    }

    private func weekdayUppercased(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date).uppercased()
    }

    private func monthUppercased(_ date: Date) -> String {
        Self.monthFormatter.string(from: date).uppercased()
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f
    }()
}

private enum PlanDayGrocerySheetMetrics {
    /// Minimal inset so recipe rows sit closer to the sheet edge (thumbnail aligns with day header flow).
    static let recipeRowLeading: CGFloat = 0
    /// Slight indent for ingredient lines under the recipe row.
    static let ingredientListLeading: CGFloat = DesignTokens.spacingXS
    static let dayNumberColumnWidth: CGFloat = 56
    static let checkboxToIconSpacing: CGFloat = 6
}

#Preview("Single day") {
    PlanDayAddToGrocerySheet(dayKey: "2026-03-30", viewModel: PantryViewModel())
}
