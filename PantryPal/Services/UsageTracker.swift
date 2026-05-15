//
//  UsageTracker.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
import Combine

/// Tracks usage for analytics. Gating for recipe generation (pantry / cookbook / web) is handled by
/// `GenerationCreditsManager`. Ingredient scanning and recipe image generation are free for all users.
/// Recipe modification requires an active Pro subscription.
class UsageTracker: ObservableObject {
    static let shared = UsageTracker()
    
    // MARK: - Free Tier Limits (legacy analytics buckets; generation caps use AppConfig + GenerationCreditsManager)
    
    struct FreeTierLimits {
        static let maxScans = 5
        static let maxRecipeGenerations = 5
        static let maxImageGenerations = 10
        static let maxModifications = 10
    }
    
    // MARK: - Daily Usage
    
    struct DailyUsage: Codable {
        var scans: Int = 0
        var recipeGenerations: Int = 0
        var imageGenerations: Int = 0
        var modifications: Int = 0
        
        var totalInteractions: Int {
            scans + recipeGenerations + imageGenerations + modifications
        }
    }
    
    @Published private(set) var currentUsage: DailyUsage
    /// When true, present upgrade paywall (e.g. Pro-only recipe modification or nutritional information).
    @Published var shouldShowPaywall: Bool = false
    
    private var hasShownPaywallForCurrentState: Bool = false
    
    // MARK: - Limit Toggle
    
    var limitsEnabled: Bool {
        AppConfig.usageLimitsEnabled
    }
    
    private let userDefaults = UserDefaults.standard
    private let usageKey = "Reciplease.DailyUsage"
    
    // MARK: - Initialization
    
    private init() {
        if let data = userDefaults.data(forKey: usageKey),
           let savedUsage = try? JSONDecoder().decode(DailyUsage.self, from: data) {
            currentUsage = savedUsage
            print("📊 UsageTracker - Loaded saved usage: \(savedUsage.totalInteractions) total interactions")
        } else {
            currentUsage = DailyUsage()
            saveUsage()
            print("📊 UsageTracker - First launch, initialized with zero usage")
        }
    }
    
    // MARK: - Usage Tracking
    
    private func saveUsage() {
        if let data = try? JSONEncoder().encode(currentUsage) {
            userDefaults.set(data, forKey: usageKey)
        }
    }
    
    func recordScan() {
        currentUsage.scans += 1
        saveUsage()
        print("📊 Recorded scan. Total: \(currentUsage.scans)")
    }
    
    func recordRecipeGeneration() {
        currentUsage.recipeGenerations += 1
        saveUsage()
        print("📊 Recorded recipe generation. Total: \(currentUsage.recipeGenerations)")
    }

    /// Batch recipe outputs (e.g. meal plan) — each recipe counts toward the same `recipeGenerations` bucket as `recordRecipeGeneration()`.
    func recordRecipeGenerations(_ count: Int) {
        guard count > 0 else { return }
        currentUsage.recipeGenerations += count
        saveUsage()
        print("📊 Recorded \(count) recipe generation(s). Total: \(currentUsage.recipeGenerations)")
    }
    
    func recordImageGeneration() {
        currentUsage.imageGenerations += 1
        saveUsage()
        print("📊 Recorded image generation. Total: \(currentUsage.imageGenerations)")
    }
    
    func recordModification() {
        currentUsage.modifications += 1
        saveUsage()
        print("📊 Recorded modification. Total: \(currentUsage.modifications)")
    }
    
    func onPaywallDismissed() {
        shouldShowPaywall = false
        hasShownPaywallForCurrentState = false
    }
    
    // MARK: - Limit Checks
    
    /// Ingredient photo scanning — free for all users.
    func canScan() -> Bool {
        true
    }
    
    /// Recipe image generation — free for all users.
    func canGenerateImage() -> Bool {
        true
    }
    
    /// Recipe modification — Pro only.
    func canModifyRecipe() -> Bool {
        RevenueCatService.shared.isProMember
    }
}
