//
//  GenerationCreditsManager.swift
//  PantryPal
//
//  Weekly allowance for free users (TRIAL_MAX_INTERACTIONS per rolling week from anchor).
//  Pro users: PRO_MAX_INTERACTIONS per RevenueCat subscription period (keyed by entitlement expiration).
//

import Foundation
import Combine
import RevenueCat

@MainActor
final class GenerationCreditsManager: ObservableObject {
    static let shared = GenerationCreditsManager()

    /// Present the quota / upgrade sheet (header coin tap or blocked generation).
    @Published var showGenerationLimitSheet = false

    @Published private(set) var remainingCredits: Int = 0
    @Published private(set) var maxCreditsForCurrentTier: Int = 0
    @Published private(set) var isProSubscriber: Bool = false

    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current

    /// Anchor for rolling 7-day windows (start of local day).
    private let anchorDateKey = "Reciplease.GenerationAnchorDate"
    private let freeWeekIndexKey = "Reciplease.FreeGenerationWeekIndex"
    private let freeUsedKey = "Reciplease.FreeGenerationUsed"
    private let proPeriodKeyKey = "Reciplease.ProGenerationPeriodKey"
    private let proUsedKey = "Reciplease.ProGenerationUsed"

    /// Legacy trial start — reused as anchor when present (migration).
    private let legacyTrialStartKey = "Reciplease.TrialStartDate"

    private init() {
        #if DEBUG
        if AppConfig.resetTrialInDebug {
            userDefaults.removeObject(forKey: anchorDateKey)
            userDefaults.removeObject(forKey: freeWeekIndexKey)
            userDefaults.removeObject(forKey: freeUsedKey)
            userDefaults.removeObject(forKey: proPeriodKeyKey)
            userDefaults.removeObject(forKey: proUsedKey)
            userDefaults.removeObject(forKey: legacyTrialStartKey)
            print("🔧 GenerationCreditsManager - RESET_TRIAL: cleared generation credit keys for testing")
        }
        #endif
        syncProFlagFromRevenueCat()
        refreshPeriodsAndUsage()
    }

    // MARK: - Public API

    func refreshPeriodsAndUsage(customerInfo: CustomerInfo? = nil) {
        syncProFlagFromRevenueCat()
        let info = customerInfo ?? RevenueCatService.shared.customerInfo
        ensureAnchorDateExists()

        if isProSubscriber {
            reconcileProPeriod(using: info)
        } else {
            reconcileFreeWeek()
        }

        recomputePublishedRemaining()
    }

    /// Whether the user may start a generation action (pantry / cookbook scan / web scan).
    func canConsumeGenerationCredit() -> Bool {
        refreshPeriodsAndUsage()
        if isProSubscriber {
            let used = userDefaults.integer(forKey: proUsedKey)
            return used < AppConfig.proMaxInteractions
        }
        let used = userDefaults.integer(forKey: freeUsedKey)
        return used < AppConfig.trialMaxInteractions
    }

    /// Call after a successful API generation (one recipe batch still counts as one credit).
    func consumeGenerationCredit() {
        if isProSubscriber {
            let used = userDefaults.integer(forKey: proUsedKey)
            userDefaults.set(used + 1, forKey: proUsedKey)
        } else {
            let used = userDefaults.integer(forKey: freeUsedKey)
            userDefaults.set(used + 1, forKey: freeUsedKey)
        }
        recomputePublishedRemaining()
        AppAnalytics.log(.generationCreditConsumed, parameters: analyticsParams())
    }

    /// Consumes up to `maxCount` credits, but never more than current `remainingCredits`
    /// (e.g. 1 remaining credit covers a 3-recipe meal plan; balance goes to 0).
    func consumeGenerationCredits(upTo maxCount: Int) {
        guard maxCount > 0 else { return }
        refreshPeriodsAndUsage()
        let n = min(maxCount, remainingCredits)
        for _ in 0..<n {
            consumeGenerationCredit()
        }
    }

    func presentGenerationLimitSheet() {
        showGenerationLimitSheet = true
        AppAnalytics.log(.generationLimitSheetShown, parameters: analyticsParams())
    }

    func dismissGenerationLimitSheet() {
        showGenerationLimitSheet = false
    }

    // MARK: - Period logic

    private func syncProFlagFromRevenueCat() {
        isProSubscriber = RevenueCatService.shared.isProMember
    }

    private func ensureAnchorDateExists() {
        if userDefaults.object(forKey: anchorDateKey) as? Date != nil {
            return
        }
        if let legacy = userDefaults.object(forKey: legacyTrialStartKey) as? Date {
            userDefaults.set(legacy, forKey: anchorDateKey)
            return
        }
        let start = calendar.startOfDay(for: Date())
        userDefaults.set(start, forKey: anchorDateKey)
    }

    private func anchorStartOfDay() -> Date {
        if let d = userDefaults.object(forKey: anchorDateKey) as? Date {
            return calendar.startOfDay(for: d)
        }
        let start = calendar.startOfDay(for: Date())
        userDefaults.set(start, forKey: anchorDateKey)
        return start
    }

    private func reconcileFreeWeek() {
        let anchor = anchorStartOfDay()
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: anchor, to: today).day ?? 0
        let weekIndex = max(0, days / 7)
        let savedIndex = userDefaults.integer(forKey: freeWeekIndexKey)

        if weekIndex != savedIndex {
            userDefaults.set(weekIndex, forKey: freeWeekIndexKey)
            userDefaults.set(0, forKey: freeUsedKey)
            AppAnalytics.log(.generationPeriodReset, parameters: [
                "tier": "free",
                "week_index": weekIndex
            ])
        }
    }

    private func reconcileProPeriod(using customerInfo: CustomerInfo?) {
        guard let info = customerInfo,
              let entitlement = info.entitlements["Reciplease Pro"],
              entitlement.isActive,
              let expiration = entitlement.expirationDate else {
            return
        }

        let key = String(expiration.timeIntervalSince1970)
        let savedKey = userDefaults.string(forKey: proPeriodKeyKey) ?? ""

        if key != savedKey {
            userDefaults.set(key, forKey: proPeriodKeyKey)
            userDefaults.set(0, forKey: proUsedKey)
            AppAnalytics.log(.generationPeriodReset, parameters: [
                "tier": "pro",
                "period_key": key
            ])
        }
    }

    private func recomputePublishedRemaining() {
        maxCreditsForCurrentTier = isProSubscriber ? AppConfig.proMaxInteractions : AppConfig.trialMaxInteractions
        if isProSubscriber {
            let used = userDefaults.integer(forKey: proUsedKey)
            remainingCredits = max(0, AppConfig.proMaxInteractions - used)
        } else {
            let used = userDefaults.integer(forKey: freeUsedKey)
            remainingCredits = max(0, AppConfig.trialMaxInteractions - used)
        }
    }

    private func analyticsParams() -> [String: Any] {
        [
            "tier": isProSubscriber ? "pro" : "free",
            "remaining": remainingCredits,
            "max": maxCreditsForCurrentTier
        ]
    }
}
