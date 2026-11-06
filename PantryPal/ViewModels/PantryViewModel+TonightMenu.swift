//
//  PantryViewModel+TonightMenu.swift
//  Reciplease
//
//  Fresh Picks sessions, pitch expansion, and cooking follow-through.
//

import Foundation

struct TonightMenuDraft {
    var moods: [String] = []
    var strictness: MealPlanStrictness = .mostly
    var mealTypes: [String] = []
    var cuisine: String?
    var servings: Int = 2
    var equipment: [String] = []
    var maxTimeMinutes: Int?
    var customRequest: String = ""
    var confirmedStaples: [String] = []
    var excludeSignatures: [String] = []
    var similarTo: String?
    var sessionId: String?
    var count: Int = 6
    var appendToSession: Bool = false
}

extension PantryViewModel {
    func dietaryExclusionsForGeneration() -> [String] {
        DietaryConstraint.wireExclusions(from: RecipeGenerationFormOptionData.preferredDietaryIdsFromStorage())
    }

    func confirmedStaplesForGeneration() -> [String] {
        let saved = KitchenStaples.loadSaved()
        return KitchenStaples.filtered(saved, dietaryExclusions: dietaryExclusionsForGeneration())
    }

    @MainActor
    func setIngredientPinned(id: UUID, pinned: Bool) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        ingredients[index].pinned = pinned
        saveData()
    }

    @MainActor
    func setIngredientExpiration(id: UUID, date: Date?) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        ingredients[index].expirationDate = date
        saveData()
    }

    @MainActor
    func addKitchenStaplesToPantry() {
        let staples = confirmedStaplesForGeneration()
        for name in staples {
            if ingredients.contains(where: { $0.generalName.caseInsensitiveCompare(name) == .orderedSame }) { continue }
            guard ingredients.count < AppConfig.maxIngredients else { break }
            var ingredient = Ingredient(generalName: name, quantity: nil)
            ingredient.capitalizeName()
            ingredients.append(ingredient)
        }
        pantryInsights = []
        showEmptyPantryGuidance = false
        saveData()
    }

    func generateTonightMenu(_ draft: TonightMenuDraft) async {
        if ingredients.isEmpty {
            await MainActor.run { showEmptyPantryGuidance = true }
            return
        }
        let prompt: String?
        if draft.appendToSession && draft.similarTo == nil {
            let trimmed = draft.customRequest.trimmingCharacters(in: .whitespacesAndNewlines)
            prompt = trimmed.isEmpty ? nil : String(trimmed.prefix(AppConfig.maxGeneratePromptLength))
        } else if draft.appendToSession {
            prompt = TonightMenuRequestBuilder.composedPrompt(
                mealTypes: [],
                cuisine: nil,
                custom: nil,
                similarTo: draft.similarTo,
                maxLength: AppConfig.maxGeneratePromptLength
            )
        } else {
            prompt = TonightMenuRequestBuilder.composedPrompt(
                mealTypes: draft.mealTypes,
                cuisine: draft.cuisine,
                custom: draft.customRequest,
                similarTo: draft.similarTo,
                maxLength: AppConfig.maxGeneratePromptLength
            )
        }
        let exclusions = dietaryExclusionsForGeneration()
        let staples = draft.confirmedStaples.isEmpty ? confirmedStaplesForGeneration() : KitchenStaples.filtered(draft.confirmedStaples, dietaryExclusions: exclusions)
        let pinned = ingredients.filter(\.pinned).map(\.generalName)
        let wireIngredients = ingredients.map { ingredient in
            TonightMenuWireIngredient(
                id: ingredient.id.uuidString,
                generalName: ingredient.generalName,
                specificName: ingredient.specificName,
                quantity: ingredient.quantity,
                amount: ingredient.amount,
                unit: ingredient.unit,
                pinned: ingredient.pinned
            )
        }
        let wire = TonightMenuWireRequest(
            ingredients: wireIngredients,
            prompt: prompt,
            strictness: draft.strictness.rawValue,
            count: draft.count,
            moods: draft.moods,
            dietaryExclusions: exclusions,
            confirmedStaples: staples,
            pinnedIngredients: pinned,
            maxTimeMinutes: draft.maxTimeMinutes,
            servings: draft.servings,
            equipment: draft.equipment,
            excludeSignatures: draft.excludeSignatures,
            sessionId: draft.sessionId
        )

        let allowed = await MainActor.run { () -> Bool in
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
            if GenerationCreditsManager.shared.canConsumeGenerationCredit() { return true }
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
            return false
        }
        guard allowed else { return }

        await MainActor.run {
            if draft.appendToSession {
                isDealingMorePitches = true
            } else {
                isGeneratingRecipes = true
            }
            errorMessage = nil
            showEmptyPantryGuidance = false
        }
        defer {
            Task { @MainActor in
                isGeneratingRecipes = false
                isDealingMorePitches = false
            }
        }

        do {
            let result = try await apiService.fetchTonightMenu(wire)
            guard GenerationCreditPolicy.shouldConsumeCredit(httpStatus: 200) else { return }
            await MainActor.run {
                guard !result.pitches.isEmpty else {
                    showNoRecipesAlert = true
                    return
                }
                storeTonightMenuResult(result, draft: draft, wire: wire, staples: staples, pinned: pinned)
                usageTracker.recordRecipeGeneration()
                GenerationCreditsManager.shared.consumeGenerationCredit()
                ReviewPromptService.shared.registerGenerationBatchViewed()
                var params: [String: Any] = [
                    "recipe_count": result.pitches.count,
                    "ingredient_count": ingredients.count,
                    "strictness": draft.strictness.rawValue,
                    "used_v1_fallback": result.usedV1Fallback,
                    "appended": draft.appendToSession
                ]
                AppAnalytics.log(.recipesGenerated, parameters: params)
                let firstKey = "Reciplease.Analytics.FirstRecipeGenerated"
                if !UserDefaults.standard.bool(forKey: firstKey) {
                    UserDefaults.standard.set(true, forKey: firstKey)
                    AppAnalytics.log(.firstRecipeGenerated, parameters: ["count": result.pitches.count])
                }
                if !draft.appendToSession {
                    shouldNavigateToFreshPicks = true
                }
            }
        } catch let error as APIError {
            await MainActor.run { presentGenerationFailure(error) }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to generate recipes. Please try again."
            }
        }
    }

    @MainActor
    private func storeTonightMenuResult(
        _ result: RecipeAPIService.TonightMenuFetchResult,
        draft: TonightMenuDraft,
        wire: TonightMenuWireRequest,
        staples: [String],
        pinned: [String]
    ) {
        let focus = pinned.isEmpty ? Array(ingredients.prefix(2).map(\.generalName)) : Array(pinned.prefix(2))
        let constraints = GenerationConstraintSnapshot(
            strictness: wire.strictness,
            moods: wire.moods,
            dietaryExclusions: wire.dietaryExclusions,
            confirmedStaples: staples,
            pinnedIngredients: pinned,
            mealTypes: draft.mealTypes,
            cuisine: draft.cuisine,
            servings: draft.servings,
            equipment: draft.equipment,
            maxTimeMinutes: draft.maxTimeMinutes,
            prompt: wire.prompt,
            ingredientNames: ingredients.map(\.generalName)
        )
        if draft.appendToSession, let sessionId = draft.sessionId ?? activeGenerationSessionId,
           let index = generationSessions.firstIndex(where: { $0.sessionId == sessionId }) {
            var session = generationSessions[index]
            let existing = Set(session.pitches.map(\.signature).map { $0.lowercased() })
            for pitch in result.pitches where !existing.contains(pitch.signature.lowercased()) {
                session.pitches.append(pitch)
            }
            for (key, recipe) in result.expandedByPitchId {
                var stamped = recipe.stampedForLibrary()
                stamped.pitchId = key
                stamped.generationSessionId = session.sessionId
                session.expandedRecipes[key] = stamped
                rememberExpandedRecipe(stamped, pitchId: key, sessionId: session.sessionId)
            }
            session.summaryLabel = TonightMenuRequestBuilder.summaryLabel(ingredientNames: focus, count: session.pitches.count)
            generationSessions[index] = session
            activeGenerationSessionId = session.sessionId
        } else {
            let sessionId = result.sessionId ?? UUID().uuidString
            var expanded: [String: Recipe] = [:]
            for (key, recipe) in result.expandedByPitchId {
                var stamped = recipe.stampedForLibrary()
                stamped.pitchId = key
                stamped.generationSessionId = sessionId
                expanded[key] = stamped
                rememberExpandedRecipe(stamped, pitchId: key, sessionId: sessionId)
            }
            let session = GenerationSession(
                sessionId: sessionId,
                createdAt: Date(),
                summaryLabel: TonightMenuRequestBuilder.summaryLabel(ingredientNames: focus, count: result.pitches.count),
                constraints: constraints,
                pitches: result.pitches,
                expandedRecipes: expanded,
                viewedPitchIds: [],
                savedPitchIds: [],
                dismissedPitchIds: [],
                usedV1Fallback: result.usedV1Fallback
            )
            generationSessions.insert(session, at: 0)
            activeGenerationSessionId = sessionId
        }
        saveData()
    }

    @MainActor
    private func rememberExpandedRecipe(_ recipe: Recipe, pitchId: String, sessionId: String) {
        var stored = recipe
        stored.pitchId = pitchId
        stored.generationSessionId = sessionId
        if let index = recipes.firstIndex(where: { $0.id == stored.id }) {
            recipes[index] = stored
        } else if let index = favoritedRecipes.firstIndex(where: { $0.id == stored.id }) {
            favoritedRecipes[index] = stored
        } else {
            recipes.insert(stored, at: 0)
        }
    }

    func expandPitch(pitchId: String, in sessionId: String) async -> Recipe? {
        let cached: Recipe? = await MainActor.run {
            guard let session = generationSessions.first(where: { $0.sessionId == sessionId }),
                  let recipe = session.expandedRecipes[pitchId] else { return nil }
            markPitch(pitchId, in: sessionId, viewed: true)
            return recipe
        }
        if let cached {
            AppAnalytics.log(.pitchExpanded, parameters: ["cached": true])
            return cached
        }

        let context: (RecipePitch, TonightMenuWireRequest, String)? = await MainActor.run {
            guard let session = generationSessions.first(where: { $0.sessionId == sessionId }),
                  let pitch = session.pitches.first(where: { $0.pitchId == pitchId }) else { return nil }
            expandingPitchTitle = pitch.title
            isExpandingPitch = true
            let wire = wireRequest(from: session.constraints, count: 1, sessionId: sessionId, exclude: [])
            return (pitch, wire, pitch.title)
        }
        guard let context else { return nil }
        defer { Task { @MainActor in isExpandingPitch = false; expandingPitchTitle = nil } }

        do {
            let expanded = try await apiService.expandPitch(sessionId: sessionId, pitch: context.0, wire: context.1)
            let recipe = await MainActor.run { () -> Recipe in
                var stamped = expanded.recipe.stampedForLibrary()
                stamped.pitchId = pitchId
                stamped.generationSessionId = sessionId
                stamped.hook = stamped.hook ?? context.0.hook
                stamped.lane = stamped.lane ?? context.0.lane
                if let index = generationSessions.firstIndex(where: { $0.sessionId == sessionId }) {
                    generationSessions[index].expandedRecipes[pitchId] = stamped
                    if !generationSessions[index].viewedPitchIds.contains(pitchId) {
                        generationSessions[index].viewedPitchIds.append(pitchId)
                    }
                }
                rememberExpandedRecipe(stamped, pitchId: pitchId, sessionId: sessionId)
                saveData()
                return stamped
            }
            AppAnalytics.log(.pitchExpanded, parameters: ["cached": expanded.cached, "pitch_id": pitchId])
            AppAnalytics.log(.pitchSelected, parameters: ["title": context.2])
            return recipe
        } catch let error as APIError {
            await MainActor.run { presentGenerationFailure(error) }
            return nil
        } catch {
            await MainActor.run { errorMessage = "We couldn't prep that recipe. Please try again." }
            return nil
        }
    }

    @MainActor
    func markPitch(_ pitchId: String, in sessionId: String, viewed: Bool) {
        guard let index = generationSessions.firstIndex(where: { $0.sessionId == sessionId }) else { return }
        if viewed, !generationSessions[index].viewedPitchIds.contains(pitchId) {
            generationSessions[index].viewedPitchIds.append(pitchId)
            saveData()
        }
    }

    @MainActor
    func dismissPitch(_ pitchId: String, in sessionId: String) {
        guard let index = generationSessions.firstIndex(where: { $0.sessionId == sessionId }) else { return }
        if !generationSessions[index].dismissedPitchIds.contains(pitchId) {
            generationSessions[index].dismissedPitchIds.append(pitchId)
            saveData()
        }
    }

    func dealMorePitches(in sessionId: String, like pitch: RecipePitch?) async {
        let draft: TonightMenuDraft? = await MainActor.run {
            guard let session = generationSessions.first(where: { $0.sessionId == sessionId }) else { return nil }
            var draft = TonightMenuDraft()
            draft.moods = session.constraints.moods
            draft.strictness = MealPlanStrictness(rawValue: session.constraints.strictness) ?? .mostly
            draft.mealTypes = session.constraints.mealTypes
            draft.cuisine = session.constraints.cuisine
            draft.servings = session.constraints.servings ?? 2
            draft.equipment = session.constraints.equipment
            draft.maxTimeMinutes = session.constraints.maxTimeMinutes
            draft.customRequest = session.constraints.prompt ?? ""
            draft.confirmedStaples = session.constraints.confirmedStaples
            draft.excludeSignatures = session.pitches.map(\.signature)
            draft.similarTo = pitch?.title
            draft.sessionId = sessionId
            draft.count = 3
            draft.appendToSession = true
            return draft
        }
        guard let draft else { return }
        await generateTonightMenu(draft)
    }

    func savePitchToCookbook(_ pitchId: String, sessionId: String) async {
        guard let recipe = await expandPitch(pitchId: pitchId, in: sessionId) else { return }
        await MainActor.run {
            var stored = recipe
            if !stored.tags.contains(where: { $0.caseInsensitiveCompare(RecipeCollectionTag.wantToTry) == .orderedSame }) {
                stored.tags.append(RecipeCollectionTag.wantToTry)
            }
            updateRecipeInBothLists(recipeId: stored.id) { _ in stored }
            let destination = cookbooks.first(where: { $0.isDefaultFavorites })?.id ?? cookbooks.first?.id
            if let destination {
                addRecipeToCookbook(recipeId: stored.id, cookbookId: destination, navigateToCookbooksTab: false)
            }
            if let index = generationSessions.firstIndex(where: { $0.sessionId == sessionId }),
               !generationSessions[index].savedPitchIds.contains(pitchId) {
                generationSessions[index].savedPitchIds.append(pitchId)
                generationSessions[index].expandedRecipes[pitchId] = stored
                saveData()
            }
        }
        ensureHeroImage(for: recipe.id)
    }

    func cookPitchTonight(_ pitchId: String, sessionId: String) async {
        guard let recipe = await expandPitch(pitchId: pitchId, in: sessionId) else { return }
        await MainActor.run {
            let dayKey = Self.todayMealPlanKey()
            setPlannedRecipe(dayKey: dayKey, slot: .dinner, recipeId: recipe.id)
            LocalNotificationManager.shared.rescheduleTomorrowMealReminder(using: self)
        }
        ensureHeroImage(for: recipe.id)
    }

    func ensureHeroImage(for recipeId: UUID) {
        guard let recipe = recipe(id: recipeId), recipe.imageURL == nil, !recipe.isGeneratingImage else { return }
        Task { await generateRecipeImage(recipeId: recipeId) }
    }

    @MainActor
    func toggleRecipeTag(_ tag: String, recipeId: UUID) {
        updateRecipeInBothLists(recipeId: recipeId) { recipe in
            var copy = recipe
            if let index = copy.tags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                copy.tags.remove(at: index)
            } else {
                copy.tags.append(tag)
            }
            return copy
        }
    }

    @MainActor
    func undoRecipeModification(recipeId: UUID) {
        updateRecipeInBothLists(recipeId: recipeId) { recipe in
            recipe.restoringUndo() ?? recipe
        }
    }

    @MainActor
    func recordCooked(recipeId: UUID, rating: Int?, wouldCookAgain: Bool?, notes: String?) {
        updateRecipeInBothLists(recipeId: recipeId) { recipe in
            var copy = recipe
            copy.cookedCount += 1
            copy.lastCookedAt = Date()
            if let rating { copy.rating = rating }
            if let wouldCookAgain { copy.wouldCookAgain = wouldCookAgain }
            if let notes, !notes.isEmpty { copy.cookNotes = notes }
            return copy
        }
        ReviewPromptService.shared.registerCookingCompleted()
        let name = recipe(id: recipeId)?.name ?? ""
        AppAnalytics.log(.cookingCompleted, parameters: ["recipe_name": name, "rating": rating ?? 0])
    }

    /// Removes only the pantry items the cook confirmed. Returns the previous pantry for undo.
    @MainActor
    func applyConfirmedPantryRemovals(_ ingredientIDs: [UUID]) -> [Ingredient] {
        let previous = ingredients
        guard !ingredientIDs.isEmpty else { return previous }
        ingredients.removeAll { ingredientIDs.contains($0.id) }
        pantryInsights = []
        saveData()
        return previous
    }

    @MainActor
    func restorePantry(_ snapshot: [Ingredient]) {
        ingredients = snapshot
        saveData()
    }

    func remapRecipeIdentity(from old: UUID, to new: UUID) {
        guard old != new else { return }
        for index in cookbooks.indices {
            cookbooks[index].recipeIds = cookbooks[index].recipeIds.map { $0 == old ? new : $0 }
        }
        var nextPlan = mealPlanByDay
        for (day, plan) in mealPlanByDay {
            var copy = plan
            for slot in MealPlanSlot.allCases where copy.recipeId(for: slot) == old {
                copy.setRecipe(new, for: slot)
            }
            nextPlan[day] = copy
        }
        mealPlanByDay = nextPlan
        if let score = pantryMatchScores.removeValue(forKey: old) {
            pantryMatchScores[new] = score
        }
    }

    @MainActor
    func presentGenerationFailure(_ error: APIError) {
        if let quota = error.quotaDetails {
            GenerationCreditsManager.shared.noteServerQuota(quota)
            GenerationCreditsManager.shared.presentGenerationLimitSheet()
        }
        errorMessage = error.localizedDescription
    }

    private func wireRequest(
        from constraints: GenerationConstraintSnapshot,
        count: Int,
        sessionId: String?,
        exclude: [String]
    ) -> TonightMenuWireRequest {
        TonightMenuWireRequest(
            ingredients: ingredients.map {
                TonightMenuWireIngredient(
                    id: $0.id.uuidString,
                    generalName: $0.generalName,
                    specificName: $0.specificName,
                    quantity: $0.quantity,
                    amount: $0.amount,
                    unit: $0.unit,
                    pinned: $0.pinned
                )
            },
            prompt: constraints.prompt,
            strictness: constraints.strictness,
            count: count,
            moods: constraints.moods,
            dietaryExclusions: constraints.dietaryExclusions,
            confirmedStaples: constraints.confirmedStaples,
            pinnedIngredients: constraints.pinnedIngredients,
            maxTimeMinutes: constraints.maxTimeMinutes,
            servings: constraints.servings,
            equipment: constraints.equipment,
            excludeSignatures: exclude,
            sessionId: sessionId
        )
    }

    static func todayMealPlanKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
