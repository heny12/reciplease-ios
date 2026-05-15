//
//  GenerateMealPlanPlaceholderSheet.swift
//  PantryPal
//
//  Meal-plan generation: meal slot picks plus cuisine / dietary / custom prompt (same chrome as generate recipes).
//

import SwiftUI

struct GenerateMealPlanPlaceholderSheet: View {
    @ObservedObject var viewModel: PantryViewModel
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @Environment(\.dismiss) private var dismiss

    private struct DaySelection: Identifiable {
        let id: String
        let date: Date
        var breakfast: Bool = false
        var lunch: Bool = false
        var dinner: Bool = false
        var dessert: Bool = false
    }

    @State private var days: [DaySelection] = []
    @State private var selectedCuisines: Set<String> = ["Any"]
    @State private var selectedDietary: Set<String> = []
    @State private var additionalPreferences = ""
    @State private var promptErrorMessage: String?
    /// Matches `MealPlanRequest.strictness` (`POST /api/recipe/meal-plan`).
    @State private var pantryIngredientStrictness: MealPlanStrictness = .any

    @State private var currentPage = 0
    private let totalPages = 5

    private let calendar = Calendar.current

    private var maxSelectableMealSlots: Int {
        revenueCatService.isProMember ? AppConfig.maxMealPlanGenerateSlotsPro : AppConfig.maxMealPlanGenerateSlotsFree
    }

    private var selectedEmptySlotCheckboxCount: Int {
        days.reduce(0) { partial, day in
            partial + (day.breakfast ? 1 : 0) + (day.lunch ? 1 : 0) + (day.dinner ? 1 : 0) + (day.dessert ? 1 : 0)
        }
    }

    private var additionalPreferencesBinding: Binding<String> {
        Binding(
            get: { additionalPreferences },
            set: { newValue in
                additionalPreferences = newValue
                promptErrorMessage = nil
            }
        )
    }

