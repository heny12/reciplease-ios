//
//  PaywallView.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI
import RevenueCat

// MARK: - Paywall Scenario

/// Context for the paywall so copy and CTA can be tailored for conversion.
enum PaywallScenario: Equatable {
    /// Legacy: hard-block framing (prefer `.upgrade` for new flows).
    case trialExpired
    /// Legacy soft nudge (no longer used by the app shell).
    case trialEndingSoon(daysRemaining: Int)
    /// Voluntary upgrade or Pro-only feature (e.g. recipe modify).
    case upgrade
}

struct PaywallView: View {
    /// Dismiss the paywall: prefer the presenter’s `isPresented` binding so custom bindings (e.g. ContentView gating) update correctly. Only use `dismiss()` when no binding was provided.
    private func dismissPaywall() {
        if let binding = isPresented {
            binding.wrappedValue = false
        } else {
            dismiss()
        }
    }

    /// Which scenario is presenting the paywall (drives headline, CTA, and dismiss label).
    var scenario: PaywallScenario = .upgrade
    /// When provided, the dismiss button sets this to false so the presenter's sheet actually closes.
    var isPresented: Binding<Bool>? = nil
    
    @StateObject private var revenueCatService = RevenueCatService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var offerings: Offerings? = RevenueCatService.shared.cachedOfferings
    @State private var isLoadingOfferings = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var selectedPackage: Package?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSubscriptionSuccess = false
    /// Intro offer eligibility per product ID (.eligible, .ineligible, .unknown). Fetched when offerings load.
    @State private var introEligibility: [String: IntroEligibilityStatus] = [:]
    @State private var hasLoggedPaywallViewed = false
    
    /// Available packages from the current offering
    private var packages: [Package] {
        guard let offerings = offerings, let current = offerings.current else {
            return []
        }
        return current.availablePackages
    }
    
    private var navTitle: String {
        switch scenario {
        case .trialExpired: return "Trial ended"
        case .trialEndingSoon: return "Trial ending soon"
        case .upgrade: return "Reciplease Pro"
        }
    }

    var body: some View {
        Group {
            if showSubscriptionSuccess {
                PantryQuickActionSheetShell(minDetentHeight: 360) {
                    subscriptionSuccessSheetContent
                }
            } else {
                PantryQuickActionSheetShell(minDetentHeight: 600) {
                    if isLoadingOfferings {
                        paywallLoadingPlaceholder
                    } else {
                        paywallMainSheetContent
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if !hasLoggedPaywallViewed {
                hasLoggedPaywallViewed = true
                AppAnalytics.log(.paywallViewed, parameters: paywallBaseAnalyticsParams())
            }
            if offerings == nil {
                isLoadingOfferings = true
                Task {
                    await loadOfferings()
                }
            } else {
                if selectedPackage == nil {
                    selectedPackage = packages.first
                }
                Task.detached(priority: .background) {
                    _ = await revenueCatService.getOfferings()
                }
                Task {
                    await fetchIntroEligibilityIfNeeded()
                }
            }
        }
    }

    private var paywallLoadingPlaceholder: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            ProgressView()
                .tint(.white)
            Text("Loading subscription options…")
                .font(.pantryBody)
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXXL)
    }

    private var paywallMainSheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button("Close") {
                    dismissPaywall()
                }
                .font(.pantryBody)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .padding(.vertical, DesignTokens.spacingSM)
                .padding(.horizontal, DesignTokens.spacingSM)
                .contentShape(Rectangle())
            }
            .padding(.bottom, DesignTokens.spacingSM)

