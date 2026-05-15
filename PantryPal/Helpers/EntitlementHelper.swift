//
//  EntitlementHelper.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation

/// Helper utilities for checking subscription entitlements
enum EntitlementHelper {
    /// Checks if user has active "Reciplease Pro" entitlement
    static var isProMember: Bool {
        return RevenueCatService.shared.isProMember
    }
    
    /// Checks if user has active entitlement (async)
    static func checkProEntitlement() async -> Bool {
        await RevenueCatService.shared.refreshCustomerInfo()
        return RevenueCatService.shared.isProMember
    }
}
