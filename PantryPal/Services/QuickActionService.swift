//
//  QuickActionService.swift
//  Reciplease
//
//  Created by Cursor on 3/17/26.
//

import Foundation
import Combine

@MainActor
final class QuickActionService: ObservableObject {
    static let shared = QuickActionService()

    enum Action: String {
        case scanIngredients = "com.reciplease.scan"
        /// Home-screen shortcut type remains `com.reciplease.generate` for compatibility.
        case generateMealPlan = "com.reciplease.generate"
        case scanCookbookRecipe = "com.reciplease.cookbook"
        case leaveFeedback = "com.reciplease.feedback"
    }

    @Published private(set) var pendingAction: Action?

    private init() {}

    func queue(actionType: String) {
        guard let action = Action(rawValue: actionType) else { return }
        pendingAction = action
    }

    func consumePendingAction() {
        pendingAction = nil
    }
}
