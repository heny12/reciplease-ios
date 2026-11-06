//
//  TonightMenuSheet.swift
//  Reciplease
//
//  One-sheet craving picker that replaced the five-page generation wizard.
//

import SwiftUI

struct TonightMenuSheet: View {
    @ObservedObject var viewModel: PantryViewModel
    @Binding var isPresented: Bool
    var onScanPantry: () -> Void

    @State private var moods: Set<String> = []
    @State private var strictness: MealPlanStrictness = .mostly
    @State private var showMore = false
    @State private var mealTypes: Set<String> = []
    @State private var cuisine = "Any"
    @State private var servings = 2
    @State private var equipment: Set<String> = []
    @State private var maxTime: Int? = nil
    @State private var customRequest = ""
    @State private var staples: [String] = []
    @State private var newStaple = ""
    @State private var dietary: Set<String> = []

    private let moodOptions: [(id: String, title: String, icon: String)] = [
        ("under_20m", "Quick (<20m)", "bolt.fill"),
        ("one_pan", "One-Pan", "fork.knife"),
        ("cozy", "Cozy", "flame.fill"),
        ("high_protein", "High Protein", "dumbbell.fill"),
        ("surprise_me", "Surprise Me", "sparkles")
    ]

    private let scopeOptions: [(MealPlanStrictness, String)] = [
        (.only, "Pantry Only"),
        (.mostly, "Allow 1–2 Extras"),
        (.any, "Flexible")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    Text("What sounds good tonight?")
                        .font(.pantryTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pantryTextPrimary)

                    Text("Pick a craving. Allergies and diets stay on, even for Surprise Me.")
                        .font(.pantrySubheadline)
                        .foregroundStyle(Color.pantryTextSecondary)

                    moodChips
                    if viewModel.ingredients.isEmpty {
                        emptyPantryCard
                    } else {
                        useFirstChips
                        scopePicker
                        staplesEditor
                        moreOptions
                        generateButton
                    }
                }
                .padding(DesignTokens.spacingLG)
            }
            .background(Color.pantryBackground)
            .navigationTitle("Tonight's Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
        .onAppear {
            staples = viewModel.confirmedStaplesForGeneration()
            dietary = Set(RecipeGenerationFormOptionData.preferredDietaryIdsFromStorage())
        }
    }

    private var moodChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(moodOptions, id: \.id) { option in
                chip(title: option.title, systemImage: option.icon, selected: moods.contains(option.id)) {
                    toggle(&moods, option.id)
                }
            }
        }
    }

    private var useFirstChips: some View {
        let highlighted = viewModel.ingredients.filter { $0.pinned || $0.useSoon }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Use these first")
                .font(.pantryHeadline)
            if highlighted.isEmpty {
                Text("Star a pantry item, or add a use-by date, and it will show up here.")
                    .font(.pantryCaption)
                    .foregroundStyle(Color.pantryTextSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(highlighted) { ingredient in
                        chip(
                            title: ingredient.useSoon ? "\(ingredient.generalName) · Use Soon" : ingredient.generalName,
                            systemImage: ingredient.pinned ? "star.fill" : "clock",
                            selected: ingredient.pinned
                        ) {
                            viewModel.setIngredientPinned(id: ingredient.id, pinned: !ingredient.pinned)
                        }
                    }
                }
            }
        }
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredient scope")
                .font(.pantryHeadline)
            ForEach(scopeOptions, id: \.0) { option in
                Button {
                    strictness = option.0
                    HapticFeedback.light()
                } label: {
                    HStack {
                        Image(systemName: strictness == option.0 ? "largecircle.fill.circle" : "circle")
                        Text(option.1)
                            .font(.pantryBody)
                        Spacer()
                    }
                    .foregroundStyle(Color.pantryTextPrimary)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var staplesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kitchen staples")
                .font(.pantryHeadline)
            Text("These are assumed on hand. Butter, honey, and flour drop off automatically for vegan or gluten-free cooking.")
                .font(.pantryCaption)
                .foregroundStyle(Color.pantryTextSecondary)
            FlowLayout(spacing: 8) {
                ForEach(staples, id: \.self) { staple in
                    chip(title: staple, systemImage: "xmark", selected: true) {
                        staples.removeAll { $0 == staple }
                        KitchenStaples.save(staples)
                    }
                }
            }
            HStack {
                TextField("Add a staple", text: $newStaple)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newStaple.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    staples.append(trimmed.capitalized)
                    newStaple = ""
                    KitchenStaples.save(staples)
                }
            }
        }
    }

    private var moreOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showMore.toggle() }
            } label: {
                HStack {
                    Text("More options")
                        .font(.pantryHeadline)
                    Spacer()
                    Image(systemName: showMore ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(Color.pantryPrimary)
            }
            .buttonStyle(.plain)
            if showMore {
                Text("Meal")
                    .font(.pantrySubheadline)
                FlowLayout(spacing: 8) {
                    ForEach(["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"], id: \.self) { meal in
                        chip(title: meal, systemImage: "fork.knife", selected: mealTypes.contains(meal)) {
                            toggle(&mealTypes, meal)
                        }
                    }
                }
                Text("Cuisine")
                    .font(.pantrySubheadline)
                Picker("Cuisine", selection: $cuisine) {
                    ForEach(RecipeGenerationFormOptionData.cuisines) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                Text("Equipment")
                    .font(.pantrySubheadline)
                FlowLayout(spacing: 8) {
                    ForEach([
                        ("stovetop", "Stovetop"),
                        ("oven", "Oven"),
                        ("air_fryer", "Air Fryer"),
                        ("microwave", "Microwave"),
                        ("slow_cooker", "Slow Cooker")
                    ], id: \.0) { item in
                        chip(title: item.1, systemImage: "cooktop", selected: equipment.contains(item.0)) {
                            toggle(&equipment, item.0)
                        }
                    }
                }
                Stepper(maxTime == nil ? "Max time: Any" : "Max time: \(maxTime!) min", value: Binding(
                    get: { maxTime ?? 30 },
                    set: { maxTime = $0 }
                ), in: 10...120, step: 5)
                Button("Clear time limit") { maxTime = nil }
                    .font(.pantryCaption)
                Text("Never include")
                    .font(.pantrySubheadline)
                FlowLayout(spacing: 8) {
                    ForEach(RecipeGenerationFormOptionData.dietaryOptions) { option in
                        chip(title: option.name, systemImage: "checkmark.shield", selected: dietary.contains(option.id)) {
                            if dietary.contains(option.id) { dietary.remove(option.id) } else { dietary.insert(option.id) }
                            RecipeGenerationFormOptionData.persistPreferredDietaryIds(Array(dietary))
                            staples = KitchenStaples.filtered(staples, dietaryExclusions: viewModel.dietaryExclusionsForGeneration())
                        }
                    }
                }
                TextField("Anything else? Keep it short.", text: $customRequest, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var emptyPantryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your pantry is empty")
                .font(.pantryHeadline)
            Text("Scan the fridge or drop in a few staples, then we’ll suggest dinner.")
                .font(.pantryBody)
                .foregroundStyle(Color.pantryTextSecondary)
            Button {
                isPresented = false
                onScanPantry()
            } label: {
                labelButton("Scan Fridge/Pantry", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.plain)
            Button {
                viewModel.addKitchenStaplesToPantry()
                staples = viewModel.confirmedStaplesForGeneration()
                HapticFeedback.success()
            } label: {
                labelButton("Add Staples", systemImage: "basket.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingMD)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.pantrySurface))
    }

    private var generateButton: some View {
        Button {
            var draft = TonightMenuDraft()
            draft.moods = Array(moods)
            draft.strictness = strictness
            draft.mealTypes = Array(mealTypes)
            draft.cuisine = cuisine
            draft.servings = servings
            draft.equipment = Array(equipment)
            draft.maxTimeMinutes = maxTime
            draft.customRequest = customRequest
            draft.confirmedStaples = staples
            draft.count = 6
            KitchenStaples.save(staples)
            isPresented = false
            Task { await viewModel.generateTonightMenu(draft) }
        } label: {
            Text("Show me 6 dinner ideas")
                .font(.pantryHeadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.pantryPrimary)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ set: inout Set<String>, _ id: String) {
        HapticFeedback.light()
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func chip(title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(selected ? Color.pantryPrimary : Color.pantrySurface))
            .foregroundStyle(selected ? Color.white : Color.pantryTextPrimary)
            .overlay(Capsule().stroke(Color.pantryPrimary.opacity(selected ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func labelButton(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title).fontWeight(.semibold)
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pantryPrimary))
        .foregroundStyle(Color.white)
    }
}
