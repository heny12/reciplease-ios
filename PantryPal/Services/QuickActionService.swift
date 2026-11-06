//
//  QuickActionService.swift
//  Reciplease
//
//  Created by Cursor on 3/17/26.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

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

    func registerHomeScreenShortcuts() {
        #if os(iOS)
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: Action.scanIngredients.rawValue,
                localizedTitle: "Scan Pantry",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "camera.viewfinder"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: Action.generateMealPlan.rawValue,
                localizedTitle: "Generate Meal Plan",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "wand.and.stars"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: Action.scanCookbookRecipe.rawValue,
                localizedTitle: "Scan a Recipe",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "text.viewfinder"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: Action.leaveFeedback.rawValue,
                localizedTitle: "Leave Feedback",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "envelope"),
                userInfo: nil
            )
        ]
        #endif
    }

    func queue(actionType: String) {
        guard let action = Action(rawValue: actionType) else { return }
        pendingAction = action
    }

    func consumePendingAction() {
        pendingAction = nil
    }
}
