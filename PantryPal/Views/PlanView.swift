//
//  PlanView.swift
//  PantryPal
//
//  Meal-planning timeline UI (yesterday through next 30 days). Persisted meal slots per day.
//

import SwiftUI
import UIKit

private struct MealPickerTarget: Identifiable {
    let dayKey: String
    let slot: MealPlanSlot

    var id: String { "\(dayKey)-\(slot.rawValue)" }
}

private struct AddPlanDayGrocerySheetTarget: Identifiable {
    let dayKeys: [String]
    var id: String {
        if dayKeys.count == 1, let only = dayKeys.first { return only }
        return dayKeys.sorted().joined(separator: ",")
    }
}

/// Pushes recipe detail without a list disclosure chevron (same pattern as pantry matches).
private struct PlanRecipeNavigationItem: Hashable {
    let recipeId: UUID
}

private enum PlanListMetrics {
    static let horizontalInset = LayoutHelpers.horizontalPadding
    /// Extra leading inset for recipe rows so they sit in from the day header.
    static let recipeLeadingInset = horizontalInset + DesignTokens.spacingMD
    /// Fixed width so single- and double-digit days align on the same leading edge.
    static let dayNumberColumnWidth: CGFloat = 56
    static let planRowThumbnailSize: CGFloat = 52
    /// Weekday/month labels start here (from header row content leading); matches meal type + title after thumbnail.
    static var dayHeaderTextColumnOffset: CGFloat {
        (recipeLeadingInset - horizontalInset) + planRowThumbnailSize + DesignTokens.spacingSM
    }
}

struct PlanView: View {
    @ObservedObject var viewModel: PantryViewModel
    /// Opens the green “Generate Meal Plan” sheet (presented from `ContentView`).
    var onGenerateMealPlan: () -> Void

