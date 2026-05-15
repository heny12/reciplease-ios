//
//  CustomerCenterView.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @StateObject private var revenueCatService = RevenueCatService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pantryQuickActionSheet
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: DesignTokens.spacingMD) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading…")
                            .font(.pantryBody)
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            headerSection

                            if revenueCatService.isProMember, let customerInfo = revenueCatService.customerInfo {
                                customerSectionHeader("Your plan", isFirst: true)
                                currentPlanSection(customerInfo: customerInfo)
                                PantryQuickActionSheetChrome.sectionDivider
                                customerSectionHeader(ProMarketingCopy.customerCenterIncludedTitle, isFirst: false)
                                whatsIncludedContent
                            } else {
                                customerSectionHeader(ProMarketingCopy.customerCenterUpgradeTitle, isFirst: true)
                                upgradePromptContent
                            }

                            PantryQuickActionSheetChrome.sectionDivider
                            actionsSection
                            Spacer().frame(height: DesignTokens.spacingLG)
                        }
                        .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                        .padding(.top, DesignTokens.spacingSM)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Reciplease Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.pantryQuickActionSheet, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .font(.pantryBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                }
            }
            .tint(.white)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(scenario: .upgrade, isPresented: $showPaywall)
            }
            .task {
                await refreshCustomerInfo()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            BundleImage("avi_pan")
                .scaledToFit()
                .frame(width: 88, height: 88)

            Text("Reciplease Pro")
                .font(.pantryLargeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(
                revenueCatService.isProMember
                    ? "Your subscription is active"
                    : "Your personal kitchen companion"
            )
            .font(.pantrySubheadline)
            .foregroundStyle(Color.white.opacity(0.88))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, DesignTokens.spacingMD)
    }

    private func customerSectionHeader(_ name: String, isFirst: Bool) -> some View {
        Text(name.uppercased())
            .font(.pantryBody)
            .fontWeight(.bold)
            .tracking(0.55)
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.top, isFirst ? DesignTokens.spacingMD : DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current plan

    private func currentPlanSection(customerInfo: CustomerInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let proEntitlement = customerInfo.entitlements["Reciplease Pro"], proEntitlement.isActive {
                planRow(label: "Plan", value: friendlyProductName(proEntitlement.productIdentifier))
                planDivider
                planRow(label: "Status", value: "Active")
                if let expirationDate = proEntitlement.expirationDate {
                    planDivider
                    planRow(
                        label: "Renews",
                        value: expirationDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
        .padding(.bottom, DesignTokens.spacingSM)
    }

    private var planDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.22))
            .frame(height: 1)
            .padding(.vertical, DesignTokens.spacingSM)
    }

    private func planRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.78))
            Spacer(minLength: DesignTokens.spacingMD)
            Text(value)
                .font(.pantrySubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Benefits (paywall-style list on orange)

    private var whatsIncludedContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            ProMarketingPaywallStyleBenefitsList()
            Text(ProMarketingCopy.monthlyResetFootnote)
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DesignTokens.spacingXS)
        }
        .padding(.bottom, DesignTokens.spacingSM)
    }

    private var upgradePromptContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("Upgrade to unlock everything below.")
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            ProMarketingPaywallStyleBenefitsList()
            Text(ProMarketingCopy.monthlyResetFootnote)
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DesignTokens.spacingXS)
        }
        .padding(.bottom, DesignTokens.spacingSM)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if !revenueCatService.isProMember {
                Button {
                    HapticFeedback.light()
                    showPaywall = true
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "crown.fill")
                            .font(.pantryTitle3)
                        Text("Upgrade to Pro")
                            .font(.pantryTitle3)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.pantrySecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignTokens.buttonHeightLarge)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous)
                            .fill(Color.white)
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Already subscribed? Restore to sync your purchase.")
                .font(.pantryCaption)
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                HapticFeedback.light()
                Task { await restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.pantryBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.light()
                openManageSubscriptions()
            } label: {
                Text("Manage Subscription")
                    .font(.pantryBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, DesignTokens.spacingSM)
    }

    // MARK: - Helpers

    private func friendlyProductName(_ productIdentifier: String) -> String {
        let lower = productIdentifier.lowercased()
        if lower.contains("annual") || lower.contains("yearly") { return "Annual" }
        if lower.contains("monthly") { return "Monthly" }
        if lower.contains("weekly") { return "Weekly" }
        if lower.contains("lifetime") { return "Lifetime" }
        if lower.contains("6") || lower.contains("six") { return "6 Months" }
        if lower.contains("3") || lower.contains("three") { return "3 Months" }
        if lower.contains("2") || lower.contains("two") { return "2 Months" }
        return productIdentifier
            .replacingOccurrences(of: "reciplease_", with: "")
            .capitalized
    }

    private func refreshCustomerInfo() async {
        isLoading = true
        await revenueCatService.refreshCustomerInfo()
        isLoading = false
    }

    private func restorePurchases() async {
        isLoading = true
        let success = await revenueCatService.restorePurchases()
        isLoading = false
        if !success {
            errorMessage = revenueCatService.errorMessage ?? "Failed to restore purchases."
            showError = true
        }
    }

    private func openManageSubscriptions() {
        revenueCatService.showCustomerCenter()
    }
}
