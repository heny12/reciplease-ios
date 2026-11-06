//
//  RecipeLogicTests.swift
//  PantryPalTests
//

import XCTest
@testable import PantryPal

final class RecipeLogicTests: XCTestCase {
    @MainActor
    func testMixedNumberDoublesToThreeCups() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            quantity: "1 1/2 cups",
            recipeServings: 2,
            currentServings: 4
        )
        XCTAssertEqual(scaled.text, "3 cups")
        XCTAssertNil(scaled.scaleFactorToShow)
    }

    @MainActor
    func testUnicodeVulgarFractionDoubles() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            quantity: "1½ cups",
            recipeServings: 1,
            currentServings: 2
        )
        XCTAssertEqual(scaled.text, "3 cups")
    }

    @MainActor
    func testSimpleFractionDoublesToWhole() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            quantity: "1/2 cup",
            recipeServings: 1,
            currentServings: 2
        )
        XCTAssertEqual(scaled.text, "1 cup")
    }

    @MainActor
    func testRangeScalesBothEnds() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            quantity: "1-2 tbsp",
            recipeServings: 2,
            currentServings: 4
        )
        XCTAssertEqual(scaled.text, "2-4 tbsp")
    }

    @MainActor
    func testStructuredAmountPreferredOverLegacyString() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            amount: 1.5,
            unit: "cups",
            quantity: "1 1/2 cups",
            recipeServings: 2,
            currentServings: 4
        )
        XCTAssertEqual(scaled.text, "3 cups")
    }

    @MainActor
    func testToTasteIsNotScaled() async {
        let scaled = RecipeQuantityScaling.scaledDisplay(
            quantity: "to taste",
            recipeServings: 2,
            currentServings: 6
        )
        XCTAssertEqual(scaled.text, "to taste")
    }

    @MainActor
    func testLegacyAndV2RecipeJSONDecode() async throws {
        let legacy = """
        {"id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","name":"Soup","description":"Warm","ingredients":[{"name":"noodle","quantity":"1 cup"}],"steps":["Boil"]}
        """.data(using: .utf8)!
        let legacyRecipe = try JSONDecoder().decode(Recipe.self, from: legacy)
        XCTAssertEqual(legacyRecipe.name, "Soup")
        XCTAssertEqual(legacyRecipe.ingredients.first?.name, "noodle")
        XCTAssertEqual(legacyRecipe.cookedCount, 0)

        let modern = """
        {
          "id": "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
          "name": "Sticky Garlic-Lime Skillet Chicken",
          "description": "Crispy pan-seared chicken thighs.",
          "hook": "Crispy thighs with a sticky pan sauce.",
          "lane": "quick_skillet",
          "extraIngredients": ["lime"],
          "ingredients": [{
            "id": "ing_chicken",
            "generalName": "chicken thighs",
            "quantity": "1.5 lbs",
            "amount": 1.5,
            "unit": "lbs",
            "category": "pantry"
          }],
          "steps": ["Sear the chicken."],
          "structuredSteps": [{
            "stepNumber": 2,
            "text": "Sear for 6 minutes per side.",
            "ingredientUses": [],
            "timerSeconds": 360,
            "heat": "medium-high",
            "donenessCue": "165°F"
          }],
          "prepTimeMinutes": 10,
          "cookTimeMinutes": 15,
          "servings": 4,
          "difficulty": 2,
          "changeSummary": "Added lime.",
          "visualIdentityChanged": true
        }
        """.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(Recipe.self, from: modern)
        XCTAssertEqual(recipe.hook, "Crispy thighs with a sticky pan sauce.")
        XCTAssertEqual(recipe.lane, "quick_skillet")
        XCTAssertEqual(recipe.ingredients.first?.name, "chicken thighs")
        XCTAssertEqual(recipe.ingredients.first?.amount, 1.5)
        XCTAssertEqual(recipe.structuredSteps?.first?.timerSeconds, 360)
        XCTAssertEqual(recipe.extraIngredients, ["lime"])
        XCTAssertEqual(recipe.visualIdentityChanged, true)
        XCTAssertEqual(recipe.changeSummary, "Added lime.")
        XCTAssertEqual(recipe.id, UUID(uuidString: "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
    }

    @MainActor
    func testPitchDeckDecodes() async throws {
        let data = """
        {
          "sessionId": "sess_uuid",
          "status": "ok",
          "reasonCodes": [],
          "pitches": [{
            "pitchId": "pitch_uuid",
            "lane": "quick_skillet",
            "title": "Sticky Garlic-Lime Skillet Chicken",
            "hook": "Crispy pan-seared thighs glazed in a bright garlic-lime pan sauce.",
            "totalTimeMinutes": 25,
            "difficulty": 2,
            "servings": 4,
            "pantryIngredientsUsed": ["chicken thighs", "garlic", "spinach"],
            "staplesUsed": ["Salt", "Olive Oil"],
            "extraIngredients": ["lime"]
          }]
        }
        """.data(using: .utf8)!
        let deck = try JSONDecoder().decode(PitchDeckResponse.self, from: data)
        XCTAssertEqual(deck.sessionId, "sess_uuid")
        XCTAssertEqual(deck.pitches.count, 1)
        XCTAssertEqual(deck.pitches[0].laneTitle, "Quick Skillet")
        XCTAssertEqual(deck.pitches[0].matchPill(), "Uses 3 pantry items · +1 extra: lime")
    }

    @MainActor
    func testUncategorizedMovesIntoEarlierIdeasWithoutDeleting() async {
        let recipeA = UUID()
        let recipeB = UUID()
        let uncategorized = CookbookSnapshot(
            id: UUID(),
            name: "Uncategorized",
            recipeIds: [recipeA, recipeB],
            createdAt: Date(timeIntervalSince1970: 10),
            isDefaultFavorites: false,
            isDefaultUncategorized: true
        )
        let favorites = CookbookSnapshot(
            id: UUID(),
            name: "Favorites",
            recipeIds: [],
            createdAt: Date(timeIntervalSince1970: 20),
            isDefaultFavorites: true,
            isDefaultUncategorized: false
        )
        let first = EarlierIdeasMigration.migrate([uncategorized, favorites])
        XCTAssertTrue(first.changed)
        let inbox = try? XCTUnwrap(first.cookbooks.first { $0.isInbox })
        XCTAssertEqual(inbox?.name, "Earlier Ideas")
        XCTAssertEqual(inbox?.recipeIds, [recipeA, recipeB])
        XCTAssertEqual(first.cookbooks.first { $0.isDefaultUncategorized }?.recipeIds, [])
        let second = EarlierIdeasMigration.migrate(first.cookbooks)
        XCTAssertFalse(second.changed)
        XCTAssertEqual(second.cookbooks.first { $0.isInbox }?.recipeIds, [recipeA, recipeB])
    }

    @MainActor
    func testPantryMatchCountsNameOverlapAndStaples() async {
        let result = PantryMatchCalculator.breakdown(
            ingredientNames: ["chicken thighs", "lime", "salt"],
            pantryNames: ["chicken", "spinach"]
        )
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.matched, 2)
        XCTAssertEqual(result.score, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertTrue(PantryMatchCalculator.isStaple("olive oil"))
        XCTAssertFalse(PantryMatchCalculator.isInPantry("lime", pantryNames: ["chicken"]))
    }

    @MainActor
    func testLibrarySearchIncludesIngredientNames() async {
        let recipe = Recipe(
            name: "Skillet",
            description: "Golden",
            ingredients: [RecipeIngredient(name: "spinach", quantity: "2 cups")],
            steps: ["Cook"],
            prepTimeMinutes: 10,
            cookTimeMinutes: 15
        )
        XCTAssertTrue(RecipeLibraryQuery.matchesSearch(recipe, query: "spin"))
        XCTAssertFalse(RecipeLibraryQuery.matchesSearch(recipe, query: "lasagna"))
        XCTAssertTrue(RecipeLibraryQuery.matches(recipe: recipe, smart: .under30, pantryScore: 0))
    }

    @MainActor
    func testQuotaEnvelopeAndCreditPolicy() async throws {
        let data = """
        {"error":"QUOTA_EXCEEDED","code":"QUOTA_EXCEEDED","message":"Weekly free recipe limit reached.","remaining":0,"limit":5,"resetAtMs":1762900000000}
        """.data(using: .utf8)!
        let quota = try XCTUnwrap(QuotaEnvelopeParser.parse(data: data))
        XCTAssertEqual(quota.remaining, 0)
        XCTAssertEqual(quota.limit, 5)
        XCTAssertEqual(quota.resetAtMs, 1_762_900_000_000)
        let copy = AllowanceCopy.detail(
            AllowanceSnapshot(remaining: 0, limit: 5, isPro: false, resetAtMs: quota.resetAtMs, serverMessage: quota.message),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(copy.contains("Weekly free recipe limit reached."))
        XCTAssertTrue(copy.contains("Resets"))
        XCTAssertEqual(AllowanceCopy.sheetTitle(isPro: false), "Weekly Free Allowance")
        XCTAssertEqual(AllowanceCopy.settingsLabel(isPro: false), "Recipe generations this week")
        XCTAssertFalse(GenerationCreditPolicy.shouldConsumeCredit(httpStatus: 404))
        XCTAssertFalse(GenerationCreditPolicy.shouldConsumeCredit(httpStatus: 429))
        XCTAssertTrue(GenerationCreditPolicy.shouldConsumeCredit(httpStatus: 200))
    }

    @MainActor
    func testVeganAndGlutenFreeStaplesAreRemoved() async {
        let filtered = KitchenStaples.filtered(
            ["Salt", "Butter", "Honey", "Flour", "Olive Oil"],
            dietaryExclusions: ["vegan", "gluten-free"]
        )
        XCTAssertEqual(filtered, ["Salt", "Olive Oil"])
    }

    @MainActor
    func testPromptKeepsDietsOutOfFreeText() async {
        let prompt = TonightMenuRequestBuilder.composedPrompt(
            mealTypes: ["Dinner"],
            cuisine: "Thai",
            custom: "Surprise me"
        )
        XCTAssertEqual(prompt, "Meal type: Dinner. Cuisine: Thai. Surprise me")
        XCTAssertFalse(prompt?.localizedCaseInsensitiveContains("vegan") ?? true)
        let exclusions = DietaryConstraint.wireExclusions(from: ["Vegan", "Gluten Free", "Vegan"])
        XCTAssertEqual(exclusions, ["vegan", "gluten-free"])
    }

    @MainActor
    func testShareLinksAndServerIdentity() async {
        let id = UUID(uuidString: "CCCCCCCC-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let universal = URL(string: "https://reciplease.info/recipes/shared/\(id.uuidString.lowercased())")!
        let custom = URL(string: "reciplease://recipe/\(id.uuidString)")!
        XCTAssertEqual(RecipeShareLink.recipeID(from: universal)?.lowercased(), id.uuidString.lowercased())
        XCTAssertEqual(RecipeShareLink.recipeID(from: custom)?.lowercased(), id.uuidString.lowercased())
        XCTAssertNil(RecipeShareLink.recipeID(from: URL(string: "https://example.com/recipes/shared/\(id.uuidString)")!))

        let local = Recipe(id: UUID(), name: "Soup", description: "Warm", ingredients: [], steps: ["Boil"])
        let server = Recipe(id: id, name: "Soup", description: "Warm", ingredients: [], steps: ["Simmer"])
        let merged = RecipeIdentityMerge.merge(recipes: [local], favoritedRecipes: [], fetched: server)
        XCTAssertEqual(merged.openedId, id)
        XCTAssertEqual(merged.remappedFrom, local.id)
        XCTAssertEqual(merged.recipes.first?.id, id)
        XCTAssertEqual(merged.recipes.first?.steps, ["Simmer"])
    }

    @MainActor
    func testModificationKeepsUndoAndDropsPhotoWhenTheDishChanges() async {
        let original = Recipe(
            name: "Alfredo",
            description: "Creamy",
            ingredients: [RecipeIngredient(name: "cream", quantity: "1 cup")],
            steps: ["Simmer"],
            imageURL: "https://example.com/alfredo.jpg",
            tags: ["Favorites"],
            cookedCount: 2
        )
        var server = original
        server = Recipe(
            id: UUID(),
            name: "Marinara",
            description: "Bright",
            ingredients: [RecipeIngredient(name: "tomato", quantity: "2 cups")],
            steps: ["Simmer the tomatoes."],
            imageURL: "https://example.com/alfredo.jpg",
            changeSummary: "Swapped the sauce.",
            visualIdentityChanged: true
        )
        let merged = RecipeModificationMerge.applying(server: server, onto: original)
        XCTAssertEqual(merged.id, original.id)
        XCTAssertEqual(merged.name, "Marinara")
        XCTAssertNil(merged.imageURL)
        XCTAssertEqual(merged.changeSummary, "Swapped the sauce.")
        XCTAssertEqual(merged.cookedCount, 2)
        XCTAssertEqual(merged.tags, ["Favorites"])
        XCTAssertEqual(merged.undoSnapshot?.name, "Alfredo")
        XCTAssertEqual(merged.restoringUndo()?.name, "Alfredo")
        XCTAssertEqual(merged.restoringUndo()?.imageURL, "https://example.com/alfredo.jpg")
    }

    @MainActor
    func testStepTimerReadsMinutesFromPlainText() async {
        XCTAssertEqual(StepTimerDetector.detect(in: "Simmer for 8 minutes"), 480)
        XCTAssertEqual(CookTimer.seconds(timerSeconds: 360, stepText: "Simmer for 8 minutes"), 360)
        XCTAssertEqual(StepTimerDetector.detect(in: "Bake 1 hour 15 minutes"), 4500)
    }

    @MainActor
    func testSummaryLabelUsesTonightAndPinnedNames() async {
        let label = TonightMenuRequestBuilder.summaryLabel(
            ingredientNames: ["Chicken", "Spinach"],
            count: 6,
            now: Date(),
            calendar: .current
        )
        XCTAssertEqual(label, "Tonight · Chicken + Spinach (6)")
    }
}
