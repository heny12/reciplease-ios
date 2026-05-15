//
//  MealPlanCalendarService.swift
//  Reciplease
//
//  Syncs Plan tab meals to Calendar via EventKit (dedicated “Reciplease” calendar).
//

import EventKit
import Foundation

// MARK: - Cold-launch Plan tab prompt

@MainActor
enum MealPlanCalendarPromptCoordinator {
    /// Set each cold launch from `AppDelegate`; cleared after the user dismisses the Plan tab offer for that launch.
    static var shouldOfferCalendarPermissionOnPlanAppear = false

    /// Call from `application(_:didFinishLaunchingWithOptions:)` on the main thread.
    static func armPlanTabPromptIfCalendarDisabled() {
        if MealPlanCalendarService.shared.hasFullCalendarAccess {
            shouldOfferCalendarPermissionOnPlanAppear = false
        } else {
            shouldOfferCalendarPermissionOnPlanAppear = true
        }
    }
}

// MARK: - EventKit sync

@MainActor
final class MealPlanCalendarService {
    static let shared = MealPlanCalendarService()

    private let store = EKEventStore()
    private let calendarTitle = "Reciplease"
    private let userDefaultsCalendarKey = "Reciplease.MealPlanEKCalendarIdentifier"
    private let eventNotes = "Planned in Reciplease"
    private let eventDurationSeconds: TimeInterval = 30 * 60

    private init() {}

    /// Full Calendar access is required to create the dedicated “Reciplease” calendar and keep meal events grouped there.
    var hasFullCalendarAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Use Settings instead of the system permission dialog (denied, restricted, or write-only when full access is required).
    var needsSettingsToEnableFullCalendarAccess: Bool {
        switch authorizationStatus {
        case .notDetermined, .fullAccess:
            return false
        case .denied, .restricted, .writeOnly:
            return true
        @unknown default:
            return true
        }
    }

    /// Requests full calendar access so we can create the green “Reciplease” calendar and sync planned meals there.
    func requestFullCalendarAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    /// Aligns Calendar with the meal plan and updates persisted event identifiers.
    func reconcile(
        mealPlanByDay: [String: SavedDayMealPlan],
        recipeLookup: [UUID: Recipe],
        bindings: inout [String: SavedDayMealPlanCalendarIds]
    ) async {
        guard hasFullCalendarAccess else { return }

        let calendar: EKCalendar
        do {
            calendar = try ensureMealPlanCalendar()
        } catch {
            print("❌ [Calendar] Could not resolve meal plan calendar: \(error.localizedDescription)")
            return
        }

        var allDayKeys = Set(mealPlanByDay.keys)
        allDayKeys.formUnion(bindings.keys)

        for dayKey in allDayKeys {
            var dayBindings = bindings[dayKey] ?? SavedDayMealPlanCalendarIds()

            for slot in MealPlanSlot.allCases {
                let recipeId = mealPlanByDay[dayKey]?.recipeId(for: slot)
                let boundId = dayBindings.eventIdentifier(for: slot)

                if recipeId == nil {
                    if let boundId {
                        removeEventIfPresent(eventIdentifier: boundId)
                        dayBindings.setEventIdentifier(nil, for: slot)
                    }
                    continue
                }

                guard let rid = recipeId, let recipe = recipeLookup[rid] else {
                    if let boundId {
                        removeEventIfPresent(eventIdentifier: boundId)
                        dayBindings.setEventIdentifier(nil, for: slot)
                    }
                    continue
                }

                guard let startDate = Self.eventStartDate(dayKey: dayKey, slot: slot) else {
                    continue
                }
                let endDate = startDate.addingTimeInterval(eventDurationSeconds)

                if let boundId {
                    if let existing = store.event(withIdentifier: boundId) {
                        if existing.calendar.calendarIdentifier == calendar.calendarIdentifier {
                            var needsSave = false
                            if existing.title != recipe.name {
                                existing.title = recipe.name
                                needsSave = true
                            }
                            if existing.startDate != startDate || existing.endDate != endDate {
                                existing.startDate = startDate
                                existing.endDate = endDate
                                needsSave = true
                            }
                            if existing.notes != eventNotes {
                                existing.notes = eventNotes
                                needsSave = true
                            }
                            if needsSave {
                                do {
                                    try store.save(existing, span: .thisEvent)
                                } catch {
                                    print("❌ [Calendar] Failed to update event: \(error.localizedDescription)")
                                }
                            }
                            continue
                        }
                        removeEventIfPresent(eventIdentifier: boundId)
                        dayBindings.setEventIdentifier(nil, for: slot)
                    } else {
                        dayBindings.setEventIdentifier(nil, for: slot)
                    }
                }

                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = recipe.name
                event.notes = eventNotes
                event.startDate = startDate
                event.endDate = endDate
                do {
                    try store.save(event, span: .thisEvent)
                    if let newId = event.eventIdentifier {
                        dayBindings.setEventIdentifier(newId, for: slot)
                    }
                } catch {
                    print("❌ [Calendar] Failed to save event: \(error.localizedDescription)")
                }
            }

            if dayBindings.hasAnyIdentifier {
                bindings[dayKey] = dayBindings
            } else {
                bindings.removeValue(forKey: dayKey)
            }
        }
    }

