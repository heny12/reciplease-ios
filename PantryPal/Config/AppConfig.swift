//
//  AppConfig.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation

struct AppConfig {
    // Read from Info.plist (injected via Build Settings INFOPLIST_KEY_*)
    static var revenueCatAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String, !key.isEmpty else {
            fatalError("REVENUECAT_API_KEY not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_REVENUECAT_API_KEY.")
        }
        return key
    }
    
    static var recipeAPIBaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "RECIPE_API_BASE_URL") as? String, !url.isEmpty else {
            fatalError("RECIPE_API_BASE_URL not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_RECIPE_API_BASE_URL.")
        }
        return url
    }
    
    static var recipleaseAPIBaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "RECIPLEASE_API_BASE_URL") as? String, !url.isEmpty else {
            fatalError("RECIPLEASE_API_BASE_URL not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_RECIPLEASE_API_BASE_URL.")
        }
        return url
    }
    
    // MARK: - Validation Limits (matching backend)
    static let maxIngredients = 100
    static let maxIngredientNameLength = 100
    static let maxGeneratePromptLength = 200
    static let maxModifyPromptLength = 200
    static let maxCookbooks = 3
    static let maxCookbookNameLength = 50
    /// Generate Meal Plan sheet: how many empty meal slots (checkboxes) can be selected.
    static let maxMealPlanGenerateSlotsFree = 3
    static let maxMealPlanGenerateSlotsPro = 10

    // MARK: - Photo Scanning Limits
    static var maxScanPhotos: Int {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_SCAN_PHOTOS") as? String,
              let intValue = Int(value) else {
            fatalError("MAX_SCAN_PHOTOS not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_MAX_SCAN_PHOTOS.")
        }
        return intValue
    }
    
    // MARK: - Trial Limits
    static var trialMaxInteractions: Int {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TRIAL_MAX_INTERACTIONS") as? String,
              let intValue = Int(value) else {
            fatalError("TRIAL_MAX_INTERACTIONS not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_TRIAL_MAX_INTERACTIONS.")
        }
        return intValue
    }
    
    /// Pro tier cap for pantry generate / cookbook scan / web scan per subscription period (from plist PRO_MAX_INTERACTIONS).
    static var proMaxInteractions: Int {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PRO_MAX_INTERACTIONS") as? String,
              let intValue = Int(value) else {
            fatalError("PRO_MAX_INTERACTIONS not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_PRO_MAX_INTERACTIONS.")
        }
        return intValue
    }
    
    // MARK: - Usage Limits
    static var usageLimitsEnabled: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "USAGE_LIMITS_ENABLED") as? String else {
            fatalError("USAGE_LIMITS_ENABLED not found in Info.plist. Please configure it in Build Settings using INFOPLIST_KEY_USAGE_LIMITS_ENABLED.")
        }
        return value.lowercased() == "true"
    }
    
    /// When true (and only in DEBUG), clears persisted generation-credit state on launch for testing. Set RESET_TRIAL in your env plist. Ignored in release.
    static var resetTrialInDebug: Bool {
        #if DEBUG
        if let value = Bundle.main.object(forInfoDictionaryKey: "RESET_TRIAL") as? Bool {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "RESET_TRIAL") as? NSNumber {
            return value.boolValue
        }
        return false
        #else
        return false
        #endif
    }

    /// When true (and only in DEBUG), app will clear the stored review-request state
    /// so the in-app rating prompt can be tested again. Ignored in release.
    static var resetRatingRequestInDebug: Bool {
        #if DEBUG
        if let value = Bundle.main.object(forInfoDictionaryKey: "RESET_RATING_REQUEST") as? Bool {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "RESET_RATING_REQUEST") as? NSNumber {
            return value.boolValue
        }
        return false
        #else
        return false
        #endif
    }
}
