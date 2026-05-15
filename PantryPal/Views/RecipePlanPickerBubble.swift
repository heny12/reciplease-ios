//
//  RecipePlanPickerBubble.swift
//  PantryPal
//
//  Centered bubble to add the current recipe to the meal plan (day → meal slot).
//

import SwiftUI

struct RecipePlanPickerBubble: View {
    @ObservedObject var viewModel: PantryViewModel
    let recipeId: UUID
    let recipeName: String
    var onDismiss: () -> Void

    private let calendar = Calendar.current

    @State private var selectedDayKey: String?
    @State private var replacePrompt: ReplacePrompt?

    private var replaceAlertPresented: Binding<Bool> {
        Binding(
            get: { replacePrompt != nil },
            set: { newValue in
                if !newValue { replacePrompt = nil }
            }
        )
    }

    private struct ReplacePrompt {
        let dayKey: String
        let slot: MealPlanSlot
        let existingRecipeName: String
    }

    /// Same range as Plan tab: yesterday through next 30 days.
    private var planDays: [Date] {
        let startOfToday = calendar.startOfDay(for: Date())
        return (-1...30).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)
        }
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
                    header
                    Rectangle()
                        .fill(Color.pantryBorder.opacity(0.45))
                        .frame(height: 1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let dayKey = selectedDayKey {
                                slotList(dayKey: dayKey)
                            } else {
                                dayList
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
        .alert("Replace planned meal?", isPresented: replaceAlertPresented) {
            Button("Replace", role: .destructive) {
                guard let prompt = replacePrompt else { return }
                HapticFeedback.medium()
                viewModel.setPlannedRecipe(dayKey: prompt.dayKey, slot: prompt.slot, recipeId: recipeId)
                replacePrompt = nil
                onDismiss()
            }
            Button("Cancel", role: .cancel) {
                replacePrompt = nil
            }
        } message: {
            if let prompt = replacePrompt {
                Text(
                    "“\(prompt.existingRecipeName)” is already planned for \(prompt.slot.label) on that day. Replace it with “\(recipeName)”?"
                )
            }
        }
    }

    private var header: some View {
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
                Text(selectedDayKey == nil ? "Add to plan" : dayHeaderTitle(for: selectedDayKey!))
                    .font(.pantryHeadline)
                    .foregroundColor(.pantryTextPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                Text(selectedDayKey == nil ? recipeName : "Choose a meal")
                    .font(.pantryCaption)
                    .foregroundColor(.pantryTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            if selectedDayKey != nil {
                Button {
                    HapticFeedback.light()
                    selectedDayKey = nil
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.pantryTitle2)
                        .foregroundStyle(Color.pantrySecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to days")
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private var dayList: some View {
        ForEach(planDays, id: \.self) { day in
            let key = mealPlanDayKey(for: day)
            Button {
                HapticFeedback.light()
                selectedDayKey = key
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                    Image(systemName: "calendar")
                        .font(.pantryTitle3)
                        .foregroundStyle(Color.pantrySecondary)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayPrimaryLabel(day))
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantryTextPrimary)
                            .multilineTextAlignment(.leading)
                        if !calendar.isDateInToday(day), !calendar.isDateInTomorrow(day), !calendar.isDateInYesterday(day) {
                            Text(Self.detailDateFormatter.string(from: day))
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.pantryCaption.weight(.semibold))
                        .foregroundStyle(Color.pantryTextSecondary.opacity(0.55))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, DesignTokens.spacingMD)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.pantryBorder.opacity(0.35))
                .frame(height: 1)
                .padding(.leading, DesignTokens.spacingMD + 28 + DesignTokens.spacingSM)
        }
    }

    @ViewBuilder
    private func slotList(dayKey: String) -> some View {
        ForEach(MealPlanSlot.allCases) { slot in
            Button {
                selectSlot(dayKey: dayKey, slot: slot)
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                    Image(systemName: slot.systemImage)
                        .font(.pantryTitle3)
                        .foregroundStyle(Color.pantrySecondary.opacity(0.9))
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.label)
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantryTextPrimary)
                            .multilineTextAlignment(.leading)
                        if let planned = viewModel.plannedRecipe(dayKey: dayKey, slot: slot) {
                            Text(planned.name)
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary)
                                .lineLimit(2)
                        } else {
                            Text("Open")
                                .font(.pantryCaption)
                                .foregroundColor(.pantryTextSecondary.opacity(0.7))
                        }
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
                .padding(.leading, DesignTokens.spacingMD + 28 + DesignTokens.spacingSM)
        }
    }

    private func selectSlot(dayKey: String, slot: MealPlanSlot) {
        if let existing = viewModel.plannedRecipe(dayKey: dayKey, slot: slot) {
            if existing.id == recipeId {
                HapticFeedback.light()
                onDismiss()
                return
            }
            replacePrompt = ReplacePrompt(dayKey: dayKey, slot: slot, existingRecipeName: existing.name)
            return
        }
        HapticFeedback.medium()
        viewModel.setPlannedRecipe(dayKey: dayKey, slot: slot, recipeId: recipeId)
        onDismiss()
    }

    private func mealPlanDayKey(for day: Date) -> String {
        let start = calendar.startOfDay(for: day)
        let c = calendar.dateComponents([.year, .month, .day], from: start)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func dayHeaderTitle(for dayKey: String) -> String {
        guard let day = planDays.first(where: { mealPlanDayKey(for: $0) == dayKey }) else {
            return dayKey
        }
        return Self.detailDateFormatter.string(from: day)
    }

    private func dayPrimaryLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return Self.weekdayFormatter.string(from: day)
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f
    }()
}