    private var assembledMealPlanPrompt: String {
        var promptParts: [String] = []
        let cuisinesFiltered = selectedCuisines.filter { $0 != "Any" }
        if !cuisinesFiltered.isEmpty {
            promptParts.append("Cuisine: \(cuisinesFiltered.joined(separator: ", "))")
        }
        if !selectedDietary.isEmpty {
            promptParts.append("Dietary requirements: \(selectedDietary.joined(separator: ", "))")
        }
        let trimmed = additionalPreferences.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            promptParts.append(trimmed)
        }
        return promptParts.joined(separator: ". ")
    }

    private var generatedPrompt: String {
        let full = assembledMealPlanPrompt
        if full.count > AppConfig.maxGeneratePromptLength {
            return String(full.prefix(AppConfig.maxGeneratePromptLength))
        }
        return full
    }

    private var isPromptValid: Bool {
        assembledMealPlanPrompt.count <= AppConfig.maxGeneratePromptLength
    }

    private var selectedPreferenceChipCount: Int {
        selectedCuisines.filter { $0 != "Any" }.count + selectedDietary.count
    }

    private func applyCannedSpecialRequest(_ request: String) {
        HapticFeedback.light()
        additionalPreferences = request
        promptErrorMessage = nil
    }

    /// Matches sheet row order: each day, then breakfast → lunch → dinner → dessert (snack is Plan-only).
    private func mealPlanGenerationPayload() -> MealPlanGenerationSheetPayload? {
        guard selectedEmptySlotCheckboxCount > 0 else { return nil }
        var b = 0, l = 0, d = 0, de = 0
        var slots: [MealPlanSlotSelection] = []
        slots.reserveCapacity(selectedEmptySlotCheckboxCount)
        for day in days {
            if day.breakfast {
                b += 1
                slots.append(MealPlanSlotSelection(dayKey: day.id, slot: .breakfast))
            }
            if day.lunch {
                l += 1
                slots.append(MealPlanSlotSelection(dayKey: day.id, slot: .lunch))
            }
            if day.dinner {
                d += 1
                slots.append(MealPlanSlotSelection(dayKey: day.id, slot: .dinner))
            }
            if day.dessert {
                de += 1
                slots.append(MealPlanSlotSelection(dayKey: day.id, slot: .dessert))
            }
        }
        let counts = MealTypeCounts(breakfast: b, lunch: l, dinner: d, snack: 0, dessert: de)
        let promptText = assembledMealPlanPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return MealPlanGenerationSheetPayload(
            mealTypeCounts: counts,
            orderedSelectedSlots: slots,
            prompt: promptText.isEmpty ? nil : promptText,
            strictness: pantryIngredientStrictness
        )
    }

    @ViewBuilder
    private func pantryStrictnessChip(
        _ value: MealPlanStrictness,
        title: String,
        icon: String,
        accessibilityLabel: String
    ) -> some View {
        let option = OptionItem(id: value.rawValue, name: title, icon: icon)
        OptionChip(
            option: option,
            isSelected: pantryIngredientStrictness == value,
            style: .generateSheet,
            size: .large,
            isFullWidth: true
        ) {
            HapticFeedback.light()
            pantryIngredientStrictness = value
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(pantryIngredientStrictness == value ? [.isSelected] : [])
    }

    private var footerButtonTitle: String {
        switch currentPage {
        case totalPages - 1: return "Generate meal plan"
        default: return "Next"
        }
    }

    private var footerButtonDisabled: Bool {
        if currentPage == totalPages - 1 {
            return !isPromptValid || viewModel.isGeneratingRecipes || selectedEmptySlotCheckboxCount == 0 || viewModel.ingredients.isEmpty
        }
        return false
    }

    private func footerButtonAction() {
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage += 1
            }
        } else {
            if !isPromptValid {
                promptErrorMessage = ValidationError.generatePromptTooLong(maxLength: AppConfig.maxGeneratePromptLength).localizedDescription
                return
            }
            guard let payload = mealPlanGenerationPayload() else {
                viewModel.errorMessage = "Select at least one meal slot to generate."
                return
            }
            guard !viewModel.ingredients.isEmpty else {
                viewModel.errorMessage = "Add ingredients to your pantry before generating a meal plan."
                return
            }
            Task {
                await viewModel.generateMealPlanFromSheet(payload)
            }
            dismiss()
        }
    }

    private var headerTitle: String {
        switch currentPage {
        case 0: return "Which meals should we plan for you?"
        case 1: return "What ingredients should we use?"
        case 2: return "Any specific cuisine in mind?"
        case 3: return "Any dietary preferences?"
        case 4: return "Any final special requests?"
        default: return "Generate Meal Plan"
        }
    }

    var body: some View {
        PantryGenerateWizardShell(
            currentPage: currentPage,
            totalPages: totalPages,
            title: headerTitle,
            onBack: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPage -= 1
                }
            },
            onCancel: {
                dismiss()
            },
            footerButtonTitle: footerButtonTitle,
            footerButtonAction: footerButtonAction,
            isFooterButtonDisabled: footerButtonDisabled,
            isFooterButtonLoading: viewModel.isGeneratingRecipes
        ) {
            Group {
                switch currentPage {
                case 0:
                    mealsToPlanPage
                case 1:
                    pantryStrictnessPage
                case 2:
                    cuisinesPage
                case 3:
                    dietaryPage
                case 4:
                    specialRequestsPage
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
        }
        .onAppear {
            if days.isEmpty {
                days = Self.initialDays(calendar: calendar)
            }
        }
    }

    // MARK: - Pages

    private var mealsToPlanPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mealSlotLimitFootnote)
                .font(.pantryBody)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DesignTokens.spacingMD)

            PantryGenerateSheetFormSection(
                title: nil,
                subtitle: "Choose which meals you would like a meal plan to be generated for · already planned meals show as thumbnails",
                showsTrailingDivider: false
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, _ in
                            dayRow(index: index)
                            if index < days.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.22))
                                    .frame(height: 1)
                                    .padding(.vertical, DesignTokens.spacingSM)
                            }
                        }
                    }
                    .frame(width: MealPlanGenerateGridMetrics.gridContentWidth, alignment: .leading)
                }
            }
        }
    }

    private var pantryStrictnessPage: some View {
        PantryGenerateSheetFormSection(
            title: nil,
            subtitle: RecipeGenerationFormOptionData.generateSheetPantryIngredientsSubtitle,
            showsTrailingDivider: false
        ) {
            VStack(spacing: 8) {
                pantryStrictnessChip(
                    .any,
                    title: "Any ingredients",
                    icon: "globe",
                    accessibilityLabel: "Any ingredients, recipes may include items not in your pantry"
                )
                pantryStrictnessChip(
                    .mostly,
                    title: "Mostly pantry",
                    icon: "leaf.fill",
                    accessibilityLabel: "Mostly use ingredients from your pantry"
                )
                pantryStrictnessChip(
                    .only,
                    title: "Pantry only",
                    icon: "checkmark.seal.fill",
                    accessibilityLabel: "Only use ingredients from your pantry"
                )
            }
            
            if viewModel.ingredients.isEmpty {
                Text("Your pantry is currently empty. Add ingredients to test the 'Mostly' or 'Only' options.")
                    .font(.pantryCaption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .padding(.top, DesignTokens.spacingSM)
            }
        }
    }

    private var cuisinesPage: some View {
        PantryGenerateSheetFormSection(title: nil, subtitle: "Pick one or more cuisines", showsTrailingDivider: false) {
            VStack(spacing: 8) {
                ForEach(RecipeGenerationFormOptionData.cuisinesOrderedForForms()) { option in
                    OptionChip(
                        option: option,
                        isSelected: selectedCuisines.contains(option.id),
                        style: .generateSheet,
                        size: .large,
                        isFullWidth: true
                    ) {
                        HapticFeedback.light()
                        if option.id == "Any" {
                            if selectedCuisines.contains("Any") {
                                selectedCuisines.removeAll()
                            } else {
                                selectedCuisines = ["Any"]
                            }
                        } else {
                            selectedCuisines.remove("Any")
                            if selectedCuisines.contains(option.id) {
                                selectedCuisines.remove(option.id)
                            } else {
                                selectedCuisines.insert(option.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dietaryPage: some View {
        PantryGenerateSheetFormSection(title: nil, subtitle: "Optional filters", showsTrailingDivider: false) {
            VStack(spacing: 8) {
                ForEach(RecipeGenerationFormOptionData.dietaryOptionsOrderedForForms()) { option in
                    OptionChip(
                        option: option,
                        isSelected: selectedDietary.contains(option.id),
                        style: .generateSheet,
                        size: .large,
                        isFullWidth: true
                    ) {
                        HapticFeedback.light()
                        if selectedDietary.contains(option.id) {
                            selectedDietary.remove(option.id)
                        } else {
                            selectedDietary.insert(option.id)
                        }
                    }
                }
            }
        }
    }

    private var specialRequestsPage: some View {
        PantryGenerateSheetFormSection(
            title: nil,
            subtitle: "Optional — add constraints or style preferences",
            showsTrailingDivider: false
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.pantryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )

                    TextEditor(text: additionalPreferencesBinding)
                        .frame(minHeight: 96)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundStyle(Color.pantryTextPrimary)
                }
                .frame(minHeight: 96)

                HStack {
                    Spacer()
                    Text("\(generatedPrompt.count)/\(AppConfig.maxGeneratePromptLength)")
                        .font(.pantryCaption)
                        .foregroundStyle(isPromptValid ? Color.white.opacity(0.65) : Color(red: 1, green: 0.88, blue: 0.86))
                }

                Text("Try a premade prompt:")
                    .font(.pantryCaption)
                    .foregroundStyle(Color.white.opacity(0.62))

                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    ForEach(RecipeGenerationFormOptionData.cannedSpecialRequests, id: \.self) { request in
                        Button {
                            applyCannedSpecialRequest(request)
                        } label: {
                            HStack {
                                Text(request)
                                    .font(.pantryBody)
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage = promptErrorMessage {
                    Text(errorMessage)
                        .font(.pantryCaption)
                        .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
                }
                
                Text("\(selectedEmptySlotCheckboxCount) meal\(selectedEmptySlotCheckboxCount == 1 ? "" : "s") selected · \(selectedPreferenceChipCount) preference\(selectedPreferenceChipCount == 1 ? "" : "s")")
                    .font(.pantryCaption)
                    .foregroundStyle(Color.pantryOnWhiteCardSecondaryText)
                    .padding(.top, DesignTokens.spacingSM)
            }
        }
    }

    private var mealSlotLimitFootnote: String {
        if revenueCatService.isProMember {
            return "Select up to \(AppConfig.maxMealPlanGenerateSlotsPro) meals to generate."
        }
        return "Select up to \(AppConfig.maxMealPlanGenerateSlotsFree) meals. Reciplease Pro allows up to \(AppConfig.maxMealPlanGenerateSlotsPro)."
    }

    /// Fixed column widths so meal checkboxes and thumbnails line up vertically day over day; `gridContentWidth` is used by one outer horizontal scroll.
    private enum MealPlanGenerateGridMetrics {
        /// Tight enough for weekday + date line without pushing the meal grid off-screen.
        static let dateColumnWidth: CGFloat = 80
        static let slotColumnWidth: CGFloat = 56
        static let slotIconAreaHeight: CGFloat = 40
        /// Space between date labels and first meal column (keep small so four slots fit on typical phones).
        static let dateToMealsSpacing: CGFloat = DesignTokens.spacingXS
        static var gridContentWidth: CGFloat {
            dateColumnWidth
                + dateToMealsSpacing
                + 4 * slotColumnWidth
                + 3 * DesignTokens.spacingXS
        }
    }

    @ViewBuilder
    private func dayRow(index: Int) -> some View {
        let day = days[index]
        HStack(alignment: .center, spacing: MealPlanGenerateGridMetrics.dateToMealsSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryDayLabel(for: day.date))
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(Self.detailFormatter.string(from: day.date))
                    .font(.pantryCaption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(width: MealPlanGenerateGridMetrics.dateColumnWidth, alignment: .leading)

            HStack(spacing: DesignTokens.spacingXS) {
                slotCell(dayKey: day.id, slot: .breakfast, title: "Breakfast", index: index, keyPath: \.breakfast)
                    .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth)
                slotCell(dayKey: day.id, slot: .lunch, title: "Lunch", index: index, keyPath: \.lunch)
                    .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth)
                slotCell(dayKey: day.id, slot: .dinner, title: "Dinner", index: index, keyPath: \.dinner)
                    .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth)
                slotCell(dayKey: day.id, slot: .dessert, title: "Dessert", index: index, keyPath: \.dessert)
                    .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth)
            }
        }
    }

    @ViewBuilder
    private func slotCell(
        dayKey: String,
        slot: MealPlanSlot,
        title: String,
        index: Int,
        keyPath: WritableKeyPath<DaySelection, Bool>
    ) -> some View {
        if let recipe = viewModel.plannedRecipe(dayKey: dayKey, slot: slot) {
            VStack(spacing: 4) {
                HStack {
                    Spacer(minLength: 0)
                    PlanSmallRecipeThumbnail(recipe: recipe, size: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                    Spacer(minLength: 0)
                }
                .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth, height: MealPlanGenerateGridMetrics.slotIconAreaHeight)

                Text(title)
                    .font(.pantryCaption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth, alignment: .top)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(recipe.name), already planned")
        } else {
            let isOnBinding = binding(for: index, keyPath: keyPath)
            let atLimit = selectedEmptySlotCheckboxCount >= maxSelectableMealSlots
            let isBlocked = !isOnBinding.wrappedValue && atLimit
            slotCheckbox(title: title, isOn: isOnBinding, isBlockedFromTurningOn: isBlocked)
        }
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<DaySelection, Bool>) -> Binding<Bool> {
        Binding(
            get: { days[index][keyPath: keyPath] },
            set: { newValue in
                var row = days[index]
                let wasOn = row[keyPath: keyPath]
                if newValue && !wasOn, selectedEmptySlotCheckboxCount >= maxSelectableMealSlots {
                    HapticFeedback.error()
                    return
                }
                row[keyPath: keyPath] = newValue
                days[index] = row
            }
        )
    }

    private func primaryDayLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return Self.weekdayFormatter.string(from: date)
    }

    private func slotCheckbox(title: String, isOn: Binding<Bool>, isBlockedFromTurningOn: Bool) -> some View {
        VStack(spacing: 4) {
            Button {
                if isBlockedFromTurningOn {
                    HapticFeedback.error()
                    return
                }
                HapticFeedback.light()
                isOn.wrappedValue.toggle()
            } label: {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.pantryTitle3)
                    .foregroundStyle(
                        isOn.wrappedValue
                            ? Color.white
                            : Color.white.opacity(isBlockedFromTurningOn ? 0.28 : 0.55)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth, height: MealPlanGenerateGridMetrics.slotIconAreaHeight)
            .accessibilityLabel(title)
            .accessibilityHint(isBlockedFromTurningOn ? "Selection limit reached" : "")

            Text(title)
                .font(.pantryCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white.opacity(isBlockedFromTurningOn ? 0.45 : 0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: MealPlanGenerateGridMetrics.slotColumnWidth, alignment: .top)
        }
    }

    private static func initialDays(calendar: Calendar) -> [DaySelection] {
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset -> DaySelection? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            guard let y = c.year, let m = c.month, let d = c.day else { return nil }
            let key = String(format: "%04d-%02d-%02d", y, m, d)
            return DaySelection(id: key, date: date)
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    private static let detailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()
}

#Preview {
    GenerateMealPlanPlaceholderSheet(viewModel: PantryViewModel())
}
