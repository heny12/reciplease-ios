//
//  AppAnalytics.swift
//  PantryPal
//
//  Central Firebase Analytics event names + helpers. Custom events stay within GA4 limits
//  (snake_case names, ≤40 chars). For QA on device: add launch arg `-FIRAnalyticsDebugEnabled`
//  (and optionally `-FIRDebugEnabled`) in the Run scheme; Release still respects `#if DEBUG`
//  collection off in PantryPalApp.
//

import FirebaseAnalytics
import Foundation

enum AppAnalytics {
    // MARK: - Collection

    static func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    // MARK: - User properties (segmentation; update sparingly)

    static func setSubscriberTier(isPro: Bool) {
        Analytics.setUserProperty(isPro ? "pro" : "free", forName: "subscriber_tier")
    }

    // MARK: - Events (North Star + product funnel)

    enum Event: String {
        case appLaunched = "app_launched"
        case onboardingCompleted = "onboarding_completed"
        case onboardingPageViewed = "onboarding_page_viewed"
        case ingredientsScanned = "ingredients_scanned"
        case ingredientManuallyAdded = "ingredient_manually_added"
        case cookbookRecipesScanned = "cookbook_recipes_scanned"
        case webRecipesScanned = "web_recipes_scanned"
        case recipesGenerated = "recipes_generated"
        case mealPlanGenerated = "meal_plan_generated"
        case recipeViewed = "recipe_viewed"
        case recipeBookmarked = "recipe_bookmarked"
        case recipeUnbookmarked = "recipe_unbookmarked"
        case recipeDeleted = "recipe_deleted"
        case recipeModified = "recipe_modified"
        case cookbookDeleted = "cookbook_deleted"
        case paywallTriggered = "paywall_triggered"
        case paywallViewed = "paywall_viewed"
        case subscribeTapped = "subscribe_tapped"
        case purchaseSuccess = "purchase_success"
        case purchaseError = "purchase_error"
        case purchaseCancelled = "purchase_cancelled"
        case feedbackSubmitted = "feedback_submitted"
        case bugReported = "bug_reported"
        case featureSuggested = "feature_suggested"
        case generationCreditConsumed = "generation_credit_consumed"
        case generationLimitSheetShown = "generation_limit_sheet_shown"
        case generationPeriodReset = "generation_period_reset"
        case actionsSheetOpened = "actions_sheet_opened"
        case groceryListShared = "grocery_list_shared"
        case firstRecipeGenerated = "first_recipe_generated"
        case pitchSelected = "pitch_selected"
        case pitchExpanded = "pitch_expanded"
        case cookingStarted = "cooking_started"
        case cookingCompleted = "cooking_completed"
        case notificationOpened = "notification_opened"
    }

    static func log(_ event: Event, parameters: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    /// Escape hatch for events with fully dynamic parameters.
    static func log(rawEventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(rawEventName, parameters: parameters)
    }

    static func logActionsSheetOpened(source: String) {
        log(.actionsSheetOpened, parameters: ["source": source])
    }

    static func logGroceryListShared() {
        log(.groceryListShared, parameters: nil)
    }
}
