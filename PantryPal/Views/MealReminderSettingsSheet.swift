//
//  MealReminderSettingsSheet.swift
//  Reciplease
//

import SwiftUI

struct MealReminderSettingsSheet: View {
    @ObservedObject var viewModel: PantryViewModel
    @ObservedObject private var notifications = LocalNotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Tomorrow's meals", isOn: Binding(
                    get: { notifications.mealRemindersEnabled },
                    set: { enabled in
                        Task { await notifications.setMealRemindersEnabled(enabled, viewModel: viewModel) }
                    }
                ))
                Toggle("Weekly planning nudge", isOn: Binding(
                    get: { notifications.weeklyNudgeEnabled },
                    set: { enabled in
                        Task { await notifications.setWeeklyNudgeEnabled(enabled) }
                    }
                ))
                Toggle("Use Soon reminders", isOn: Binding(
                    get: { notifications.expiryRemindersEnabled },
                    set: { enabled in
                        Task { await notifications.setExpiryRemindersEnabled(enabled, ingredients: viewModel.ingredients) }
                    }
                ))
                Text("Reminders stay on this phone. Nothing is sent to a server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
