//
//  CookModeView.swift
//  Reciplease
//
//  Cooking mode with prep checkoffs, structured steps, and timers that survive swipes.
//

import SwiftUI

struct ActiveCookTimer: Identifiable {
    let id = UUID()
    var label: String
    var endsAt: Date
    var duration: TimeInterval
}

struct CookModeView: View {
    @ObservedObject var viewModel: PantryViewModel
    let recipeId: UUID
    let servings: Int
    @Binding var isPresented: Bool

    @State private var currentStepIndex = 0
    @State private var preppedIDs: Set<String> = []
    @State private var timers: [ActiveCookTimer] = []
    @State private var showCompletion = false
    @State private var acquiredWakeLock = false

    private var recipe: Recipe? { viewModel.recipe(id: recipeId) }

    var body: some View {
        ZStack {
            Color.pantrySecondary.ignoresSafeArea()
            if let recipe {
                VStack(spacing: 0) {
                    header(recipe: recipe, count: displaySteps(recipe).count)
                    TabView(selection: $currentStepIndex) {
                        ForEach(Array(displaySteps(recipe).enumerated()), id: \.offset) { index, step in
                            stepPage(recipe: recipe, step: step, index: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    timerBar
                    footer(recipe: recipe, count: displaySteps(recipe).count)
                }
            }
        }
        .onAppear {
            ScreenWakeLockManager.shared.acquire()
            acquiredWakeLock = true
            AppAnalytics.log(.cookingStarted, parameters: ["recipe_id": recipeId.uuidString])
        }
        .onDisappear {
            if acquiredWakeLock {
                ScreenWakeLockManager.shared.release()
                acquiredWakeLock = false
            }
        }
        .sheet(isPresented: $showCompletion) {
            if let recipe {
                CookingCompletionSheet(viewModel: viewModel, recipe: recipe, isPresented: $showCompletion) {
                    isPresented = false
                }
            }
        }
    }

    private func header(recipe: Recipe, count: Int) -> some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.pantryHeadline)
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            Spacer()
            Text("Step \(min(currentStepIndex + 1, max(count, 1))) of \(max(count, 1))")
                .font(.pantrySubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, DesignTokens.spacingMD)
    }

    private func stepPage(recipe: Recipe, step: CookStepPresentation, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                Text(step.text)
                    .font(.pantryTitle2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let heat = step.heat {
                    Label(heat, systemImage: "flame")
                        .font(.pantrySubheadline)
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                if let cue = step.donenessCue {
                    Text(cue)
                        .font(.pantryBody)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                if let seconds = step.timerSeconds {
                    Button {
                        startTimer(seconds: seconds, label: "Step \(index + 1)")
                    } label: {
                        Label(timerTitle(seconds), systemImage: "timer")
                            .font(.pantryHeadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white))
                            .foregroundStyle(Color.pantrySecondary)
                    }
                    .buttonStyle(.plain)
                }
                if !step.uses.isEmpty {
                    Text("For this step")
                        .font(.pantrySubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white.opacity(0.75))
                    ForEach(step.uses) { use in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                if preppedIDs.contains(use.id) { preppedIDs.remove(use.id) } else { preppedIDs.insert(use.id) }
                            } label: {
                                Image(systemName: preppedIDs.contains(use.id) ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundStyle(Color.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Prep checkoff")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scaledUse(use, recipe: recipe))
                                    .font(.pantryTitle3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white)
                                Text(use.name)
                                    .font(.pantryBody)
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func footer(recipe: Recipe, count: Int) -> some View {
        HStack(spacing: 12) {
            Button("Back") {
                currentStepIndex = max(currentStepIndex - 1, 0)
            }
            .disabled(currentStepIndex == 0)
            Spacer()
            Button(currentStepIndex >= count - 1 ? "Done Cooking!" : "Next") {
                if currentStepIndex >= count - 1 {
                    showCompletion = true
                } else {
                    currentStepIndex += 1
                }
            }
        }
        .font(.pantryHeadline)
        .foregroundStyle(Color.white)
        .padding(DesignTokens.spacingLG)
    }

    private var timerBar: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let active = timers.filter { $0.endsAt > context.date }
            if !active.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(active) { timer in
                            let remaining = max(0, Int(timer.endsAt.timeIntervalSince(context.date)))
                            Text("\(timer.label) \(remaining / 60):\(String(format: "%02d", remaining % 60))")
                                .font(.pantryCaption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white))
                                .foregroundStyle(Color.pantrySecondary)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
        }
    }

    private func startTimer(seconds: Int, label: String) {
        timers.append(ActiveCookTimer(label: label, endsAt: Date().addingTimeInterval(TimeInterval(seconds)), duration: TimeInterval(seconds)))
        HapticFeedback.success()
    }

    private func timerTitle(_ seconds: Int) -> String {
        if seconds >= 3600 { return "Start \(seconds / 3600) hr timer" }
        if seconds >= 60 { return "Start \(seconds / 60) min timer" }
        return "Start \(seconds) sec timer"
    }

    private func scaledUse(_ use: StructuredStepIngredientUse, recipe: Recipe) -> String {
        RecipeQuantityScaling.scaledDisplay(
            amount: use.amount,
            unit: use.unit,
            quantity: use.displayQuantity ?? "",
            recipeServings: recipe.servings,
            currentServings: servings
        ).text
    }

    private func displaySteps(_ recipe: Recipe) -> [CookStepPresentation] {
        if let structured = recipe.structuredSteps, !structured.isEmpty {
            return structured.enumerated().map { offset, step in
                let text = step.text.isEmpty ? (recipe.steps.indices.contains(offset) ? recipe.steps[offset] : "") : step.text
                return CookStepPresentation(
                    text: text,
                    heat: step.heat,
                    donenessCue: step.donenessCue,
                    timerSeconds: CookTimer.seconds(timerSeconds: step.timerSeconds, stepText: text),
                    uses: step.ingredientUses
                )
            }
        }
        return recipe.steps.enumerated().map { offset, text in
            CookStepPresentation(
                text: text,
                heat: nil,
                donenessCue: nil,
                timerSeconds: StepTimerDetector.detect(in: text),
                uses: legacyUses(for: text, recipe: recipe, index: offset)
            )
        }
    }

    /// Legacy recipes only: show ingredients whose names appear in the step, with the step's share when the name repeats.
    private func legacyUses(for step: String, recipe: Recipe, index: Int) -> [StructuredStepIngredientUse] {
        let lowered = step.lowercased()
        return recipe.ingredients.compactMap { ingredient in
            let name = ingredient.name.lowercased()
            guard !name.isEmpty, lowered.contains(name) else { return nil }
            let mentions = recipe.steps.filter { $0.lowercased().contains(name) }.count
            let share = max(mentions, 1)
            let amount = ingredient.amount.map { $0 / Double(share) }
            return StructuredStepIngredientUse(
                ingredientId: ingredient.serverKey ?? ingredient.id.uuidString,
                name: ingredient.name,
                amount: amount,
                unit: ingredient.unit,
                displayQuantity: ingredient.quantity
            )
        }
    }
}

struct CookStepPresentation: Identifiable {
    let id = UUID()
    var text: String
    var heat: String?
    var donenessCue: String?
    var timerSeconds: Int?
    var uses: [StructuredStepIngredientUse]
}

struct CookingCompletionSheet: View {
    @ObservedObject var viewModel: PantryViewModel
    let recipe: Recipe
    @Binding var isPresented: Bool
    var onFinished: () -> Void

    @State private var rating = 0
    @State private var wouldCookAgain = true
    @State private var notes = ""
    @State private var selectedRemovals: Set<UUID> = []
    @State private var undoSnapshot: [Ingredient]?
    @State private var didApply = false

    private var deductionLines: [(id: UUID, name: String, quantity: String)] {
        recipe.ingredients.compactMap { ingredient in
            guard let match = viewModel.ingredients.first(where: {
                PantryMatchCalculator.isInPantry(ingredient.name, pantryNames: [$0.generalName])
            }) else { return nil }
            return (match.id, match.generalName, ingredient.quantity)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    Text("Done Cooking!")
                        .font(.pantryLargeTitle)
                        .fontWeight(.bold)
                    Text(recipe.name)
                        .font(.pantryTitle3)
                        .foregroundStyle(Color.pantryTextSecondary)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(Color.pantryPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("Would cook again", isOn: $wouldCookAgain)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    if !viewModel.isFavorite(recipeId: recipe.id) {
                        Button("Save to Cookbook") {
                            if let session = recipe.generationSessionId, let pitch = recipe.pitchId {
                                Task { await viewModel.savePitchToCookbook(pitch, sessionId: session) }
                            } else if let cookbook = viewModel.defaultCookbookId {
                                viewModel.addRecipeToCookbook(recipeId: recipe.id, cookbookId: cookbook, navigateToCookbooksTab: false)
                            }
                        }
                        .font(.pantryHeadline)
                    }
                    Text("Pantry check")
                        .font(.pantryHeadline)
                    Text("Check only items you used up. A spoonful does not delete the jar.")
                        .font(.pantryCaption)
                        .foregroundStyle(Color.pantryTextSecondary)
                    ForEach(deductionLines, id: \.id) { line in
                        Button {
                            if selectedRemovals.contains(line.id) { selectedRemovals.remove(line.id) } else { selectedRemovals.insert(line.id) }
                        } label: {
                            HStack {
                                Image(systemName: selectedRemovals.contains(line.id) ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading) {
                                    Text("Remove \(line.name)")
                                    if !line.quantity.isEmpty {
                                        Text("Recipe used \(line.quantity)")
                                            .font(.pantryCaption)
                                            .foregroundStyle(Color.pantryTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .foregroundStyle(Color.pantryTextPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    if didApply {
                        Button("Undo pantry changes") {
                            if let undoSnapshot {
                                viewModel.restorePantry(undoSnapshot)
                                didApply = false
                                selectedRemovals = []
                            }
                        }
                        .font(.pantryHeadline)
                    }
                    Button("Save and close") {
                        if !didApply {
                            undoSnapshot = viewModel.applyConfirmedPantryRemovals(Array(selectedRemovals))
                            didApply = true
                        }
                        viewModel.recordCooked(
                            recipeId: recipe.id,
                            rating: rating == 0 ? nil : rating,
                            wouldCookAgain: wouldCookAgain,
                            notes: notes
                        )
                        isPresented = false
                        onFinished()
                    }
                    .font(.pantryHeadline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pantryPrimary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(DesignTokens.spacingLG)
            }
            .navigationTitle("Nice work")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
