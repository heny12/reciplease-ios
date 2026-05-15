//
//  SettingsView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI
import UIKit

/// Full settings and former “…” menu actions, presented as the orange quick-action sheet from the main toolbar.
struct SettingsQuickActionSheet: View {
    @ObservedObject var generationCredits: GenerationCreditsManager
    let onLimitsAndUpgrades: () -> Void

    @StateObject private var revenueCatService = RevenueCatService.shared
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var showFeedbackForm = false
    @State private var showBugReportForm = false
    @State private var showFeatureSuggestionForm = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        PantryQuickActionSheetShell(minDetentHeight: 520) {
            VStack(alignment: .leading, spacing: 0) {
                PantryQuickActionSheetChrome.sheetTitle("Settings")

                if !revenueCatService.isProMember {
                    PantryQuickActionSheetChrome.sectionHeader("Credits", isFirst: true)
                    Text("\(generationCredits.remainingCredits)/\(generationCredits.maxCreditsForCurrentTier)")
                        .font(.pantryTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    Text("Recipe generations this period")
                        .font(.pantrySubheadline)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, DesignTokens.spacingSM)

                    PantryQuickActionSheetChrome.sectionDivider

                    PantryQuickActionSheetChrome.actionRow(title: "Limits & upgrades", systemImage: "sparkles", action: onLimitsAndUpgrades)

                    PantryQuickActionSheetChrome.sectionDivider
                }

                PantryQuickActionSheetChrome.sectionHeader("Account", isFirst: revenueCatService.isProMember)
                PantryQuickActionSheetChrome.actionRow(
                    title: "My Subscription",
                    systemImage: revenueCatService.isProMember ? "crown.fill" : "crown",
                    action: {
                        if revenueCatService.isProMember {
                            showCustomerCenter = true
                        } else {
                            showPaywall = true
                        }
                    }
                )
                PantryQuickActionSheetChrome.actionRow(title: "Restore Purchases", systemImage: "arrow.clockwise.circle.fill", action: restorePurchases)

                PantryQuickActionSheetChrome.sectionDivider

                PantryQuickActionSheetChrome.sectionHeader("Legal")
                PantryQuickActionSheetChrome.actionRow(title: "Terms of Service", systemImage: "doc.text.fill", action: openTermsOfService)
                PantryQuickActionSheetChrome.actionRow(title: "Privacy Policy", systemImage: "hand.raised.fill", action: openPrivacyPolicy)

                PantryQuickActionSheetChrome.sectionDivider

                PantryQuickActionSheetChrome.sectionHeader("Support")
                PantryQuickActionSheetChrome.actionRow(title: "Submit Feedback", systemImage: "envelope.fill", action: {
                    showFeedbackForm = true
                })
                PantryQuickActionSheetChrome.actionRow(title: "Report a Bug", systemImage: "exclamationmark.triangle.fill", action: {
                    showBugReportForm = true
                })
                PantryQuickActionSheetChrome.actionRow(title: "Suggest a Feature", systemImage: "lightbulb.fill", action: {
                    showFeatureSuggestionForm = true
                })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingLG)
        }
        .sheet(isPresented: $showFeedbackForm) {
            FeedbackFormView(feedbackType: .feedback)
        }
        .sheet(isPresented: $showBugReportForm) {
            FeedbackFormView(feedbackType: .bug)
        }
        .sheet(isPresented: $showFeatureSuggestionForm) {
            FeedbackFormView(feedbackType: .feature)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(scenario: .upgrade, isPresented: $showPaywall)
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") { }
        } message: {
            Text(restoreMessage)
        }
    }

    private func restorePurchases() {
        Task {
            let success = await revenueCatService.restorePurchases()
            await MainActor.run {
                if success {
                    restoreMessage = "Your purchases have been restored successfully."
                } else {
                    restoreMessage = revenueCatService.errorMessage ?? "Failed to restore purchases. Please try again."
                }
                showRestoreAlert = true
            }
        }
    }

    private func openTermsOfService() {
        if let url = URL(string: "https://reciplease.info/terms") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://reciplease.info/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsQuickActionSheet(
        generationCredits: GenerationCreditsManager.shared,
        onLimitsAndUpgrades: {}
    )
}