    /// Brand green aligned with `Color.pantryPrimary` (EventKit cannot use SwiftUI `Color` directly).
    private static let recipleaseCalendarCGColor = CGColor(red: 0.18, green: 0.62, blue: 0.38, alpha: 1)

    private func ensureMealPlanCalendar() throws -> EKCalendar {
        if let storedId = UserDefaults.standard.string(forKey: userDefaultsCalendarKey),
           let existing = store.calendar(withIdentifier: storedId),
           existing.title == calendarTitle {
            return existing
        }

        UserDefaults.standard.removeObject(forKey: userDefaultsCalendarKey)

        for source in sourcesEligibleForCreatingCalendar() {
            let cal = EKCalendar(for: .event, eventStore: store)
            cal.title = calendarTitle
            cal.cgColor = Self.recipleaseCalendarCGColor
            cal.source = source
            do {
                try store.saveCalendar(cal, commit: true)
                UserDefaults.standard.set(cal.calendarIdentifier, forKey: userDefaultsCalendarKey)
                return cal
            } catch {
                print("⚠️ [Calendar] Could not create calendar on “\(source.title)” (sourceType=\(source.sourceType.rawValue)): \(error.localizedDescription)")
            }
        }

        throw MealPlanCalendarError.noWritableSource
    }

    /// Sources ordered so we try accounts that typically allow creating calendars before restricted ones (e.g. some Exchange configs).
    private func sourcesEligibleForCreatingCalendar() -> [EKSource] {
        var ordered: [EKSource] = []
        var seen = Set<String>()

        func appendUnique(_ source: EKSource?) {
            guard let source else { return }
            guard !seen.contains(source.sourceIdentifier) else { return }
            seen.insert(source.sourceIdentifier)
            ordered.append(source)
        }

        appendUnique(store.defaultCalendarForNewEvents?.source)

        for s in store.sources where s.sourceType == .calDAV {
            appendUnique(s)
        }
        for s in store.sources where s.sourceType == .local {
            appendUnique(s)
        }
        for s in store.sources where s.sourceType == .mobileMe {
            appendUnique(s)
        }
        for s in store.sources {
            appendUnique(s)
        }
        return ordered
    }

    private func removeEventIfPresent(eventIdentifier: String) {
        guard let event = store.event(withIdentifier: eventIdentifier) else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            print("❌ [Calendar] Failed to remove event: \(error.localizedDescription)")
        }
    }

    private static func eventStartDate(dayKey: String, slot: MealPlanSlot) -> Date? {
        guard let dayStart = parseDayKeyToStartOfDay(dayKey) else { return nil }
        let (hour, minute) = hourMinute(for: slot)
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
    }

    private static func parseDayKeyToStartOfDay(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        guard let date = Calendar.current.date(from: c) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    private static func hourMinute(for slot: MealPlanSlot) -> (Int, Int) {
        switch slot {
        case .breakfast: return (7, 0)
        case .lunch: return (12, 0)
        case .snack: return (15, 0)
        case .dinner: return (17, 0)
        case .dessert: return (20, 0)
        }
    }
}

private enum MealPlanCalendarError: Error {
    case noWritableSource
}