            Text(navTitle)
                .font(.pantryLargeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.82)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignTokens.spacingMD)

            paywallSectionHeader("Included", isFirst: true)
            paywallBenefitsCompact
            Text(ProMarketingCopy.monthlyResetFootnote)
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DesignTokens.spacingSM)

            PantryQuickActionSheetChrome.sectionDivider

            paywallSectionHeader("Choose your plan", isFirst: false)
            VStack(spacing: DesignTokens.spacingSM) {
                ForEach(packages, id: \.identifier) { package in
                    SubscriptionOptionCard(
                        package: package,
                        isIntroEligible: isIntroEligible(for: package),
                        isSelected: selectedPackage?.identifier == package.identifier,
                        showBestValue: package.packageType == .annual,
                        orangeSheetStyle: true
                    ) {
                        withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
                            selectedPackage = package
                        }
                    }
                }
            }

            PantryQuickActionSheetChrome.sectionDivider

            subscribeButton
            restoreAndPolicySection
        }
    }

    private func paywallSectionHeader(_ name: String, isFirst: Bool) -> some View {
        Text(name.uppercased())
            .font(.pantryBody)
            .fontWeight(.bold)
            .tracking(0.55)
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.top, isFirst ? DesignTokens.spacingMD : DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paywallBenefitsCompact: some View {
        ProMarketingPaywallStyleBenefitsList()
    }

    private var subscriptionSuccessSheetContent: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            GIFView(name: "avi_celebrate_animated")
                .frame(width: 160, height: 160)

            Text("Welcome to Reciplease Pro!")
                .font(.pantryTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("You're all set—dig into your pantry and recipes.")
                .font(.pantryBody)
                .foregroundStyle(Color.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                HapticFeedback.light()
                dismissPaywall()
            } label: {
                Text("Let's get cooking!")
                    .font(.pantryHeadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantrySecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignTokens.buttonHeightLarge)
                    .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous).fill(Color.white))
            }
            .padding(.top, DesignTokens.spacingSM)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subscribe Button

    /// Primary CTA label: "Start free trial" when intro-eligible, else scenario-based.
    private var primaryCTATitle: String {
        guard let package = selectedPackage else { return "Subscribe" }
        if isIntroEligible(for: package),
           let discount = package.storeProduct.introductoryDiscount,
           discount.paymentMode == .freeTrial {
            return "Start free trial"
        }
        switch scenario {
        case .trialExpired: return "Subscribe to continue"
        case .trialEndingSoon: return "Subscribe now"
        case .upgrade: return "Subscribe"
        }
    }
    
    private var subscribeButton: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Button(action: {
                if let package = selectedPackage {
                    AppAnalytics.log(.subscribeTapped, parameters: paywallBaseAnalyticsParams(extra: packageAnalyticsParams(for: package)))
                } else {
                    AppAnalytics.log(.subscribeTapped, parameters: paywallBaseAnalyticsParams())
                }
                Task {
                    await handlePurchase()
                }
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Color.pantrySecondary)
                            .scaleEffect(0.95)
                    } else {
                        if let package = selectedPackage {
                            VStack(spacing: 4) {
                                Text(primaryCTATitle)
                                    .font(.pantryTitle3)
                                    .fontWeight(.semibold)
                                Text(subscriptionDescription(for: package))
                                    .font(.pantrySubheadline)
                                    .foregroundStyle(Color.pantrySecondary.opacity(0.88))
                            }
                        } else {
                            Text(primaryCTATitle)
                                .font(.pantryTitle3)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .foregroundStyle(Color.pantrySecondary)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.buttonHeightLarge)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous)
                        .fill(Color.white)
                )
            }
            .disabled(selectedPackage == nil || isPurchasing)
            .opacity((selectedPackage == nil || isPurchasing) ? 0.55 : 1.0)

            Text("Cancel anytime")
                .font(.pantrySubheadline)
                .foregroundStyle(Color.white.opacity(0.78))
        }
    }
    
    // MARK: - Restore & Policy Section
    
    private let restoreHintText = "Already subscribed? Restore to sync your purchase."
    
    private var restoreAndPolicySection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Text(restoreHintText)
                .font(.pantryCaption)
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Button(action: {
                Task {
                    await handleRestore()
                }
            }) {
                Group {
                    if isRestoring {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Restore Purchases")
                            .font(.pantryBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isRestoring)
            .buttonStyle(.plain)

            HStack(spacing: DesignTokens.spacingXS) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)

                Text("•")
                    .foregroundStyle(Color.white.opacity(0.55))

                Link("Privacy Policy",
                     destination: URL(string: "https://reciplease.info/privacy")!)
            }
            .font(.pantrySubheadline)
            .tint(Color.white.opacity(0.88))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, DesignTokens.spacingSM)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Actions
    
    private func loadOfferings() async {
        let fetchedOfferings = await revenueCatService.getOfferings()
        
        await MainActor.run {
            offerings = fetchedOfferings
            isLoadingOfferings = false
            // Pre-select first package
            if selectedPackage == nil, let first = packages.first {
                selectedPackage = first
            }
        }
        
        // Determine intro offer eligibility so we only show intro UI to eligible users (App Store guideline).
        guard let current = fetchedOfferings?.current else { return }
        let products = current.availablePackages.map(\.storeProduct)
        let eligibility = await revenueCatService.checkIntroEligibility(for: products)
        await MainActor.run {
            introEligibility = eligibility
        }
    }
    
    /// Fetches intro eligibility for current packages. Call when offerings are already in state (e.g. cached) so cards can gate intro UI.
    private func fetchIntroEligibilityIfNeeded() async {
        let products = packages.map(\.storeProduct)
        guard !products.isEmpty else { return }
        let eligibility = await revenueCatService.checkIntroEligibility(for: products)
        await MainActor.run {
            introEligibility = eligibility
        }
    }
    
    /// True if we should show the introductory offer for this package (.eligible or .unknown).
    private func isIntroEligible(for package: Package) -> Bool {
        let status = introEligibility[package.storeProduct.productIdentifier] ?? .unknown
        return status == .eligible || status == .unknown
    }
    
    private func handlePurchase() async {
        guard let package = selectedPackage else { return }
        
        await MainActor.run { isPurchasing = true }
        
        let result = await revenueCatService.purchase(package: package)
        
        await MainActor.run {
            isPurchasing = false
            
            if result.success {
                AppAnalytics.log(.purchaseSuccess, parameters: paywallBaseAnalyticsParams(extra: packageAnalyticsParams(for: package)))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSubscriptionSuccess = true
                }
            } else if let error = result.error {
                AppAnalytics.log(.purchaseError, parameters: paywallBaseAnalyticsParams(extra: packageAnalyticsParams(for: package, extra: [
                    "error": error.localizedDescription
                ])))
                errorMessage = error.localizedDescription
                showError = true
            } else {
                // RevenueCat returns (success: false, error: nil) when user cancels.
                AppAnalytics.log(.purchaseCancelled, parameters: paywallBaseAnalyticsParams(extra: packageAnalyticsParams(for: package)))
            }
        }
    }
    
    private func handleRestore() async {
        await MainActor.run { isRestoring = true }
        
        let success = await revenueCatService.restorePurchases()
        
        await MainActor.run {
            isRestoring = false
            
            if success && revenueCatService.isProMember {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSubscriptionSuccess = true
                }
            } else if !success {
                errorMessage = "Unable to restore purchases. Please try again."
                showError = true
            } else {
                errorMessage = "No active subscriptions found to restore."
                showError = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func subscriptionDescription(for package: Package) -> String {
        let price = package.localizedPriceString
        
        switch package.packageType {
        case .weekly:
            return "\(price) per week"
        case .monthly:
            return "\(price) per month"
        case .twoMonth:
            return "\(price) every 2 months"
        case .threeMonth:
            return "\(price) every 3 months"
        case .sixMonth:
            return "\(price) every 6 months"
        case .annual:
            return "\(price) per year"
        case .lifetime:
            return "\(price) one-time purchase"
        default:
            return price
        }
    }

    // MARK: - Analytics helpers

    private func scenarioKey() -> String {
        switch scenario {
        case .trialExpired:
            return "trial_expired"
        case .trialEndingSoon:
            return "trial_ending_soon"
        case .upgrade:
            return "upgrade"
        }
    }

    private func paywallBaseAnalyticsParams(extra: [String: Any]? = nil) -> [String: Any] {
        var params: [String: Any] = [
            "scenario": scenarioKey(),
            "packages_count": packages.count,
            "paywall_surface": "sheet"
        ]
        if let extra {
            for (k, v) in extra {
                params[k] = v
            }
        }
        return params
    }

    private func packageAnalyticsParams(for package: Package, extra: [String: Any]? = nil) -> [String: Any] {
        var params: [String: Any] = [
            "package_id": package.identifier,
            "package_type": "\(package.packageType)",
            "product_id": package.storeProduct.productIdentifier,
            "price": package.localizedPriceString,
            "intro_eligible": isIntroEligible(for: package)
        ]
        if let extra {
            for (k, v) in extra {
                params[k] = v
            }
        }
        return params
    }
}

// MARK: - Subscription Option Card

struct SubscriptionOptionCard: View {
    let package: Package
    /// When false (user ineligible), intro offer UI is hidden and only standard price is shown (App Store guideline).
    let isIntroEligible: Bool
    let isSelected: Bool
    var showBestValue: Bool = false
    /// Paywall slide-up sheet: light text on frosted white card over orange.
    var orangeSheetStyle: Bool = false
    let action: () -> Void

    private var cardFill: Color {
        orangeSheetStyle ? Color.white.opacity(0.14) : Color.pantrySurface
    }

    private var titleColor: Color {
        orangeSheetStyle ? .white : .pantryTextPrimary
    }

    private var secondaryLabelColor: Color {
        orangeSheetStyle ? Color.white.opacity(0.78) : .pantryTextSecondary
    }

    private var selectionStroke: Color {
        if orangeSheetStyle {
            return isSelected ? Color.white : Color.white.opacity(0.35)
        }
        return isSelected ? Color.pantryPrimary : Color.pantryTextSecondary.opacity(0.3)
    }

    private var selectionFill: Color {
        orangeSheetStyle ? Color.white : Color.pantryPrimary
    }

    private var priceColor: Color {
        orangeSheetStyle ? .white : .pantryTextPrimary
    }
    
    /// Introductory offer info when present and user is eligible (intro line + "then" recurring line). Nil for lifetime, no offer, or ineligible.
    private var introductoryOfferInfo: (introLine: String, thenLine: String)? {
        guard isIntroEligible,
              package.packageType != .lifetime,
              let discount = package.storeProduct.introductoryDiscount,
              discount.type == .introductory else { return nil }
        let introLine = Self.formatIntroductoryOfferLine(discount: discount)
        let thenLine = "Then \(package.localizedPriceString) \(pricePeriod)"
        return (introLine, thenLine)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                if showBestValue {
                    Text("Best value")
                        .font(.pantryCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(orangeSheetStyle ? Color.pantrySecondary : .white)
                        .padding(.horizontal, orangeSheetStyle ? 10 : 8)
                        .padding(.vertical, orangeSheetStyle ? 5 : 4)
                        .background(orangeSheetStyle ? Color.white : Color.pantryPrimary)
                        .cornerRadius(6)
                        .padding(.bottom, 6)
                }
                HStack(spacing: DesignTokens.spacingMD) {
                    ZStack {
                        Circle()
                            .stroke(selectionStroke, lineWidth: orangeSheetStyle ? 2.5 : 2)
                            .frame(width: orangeSheetStyle ? 28 : 24, height: orangeSheetStyle ? 28 : 24)

                        if isSelected {
                            Circle()
                                .fill(selectionFill)
                                .frame(width: orangeSheetStyle ? 16 : 14, height: orangeSheetStyle ? 16 : 14)
                        }
                    }

                    VStack(alignment: .leading, spacing: orangeSheetStyle ? 4 : 2) {
                        Text(packageTitle)
                            .font(orangeSheetStyle ? .pantryTitle3 : .pantryHeadline)
                            .fontWeight(.semibold)
                            .foregroundColor(titleColor)

                        if let info = introductoryOfferInfo {
                            Text(info.introLine)
                                .font(orangeSheetStyle ? .pantrySubheadline : .pantryCaption)
                                .foregroundColor(secondaryLabelColor)
                            Text(info.thenLine)
                                .font(orangeSheetStyle ? .pantrySubheadline : .pantryCaption)
                                .foregroundColor(secondaryLabelColor)
                        } else if let subtitle = packageSubtitle {
                            Text(subtitle)
                                .font(orangeSheetStyle ? .pantrySubheadline : .pantryCaption)
                                .foregroundColor(secondaryLabelColor)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: orangeSheetStyle ? 4 : 2) {
                        if introductoryOfferInfo != nil, let discount = package.storeProduct.introductoryDiscount {
                            if discount.paymentMode == .freeTrial {
                                Text("Free")
                                    .font(orangeSheetStyle ? .pantryTitle2 : .pantryHeadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(priceColor)
                            } else {
                                Text(discount.localizedPriceString)
                                    .font(orangeSheetStyle ? .pantryTitle2 : .pantryHeadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(priceColor)
                            }
                            Text("then \(package.localizedPriceString)")
                                .font(orangeSheetStyle ? .pantrySubheadline : .pantryCaption)
                                .foregroundColor(secondaryLabelColor)
                        } else {
                            Text(package.localizedPriceString)
                                .font(orangeSheetStyle ? .pantryTitle2 : .pantryHeadline)
                                .fontWeight(.bold)
                                .foregroundColor(priceColor)

                            Text(pricePeriod)
                                .font(orangeSheetStyle ? .pantrySubheadline : .pantryCaption)
                                .foregroundColor(secondaryLabelColor)
                        }
                    }
                }
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)
                            .stroke(
                                orangeSheetStyle
                                    ? (isSelected ? Color.white : Color.white.opacity(0.4))
                                    : (isSelected ? Color.pantryPrimary : Color.pantryBorder.opacity(0.55)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: orangeSheetStyle
                    ? Color.clear
                    : (isSelected ? Color.pantryPrimary.opacity(0.12) : Color.black.opacity(0.04)),
                radius: orangeSheetStyle ? 0 : (isSelected ? 10 : 4),
                x: 0,
                y: orangeSheetStyle ? 0 : (isSelected ? 4 : 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var packageTitle: String {
        switch package.packageType {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .twoMonth:
            return "2 Months"
        case .threeMonth:
            return "3 Months"
        case .sixMonth:
            return "6 Months"
        case .annual:
            return "Annual"
        case .lifetime:
            return "Lifetime"
        default:
            return package.storeProduct.localizedTitle
        }
    }
    
    private var packageSubtitle: String? {
        switch package.packageType {
        case .annual:
            // Calculate monthly equivalent for annual
            if let price = package.storeProduct.price as Decimal? {
                let monthly = price / 12
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = package.storeProduct.priceFormatter?.locale ?? .current
                if let monthlyStr = formatter.string(from: monthly as NSDecimalNumber) {
                    return "\(monthlyStr)/mo"
                }
            }
            return nil
        default:
            return nil
        }
    }
    
    private var pricePeriod: String {
        switch package.packageType {
        case .weekly:
            return "per week"
        case .monthly:
            return "per month"
        case .twoMonth:
            return "every 2 months"
        case .threeMonth:
            return "every 3 months"
        case .sixMonth:
            return "every 6 months"
        case .annual:
            return "per year"
        case .lifetime:
            return "one-time"
        default:
            return ""
        }
    }
    
    /// Formats one line for the introductory offer (e.g. "7-day free trial", "$0.99 for 1 month").
    private static func formatIntroductoryOfferLine(discount: StoreProductDiscount) -> String {
        let period = discount.subscriptionPeriod
        let totalUnits = period.value * discount.numberOfPeriods
        let durationPhrase = Self.durationPhrase(value: totalUnits, unit: period.unit)
        
        switch discount.paymentMode {
        case .freeTrial:
            return "\(durationPhrase) free trial"
        case .payUpFront:
            return "\(discount.localizedPriceString) for \(durationPhrase)"
        case .payAsYouGo:
            let perUnit = Self.periodUnitLabel(period.unit)
            return "\(discount.localizedPriceString) per \(perUnit) for \(durationPhrase)"
        @unknown default:
            return "\(discount.localizedPriceString) for \(durationPhrase)"
        }
    }
    
    private static func periodUnitLabel(_ unit: SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
    
    /// Human-readable duration (e.g. "7-day", "1 week", "3 months").
    private static func durationPhrase(value: Int, unit: SubscriptionPeriod.Unit) -> String {
        let singular: String
        let plural: String
        switch unit {
        case .day:
            singular = "day"
            plural = "days"
        case .week:
            singular = "week"
            plural = "weeks"
        case .month:
            singular = "month"
            plural = "months"
        case .year:
            singular = "year"
            plural = "years"
        @unknown default:
            singular = "period"
            plural = "periods"
        }
        let word = value == 1 ? singular : plural
        // Use hyphen for compound modifier (e.g. "7-day free trial")
        if value == 1 && (unit == .day || unit == .week) {
            return "1 \(word)"
        }
        if unit == .day || unit == .week, value <= 7 {
            return "\(value)-\(word)"
        }
        return "\(value) \(word)"
    }
}

// MARK: - Compact Feature Row

struct CompactFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: icon)
                .font(.pantryHeadline)
                .foregroundColor(.pantryPrimary)
                .frame(width: 28, alignment: .center)
            
            Text(text)
                .font(.pantryBody)
                .foregroundColor(.pantryTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