    init(viewModel: PantryViewModel, onGenerateMealPlan: @escaping () -> Void = {}) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onGenerateMealPlan = onGenerateMealPlan
    }

    private let calendar = Calendar.current

    @State private var mealPickerTarget: MealPickerTarget?
    @State private var planRecipeDetailItem: PlanRecipeNavigationItem?
    @State private var addPlanDayGrocerySheetTarget: AddPlanDayGrocerySheetTarget?
    @State private var singleRecipeForGrocery: Recipe?
    @State private var showMealPlanCalendarPermissionOffer = false

    /// Local calendar days from yesterday through (today + 30), inclusive → 32 days.
    private var planDays: [Date] {
        let startOfToday = calendar.startOfDay(for: Date())
        return (-1...30).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)
        }
    }

    var body: some View {
        ZStack {
            List {
                planActionsPillsHeader
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 6, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                ForEach(planDays, id: \.self) { day in
                    planDayBlock(for: day)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(DesignTokens.spacingXS)
            .background(Color.pantryBackground)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $planRecipeDetailItem) { item in
                RecipeDetailView(
                    viewModel: viewModel,
                    recipeId: item.recipeId,
                    isFromFavorites: viewModel.isFavorite(recipeId: item.recipeId),
                    sourceCookbookId: viewModel.cookbookContainingRecipe(recipeId: item.recipeId)?.id
                )
            }

            if let target = mealPickerTarget {
                PlanMealPickerBubble(
                    viewModel: viewModel,
                    dayKey: target.dayKey,
                    slot: target.slot,
                    onDismiss: { mealPickerTarget = nil }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.22), value: mealPickerTarget != nil)
        .mainTabRootNavigationChrome(
            title: MainTabNavigationCopy.planNavigationTitle(plannedMealSlotCount: viewModel.plannedMealSlotsFromTodayCount)
        )
        .sheet(item: $addPlanDayGrocerySheetTarget, onDismiss: {
            addPlanDayGrocerySheetTarget = nil
        }) { target in
            PlanDayAddToGrocerySheet(dayKeys: target.dayKeys, viewModel: viewModel)
        }
        .sheet(item: $singleRecipeForGrocery, onDismiss: {
            singleRecipeForGrocery = nil
        }) { recipe in
            SingleRecipeAddToGrocerySheet(recipe: recipe, viewModel: viewModel)
        }
        .onAppear {
            guard MealPlanCalendarPromptCoordinator.shouldOfferCalendarPermissionOnPlanAppear else { return }
            MealPlanCalendarPromptCoordinator.shouldOfferCalendarPermissionOnPlanAppear = false
            showMealPlanCalendarPermissionOffer = true
        }
        .alert("Calendar Access", isPresented: $showMealPlanCalendarPermissionOffer) {
            Button("Not Now", role: .cancel) {}
            Button(MealPlanCalendarService.shared.needsSettingsToEnableFullCalendarAccess ? "Open Settings" : "Enable Calendar") {
                if MealPlanCalendarService.shared.needsSettingsToEnableFullCalendarAccess {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task {
                        do {
                            let granted = try await MealPlanCalendarService.shared.requestFullCalendarAccess()
                            if granted {
                                viewModel.syncMealPlanToSystemCalendarIfNeeded()
                            }
                        } catch {
                            print("❌ [Calendar] requestFullCalendarAccess: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } message: {
            Text("Reciplease needs full Calendar access to sync your planned meals to your calendar. You can keep using Plan without this.")
        }
    }

    private var planActionsPillsHeader: some View {
        FlowLayout(spacing: 8) {
            PantryPillButton(title: "Add to Plan", tint: .pantryPrimary, isExpanded: false) {
                HapticFeedback.light()
                onGenerateMealPlan()
            }

            let upcomingDayKeys = PlanDayAddToGrocerySheet.upcomingDayKeysWithPlannedMeals(viewModel: viewModel)
            PantryPillButton(title: "Add to Grocery List", tint: .pantrySecondary, isExpanded: false) {
                HapticFeedback.light()
                if upcomingDayKeys.isEmpty {
                    viewModel.errorMessage = "You have no upcoming meals planned to add to your grocery list."
                } else {
                    addPlanDayGrocerySheetTarget = AddPlanDayGrocerySheetTarget(dayKeys: upcomingDayKeys)
                }
            }
            .opacity(upcomingDayKeys.isEmpty ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayId(_ day: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// Stable key for persisted meal plan (local calendar, start-of-day).
    private func mealPlanDayKey(for day: Date) -> String {
        let start = calendar.startOfDay(for: day)
        let c = calendar.dateComponents([.year, .month, .day], from: start)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func plannedRows(dayKey: String) -> [(MealPlanSlot, Recipe)] {
        MealPlanSlot.allCases.compactMap { slot in
            guard let recipe = viewModel.plannedRecipe(dayKey: dayKey, slot: slot) else { return nil }
            return (slot, recipe)
        }
    }

    /// Day header + meals as normal rows (not `Section` headers) so headers scroll instead of pinning.
    @ViewBuilder
    private func planDayBlock(for day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let headerTint: Color = isToday ? .pantrySecondary : .pantryTextPrimary
        let subTint: Color = isToday ? .pantrySecondary.opacity(0.92) : .pantryTextSecondary
        let dayKey = mealPlanDayKey(for: day)
        let rows = plannedRows(dayKey: dayKey)
        let isFirstDayInTimeline = planDays.first.map { calendar.isDate(day, inSameDayAs: $0) } ?? true

        Group {
            planDaySectionHeader(day: day, dayKey: dayKey, isToday: isToday, headerTint: headerTint, subTint: subTint)
                .padding(.top, isFirstDayInTimeline ? 0 : DesignTokens.spacingSM)
                .listRowInsets(
                    EdgeInsets(
                        top: DesignTokens.spacingSM,
                        leading: PlanListMetrics.horizontalInset,
                        bottom: DesignTokens.spacingXS,
                        trailing: PlanListMetrics.horizontalInset
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.pantryBackground)
                .id(dayId(day))

            ForEach(rows, id: \.0.id) { row in
                let slot = row.0
                let recipe = row.1
                Button {
                    planRecipeDetailItem = PlanRecipeNavigationItem(recipeId: recipe.id)
                } label: {
                    HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                        PlanSmallRecipeThumbnail(recipe: recipe, size: PlanListMetrics.planRowThumbnailSize)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.label.uppercased())
                                .font(.pantryCaption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.pantryTextSecondary)
                            Text(recipe.name)
                                .font(.pantryBody)
                                .foregroundStyle(Color.pantryTextPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(
                        top: 2,
                        leading: PlanListMetrics.recipeLeadingInset,
                        bottom: 2,
                        trailing: PlanListMetrics.horizontalInset
                    )
                )
                .listRowBackground(Color.pantryBackground)
                .listRowSeparatorTint(Color.pantryBorder.opacity(0.35))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        HapticFeedback.medium()
                        viewModel.clearPlannedRecipe(dayKey: dayKey, slot: slot)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        HapticFeedback.light()
                        singleRecipeForGrocery = recipe
                    } label: {
                        Label("Add to Grocery List", systemImage: "cart.badge.plus")
                    }
                    Button("Change…") {
                        mealPickerTarget = MealPickerTarget(dayKey: dayKey, slot: slot)
                    }
                    Button("Clear", role: .destructive) {
                        viewModel.clearPlannedRecipe(dayKey: dayKey, slot: slot)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func planDaySectionHeader(
        day: Date,
        dayKey: String,
        isToday: Bool,
        headerTint: Color,
        subTint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text(dayNumberString(day))
                    .font(.pantryLargeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(headerTint)
                    .monospacedDigit()
                    .frame(width: PlanListMetrics.dayNumberColumnWidth, alignment: .leading)

                Color.clear
                    .frame(width: max(0, PlanListMetrics.dayHeaderTextColumnOffset - PlanListMetrics.dayNumberColumnWidth))

                VStack(alignment: .leading, spacing: 2) {
                    Text(weekdayUppercased(day))
                        .font(.pantryCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(headerTint)
                    Text(monthUppercased(day))
                        .font(.pantryCaption)
                        .fontWeight(.regular)
                        .foregroundStyle(subTint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                planDayAddMenu(dayKey: dayKey)
            }
            .padding(.vertical, DesignTokens.spacingXS)

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.45))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pantryBackground)
    }

    private func planDayAddMenu(dayKey: String) -> some View {
        let hasPlannedRecipes = MealPlanSlot.allCases.contains {
            viewModel.plannedRecipe(dayKey: dayKey, slot: $0) != nil
        }
        return Menu {
            Button {
                HapticFeedback.light()
                onGenerateMealPlan()
            } label: {
                Label("Generate Meal Plan", systemImage: "calendar.badge.plus")
            }
            Button {
                HapticFeedback.light()
                addPlanDayGrocerySheetTarget = AddPlanDayGrocerySheetTarget(dayKeys: [dayKey])
            } label: {
                Label("Add to Grocery List", systemImage: "cart.badge.plus")
            }
            .disabled(!hasPlannedRecipes)
            Divider()
            ForEach(MealPlanSlot.allCases) { slot in
                Button {
                    mealPickerTarget = MealPickerTarget(dayKey: dayKey, slot: slot)
                } label: {
                    Label(slot.label, systemImage: slot.systemImage)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.pantryTitle3.weight(.semibold))
                .foregroundStyle(Color.pantrySecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Add meal")
    }

    private func dayNumberString(_ date: Date) -> String {
        let d = calendar.component(.day, from: date)
        return String(d)
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

#Preview {
    NavigationStack {
        PlanView(viewModel: PantryViewModel())
            .mainTabRootNavigationChrome(title: MainTabNavigationCopy.planNavigationTitle(plannedMealSlotCount: 0))
    }
}
