// swift-tools-version: 6.0
// Logic and service package so `swift build` / `swift test` typecheck with swiftc.
// Open PantryPal.xcodeproj for the iOS app. This package does not build SwiftUI screens.
// Language mode matches the Xcode target's SWIFT_VERSION = 5.0, plus the same
// member-import-visibility upcoming feature.

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
            exclude: [
                "Assets",
                "Assets.xcassets",
                "Docs",
                "ViewModels",
                "Views",
                "icon.icon",
                "ContentView.swift",
                "PantryPalApp.swift",
                "Helpers/EntitlementHelper.swift",
                "Config/ColorScheme.swift",
                "Config/ProMarketingCopy.swift",
                "Helpers/BundleImage.swift",
                "Helpers/DesignTokens.swift",
                "Helpers/GIFView.swift",
                "Helpers/HapticFeedback.swift",
                "Helpers/LayoutHelpers.swift",
                "Helpers/LoadingMessages.swift",
                "Helpers/LoopingVideoPlayer.swift",
                "Helpers/MainTabNavigationChrome.swift",
                "Helpers/PantryIngredientListChrome.swift",
                "Helpers/PantryQuickActionSheetSupport.swift",
                "Helpers/StandardButtons.swift",
                "Helpers/StandardCard.swift",
                "Helpers/UIImage+Resize.swift",
                "Services/AppAnalytics.swift",
                "Services/GCSUploadService.swift",
                "Services/GenerationCreditsManager.swift",
                "Services/ImageCacheService.swift",
                "Services/ImagePreloadService.swift",
                "Services/LocalNotificationManager.swift",
                "Services/QuickActionService.swift",
                "Services/ReviewPromptService.swift",
                "Services/TipOfDayService.swift",
                "Services/MealPlanCalendarService.swift",
                "Services/RevenueCatService.swift",
                "Services/UsageTracker.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "PantryPalLogicTests",
            dependencies: ["PantryPal"],
            path: "PantryPalTests",
            exclude: ["PantryPalTests.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        )
    ]
)
