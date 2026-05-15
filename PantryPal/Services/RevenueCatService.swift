//
//  RevenueCatService.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation
import RevenueCat
import Combine

/// Service for managing RevenueCat subscriptions and entitlements
@MainActor
class RevenueCatService: NSObject, ObservableObject {
    static let shared = RevenueCatService()
    
    // MARK: - Published Properties
    
    @Published var customerInfo: CustomerInfo?
    @Published var isProMember: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    
    private let apiKey = AppConfig.revenueCatAPIKey
    private let entitlementID = "Reciplease Pro"
    private let monthlyProductID = "reciplease_monthly"
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        // Don't set up delegate here - wait until after configuration
    }
    
    // MARK: - Configuration
    
    /// Configures RevenueCat with API key and user ID
    func configure() {
        Purchases.configure(withAPIKey: apiKey)
        
        // Set up delegate after configuration
        setupCustomerInfoListener()
        
        // Set user ID from device ID
        let deviceID = DeviceIDManager.shared.deviceID
        Purchases.shared.logIn(deviceID) { [weak self] (customerInfo: CustomerInfo?, created: Bool, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ RevenueCat login error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    self?.updateProStatus(nil)
                } else {
                    print("✅ RevenueCat user logged in: \(deviceID), created: \(created)")
                    self?.customerInfo = customerInfo
                    self?.updateProStatus(customerInfo)
                }
            }
        }
    }
    
    // MARK: - Customer Info
    
    /// Fetches the latest customer info from RevenueCat
    func refreshCustomerInfo() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateProStatus(customerInfo)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("❌ Failed to refresh customer info: \(error.localizedDescription)")
            }
        }
    }
    
    /// Checks if user has active "Reciplease Pro" entitlement
    func checkProEntitlement() -> Bool {
        guard let customerInfo = customerInfo else {
            return false
        }
        return customerInfo.entitlements[entitlementID]?.isActive == true
    }
    
    // MARK: - Products & Offerings
    
    /// Cached offerings to avoid repeated network requests
    @Published private(set) var cachedOfferings: Offerings?
    
    /// Fetches available offerings (products)
    /// Uses cached offerings if available and fresh, otherwise fetches from network
    func getOfferings() async -> Offerings? {
        if let cached = cachedOfferings {
            Task {
                await refreshOfferings()
            }
            return cached
        }
        return await refreshOfferings()
    }
    
    /// Fetches fresh offerings from network and updates cache
    private func refreshOfferings() async -> Offerings? {
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                cachedOfferings = offerings
            }
            return offerings
        } catch {
            print("❌ Failed to fetch offerings: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Preloads offerings in the background (call this on app launch or when limit is close)
    func preloadOfferings() {
        Task {
            _ = await refreshOfferings()
        }
    }
    
    /// Checks introductory offer eligibility for the given products (iOS only).
    /// Returns a dictionary keyed by product identifier. Use to show intro offer UI only when status is .eligible (or .unknown if desired).
    func checkIntroEligibility(for products: [StoreProduct]) async -> [String: IntroEligibilityStatus] {
        var result: [String: IntroEligibilityStatus] = [:]
        for product in products {
            let status = await withCheckedContinuation { (continuation: CheckedContinuation<IntroEligibilityStatus, Never>) in
                Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) { status in
                    continuation.resume(returning: status)
                }
            }
            result[product.productIdentifier] = status
        }
        return result
    }
    
    /// Gets the monthly subscription package
    func getMonthlyPackage() async -> Package? {
        guard let offerings = await getOfferings() else {
            return nil
        }
        
        // Try to get from current offering first
        if let currentOffering = offerings.current {
            if let monthlyPackage = currentOffering.availablePackages.first(where: { $0.storeProduct.productIdentifier == monthlyProductID }) {
                return monthlyPackage
            }
        }
        
        // Fallback: get first available package
        return offerings.current?.availablePackages.first
    }
    
    // MARK: - Purchases
    
    /// Purchases a package (subscription)
    func purchase(package: Package) async -> (success: Bool, customerInfo: CustomerInfo?, error: Error?) {
        isLoading = true
        errorMessage = nil
        
        do {
            let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            
            if userCancelled {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Purchase was cancelled"
                }
                return (false, nil, nil)
            }
            
            await MainActor.run {
                self.isLoading = false
                self.customerInfo = customerInfo
                self.updateProStatus(customerInfo)
                
                if let transaction = transaction {
                    print("✅ Purchase successful: \(transaction.productIdentifier)")
                }
            }
            
            return (true, customerInfo, nil)
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            
            print("❌ Purchase failed: \(error.localizedDescription)")
            return (false, nil, error)
        }
    }
    
    /// Restores previous purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateProStatus(customerInfo)
                self.isLoading = false
            }
            print("✅ Purchases restored successfully")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Failed to restore purchases: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Syncs purchases with RevenueCat (useful after StoreKit 2 purchases)
    func syncPurchases() async {
        isLoading = true
        do {
            // Force RevenueCat to sync with the App Store
            let customerInfo = try await Purchases.shared.syncPurchases()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateProStatus(customerInfo)
                self.isLoading = false
                print("✅ Purchases synced successfully")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Failed to sync purchases: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Customer Center
    
    /// Opens the RevenueCat Customer Center for subscription management
    func showCustomerCenter() {
        Purchases.shared.showManageSubscriptions { error in
            if let error = error {
                print("❌ Failed to show customer center: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the pro member status based on customer info
    private func updateProStatus(_ customerInfo: CustomerInfo?) {
        guard let customerInfo = customerInfo else {
            isProMember = false
            AppAnalytics.setSubscriberTier(isPro: false)
            GenerationCreditsManager.shared.refreshPeriodsAndUsage(customerInfo: nil)
            return
        }

        // Debug: Print active entitlements
        print("DEBUG: Active entitlements: \(customerInfo.entitlements.active.keys)")

        isProMember = customerInfo.entitlements[entitlementID]?.isActive == true
        AppAnalytics.setSubscriberTier(isPro: isProMember)
        GenerationCreditsManager.shared.refreshPeriodsAndUsage(customerInfo: customerInfo)
    }
    
    /// Sets up listener for customer info updates
    private func setupCustomerInfoListener() {
        Purchases.shared.delegate = self
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateProStatus(customerInfo)
        }
    }
}
