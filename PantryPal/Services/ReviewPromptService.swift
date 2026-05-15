//
//  ReviewPromptService.swift
//  Reciplease
//
//  Created by Cursor on 3/6/26.
//

import Foundation
import Combine

@MainActor
final class ReviewPromptService: ObservableObject {
    static let shared = ReviewPromptService()

    @Published private(set) var shouldRequestReview = false

    private let userDefaults = UserDefaults.standard
    private let favoriteActionCountKey = "Reciplease.ReviewPrompt.FavoriteActionCount"
    private let hasRequestedReviewKey = "Reciplease.ReviewPrompt.HasRequestedReview"
    private let favoriteActionThreshold = 2

    private init() {
        #if DEBUG
        if AppConfig.resetRatingRequestInDebug {
            userDefaults.removeObject(forKey: favoriteActionCountKey)
            userDefaults.removeObject(forKey: hasRequestedReviewKey)
            shouldRequestReview = false
            print("🔧 ReviewPromptService - RESET_RATING_REQUEST: cleared stored review prompt state for testing")
        }
        #endif
    }

    func registerFavoriteAction() {
        guard !hasRequestedReview else { return }

        let updatedCount = favoriteActionCount + 1
        userDefaults.set(updatedCount, forKey: favoriteActionCountKey)

        if updatedCount >= favoriteActionThreshold {
            userDefaults.set(true, forKey: hasRequestedReviewKey)
            shouldRequestReview = true
        }
    }

    func consumeReviewRequest() {
        shouldRequestReview = false
    }

    private var favoriteActionCount: Int {
        userDefaults.integer(forKey: favoriteActionCountKey)
    }

    private var hasRequestedReview: Bool {
        userDefaults.bool(forKey: hasRequestedReviewKey)
    }
}
