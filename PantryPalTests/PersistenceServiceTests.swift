//
//  PersistenceServiceTests.swift
//  PantryPalTests
//

import XCTest
@testable import PantryPal

final class PersistenceServiceTests: XCTestCase {
    /// Async and on the main actor so these tests compile against the app target,
    /// which sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
    @MainActor
    func testLegacyPayloadDecodesMissingSessionsAndInbox() async throws {
        let cookbookID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let recipeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let ingredientID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let json = """
        {
          "imageURLs": [],
          "ingredients": [{"id":"\(ingredientID.uuidString)","generalName":"Eggs","quantity":"12"}],
          "recipes": [],
          "favoritedRecipes": [],
          "favoriteRecipeIds": [],
          "cookbooks": [{
            "id": "\(cookbookID.uuidString)",
            "name": "Uncategorized",
            "recipeIds": ["\(recipeID.uuidString)"],
            "createdAt": 0,
            "isDefaultFavorites": false,
            "isDefaultUncategorized": true
          }],
          "pantryInsights": ["use the eggs"],
          "mealPlanByDay": {},
          "mealPlanCalendarEventIdsByDay": {},
          "groceryItems": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SavedAppData.self, from: json)
        XCTAssertTrue(decoded.generationSessions.isEmpty)
        XCTAssertEqual(decoded.ingredients.first?.generalName, "Eggs")
        XCTAssertEqual(decoded.ingredients.first?.pinned, false)
        XCTAssertEqual(decoded.cookbooks.first?.isInbox, false)
        XCTAssertEqual(decoded.cookbooks.first?.isDefaultUncategorized, true)
        XCTAssertEqual(decoded.cookbooks.first?.recipeIds, [recipeID])
        XCTAssertEqual(decoded.pantryInsights, ["use the eggs"])
        XCTAssertTrue(decoded.groceryItems.isEmpty)
    }

    @MainActor
    func testSavedAppDataRoundTripKeepsGenerationSession() async throws {
        let original = sampleAppData()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedAppData.self, from: data)
        XCTAssertEqual(decoded.generationSessions.count, 1)
        XCTAssertEqual(decoded.generationSessions.first?.sessionId, "sess_roundtrip")
        XCTAssertEqual(decoded.generationSessions.first?.pitches.first?.title, "Skillet Chicken")
        XCTAssertEqual(decoded.generationSessions.first?.expandedRecipes["pitch_1"]?.name, "Skillet Chicken")
        XCTAssertEqual(decoded.recipes.first?.name, "Skillet Chicken")
        XCTAssertEqual(decoded.cookbooks.first?.isInbox, true)
    }

    @MainActor
    func testPersistenceServiceDiskRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reciplease-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = PersistenceService(directory: directory)
        let original = sampleAppData()
        service.save(
            imageURLs: original.imageURLs,
            ingredients: original.ingredients,
            recipes: original.recipes,
            favoritedRecipes: original.favoritedRecipes,
            favoriteRecipeIds: original.favoriteRecipeIds,
            cookbooks: original.cookbooks,
            pantryInsights: original.pantryInsights,
            mealPlanByDay: original.mealPlanByDay,
            mealPlanCalendarEventIdsByDay: original.mealPlanCalendarEventIdsByDay,
            groceryItems: original.groceryItems,
            generationSessions: original.generationSessions
        )

        let loaded = service.load()
        XCTAssertEqual(loaded.ingredients.map(\.generalName), ["Spinach"])
        XCTAssertEqual(loaded.ingredients.first?.pinned, true)
        XCTAssertEqual(loaded.generationSessions.first?.summaryLabel, "Tonight · Spinach (1)")
        XCTAssertEqual(loaded.generationSessions.first?.expandedRecipes["pitch_1"]?.steps, ["Sear"])
        XCTAssertEqual(loaded.cookbooks.first?.name, "Earlier Ideas")

        let encoded = try JSONEncoder().encode(loaded)
        let again = try JSONDecoder().decode(SavedAppData.self, from: encoded)
        XCTAssertEqual(again.generationSessions.first?.sessionId, "sess_roundtrip")
    }

    @MainActor
    private func sampleAppData() -> SavedAppData {
        let recipe = Recipe(
            name: "Skillet Chicken",
            description: "Crispy",
            ingredients: [RecipeIngredient(name: "spinach", quantity: "2 cups")],
            steps: ["Sear"],
            hook: "Crispy and bright",
            lane: "quick_skillet"
        )
        let pitch = RecipePitch(
            pitchId: "pitch_1",
            lane: "quick_skillet",
            title: "Skillet Chicken",
            hook: "Crispy and bright",
            pantryIngredientsUsed: ["spinach"],
            extraIngredients: []
        )
        let session = GenerationSession(
            sessionId: "sess_roundtrip",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            summaryLabel: "Tonight · Spinach (1)",
            constraints: GenerationConstraintSnapshot(
                strictness: "mostly",
                moods: ["cozy"],
                dietaryExclusions: ["vegan"],
                confirmedStaples: ["Salt"],
                pinnedIngredients: ["Spinach"],
                mealTypes: ["Dinner"],
                cuisine: nil,
                servings: 2,
                equipment: ["stovetop"],
                maxTimeMinutes: 30,
                prompt: nil,
                ingredientNames: ["Spinach"]
            ),
            pitches: [pitch],
            expandedRecipes: ["pitch_1": recipe],
            viewedPitchIds: [],
            savedPitchIds: [],
            dismissedPitchIds: [],
            usedV1Fallback: false
        )
        let ingredient = Ingredient(generalName: "Spinach", quantity: "1 bunch", pinned: true)
        let cookbook = SavedCookbook(
            id: UUID(),
            name: "Earlier Ideas",
            recipeIds: [recipe.id],
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            isDefaultFavorites: false,
            isDefaultUncategorized: false,
            isInbox: true
        )
        return SavedAppData(
            ingredients: [ingredient],
            recipes: [recipe],
            cookbooks: [cookbook],
            pantryInsights: ["wilt the spinach"],
            generationSessions: [session]
        )
    }
}
