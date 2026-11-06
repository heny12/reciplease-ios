// swift-tools-version: 5.9
// Logic-only package so `swift test` can run on Linux without Xcode.
// Open PantryPal.xcodeproj for the iOS app. This package does not build the UI.

import PackageDescription

let package = Package(
    name: "RecipleaseLogic",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PantryPal", targets: ["PantryPal"])
    ],
    targets: [
        .target(
            name: "PantryPal",
            path: "PantryPal",
            sources: [
                "Domain/StableIdentifier.swift",
                "Domain/FlexibleDecoding.swift",
                "Domain/StructuredCooking.swift",
                "Domain/KitchenStaples.swift",
                "Domain/RecipePitch.swift",
                "Domain/PantryMatchCalculator.swift",
                "Domain/EarlierIdeasMigration.swift",
                "Domain/QuotaAndCredits.swift",
                "Domain/RecipeLibraryQuery.swift",
                "Domain/RecipeShareLink.swift",
                "Domain/TonightMenuRequest.swift",
                "Helpers/RecipeQuantityScaling.swift",
                "Models/Ingredient.swift",
                "Models/RecipeIngredient.swift",
                "Models/Recipe.swift"
            ]
        ),
        .testTarget(
            name: "PantryPalLogicTests",
            dependencies: ["PantryPal"],
            path: "PantryPalTests",
            sources: ["RecipeLogicTests.swift"]
        )
    ]
)
