//
//  LocalNotificationManager.swift
//  Reciplease
//
//  Opt-in local reminders for tomorrow's meals, a weekly planning nudge, and Use Soon items.
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class LocalNotificationManager: ObservableObject {
    static let shared = LocalNotificationManager()

    static let mealReminderKey = "Reciplease.Notifications.MealReminders"
    static let weeklyNudgeKey = "Reciplease.Notifications.WeeklyNudge"
    static let expiryKey = "Reciplease.Notifications.ExpiryReminders"

    @Published var mealRemindersEnabled: Bool
    @Published var weeklyNudgeEnabled: Bool
    @Published var expiryRemindersEnabled: Bool

    private let center = UNUserNotificationCenter.current()

    private init() {
        mealRemindersEnabled = UserDefaults.standard.bool(forKey: Self.mealReminderKey)
        weeklyNudgeEnabled = UserDefaults.standard.bool(forKey: Self.weeklyNudgeKey)
        expiryRemindersEnabled = UserDefaults.standard.bool(forKey: Self.expiryKey)
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    func setMealRemindersEnabled(_ enabled: Bool, viewModel: PantryViewModel) async {
        if enabled {
            guard await requestAuthorizationIfNeeded() else { return }
        }
        mealRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.mealReminderKey)
        rescheduleTomorrowMealReminder(using: viewModel)
    }

    func setWeeklyNudgeEnabled(_ enabled: Bool) async {
        if enabled {
            guard await requestAuthorizationIfNeeded() else { return }
        }
        weeklyNudgeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.weeklyNudgeKey)
        rescheduleWeeklyNudge()
    }

    func setExpiryRemindersEnabled(_ enabled: Bool, ingredients: [Ingredient]) async {
        if enabled {
            guard await requestAuthorizationIfNeeded() else { return }
        }
        expiryRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.expiryKey)
        rescheduleExpiryReminders(ingredients: ingredients)
    }

    func rescheduleTomorrowMealReminder(using viewModel: PantryViewModel) {
        center.removePendingNotificationRequests(withIdentifiers: ["reciplease.meal.tomorrow"])
        guard mealRemindersEnabled else { return }
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else { return }
        let key = PantryViewModel.todayMealPlanKey(now: tomorrow, calendar: calendar)
        let names = MealPlanSlot.allCases.compactMap { slot in
            viewModel.plannedRecipe(dayKey: key, slot: slot)?.name
        }
        guard let first = names.first else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tomorrow's menu"
        content.body = names.count == 1 ? "You're cooking \(first)." : "You're cooking \(first) and \(names.count - 1) more."
        content.sound = .default
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 17
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: "reciplease.meal.tomorrow", content: content, trigger: trigger))
    }

    func rescheduleWeeklyNudge() {
        center.removePendingNotificationRequests(withIdentifiers: ["reciplease.plan.weekly"])
        guard weeklyNudgeEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Plan a few dinners"
        content.body = "Open Tonight's Menu and pick what sounds good this week."
        content.sound = .default
        var components = DateComponents()
        components.weekday = 1
        components.hour = 16
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "reciplease.plan.weekly", content: content, trigger: trigger))
    }

    func rescheduleExpiryReminders(ingredients: [Ingredient]) {
        let storedKey = "Reciplease.Notifications.ExpiryIDs"
        let previous = UserDefaults.standard.stringArray(forKey: storedKey) ?? []
        center.removePendingNotificationRequests(withIdentifiers: previous)
        guard expiryRemindersEnabled else {
            UserDefaults.standard.set([String](), forKey: storedKey)
            return
        }
        let calendar = Calendar.current
        var scheduled: [String] = []
        for ingredient in ingredients {
            guard let expiration = ingredient.expirationDate else { continue }
            guard let morning = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: expiration)) else { continue }
            guard morning > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Use soon"
            content.body = "\(ingredient.generalName) is best used in the next day or two."
            content.sound = .default
            var components = calendar.dateComponents([.year, .month, .day], from: morning)
            components.hour = 10
            let identifier = "reciplease.expiry.\(ingredient.id.uuidString)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            scheduled.append(identifier)
        }
        UserDefaults.standard.set(scheduled, forKey: storedKey)
    }
}
