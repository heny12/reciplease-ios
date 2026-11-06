//
//  DeviceIDManager.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages the unique device identifier for the app.
/// Prefers Keychain (persists across reinstall); migrates from UserDefaults for existing users and keeps both in sync.
class DeviceIDManager {
    static let shared = DeviceIDManager()
    
    private let userDefaults = UserDefaults.standard
    private let deviceIDKey = "Reciplease.DeviceID"
    
    private init() {}
    
    /// Gets or creates a unique device ID.
    /// Existing users: keeps ID from UserDefaults and copies to Keychain. New users: store in Keychain (and UserDefaults).
    var deviceID: String {
        // 1. Existing users: use ID from UserDefaults and ensure it's in Keychain (migrate, never delete)
        if let existingID = userDefaults.string(forKey: deviceIDKey), !existingID.isEmpty {
            _ = KeychainHelper.set(existingID, forKey: deviceIDKey)
            return existingID
        }
        
        // 2. Keychain (e.g. after reinstall or first run after migration)
        if let keychainID = KeychainHelper.string(forKey: deviceIDKey), !keychainID.isEmpty {
            userDefaults.set(keychainID, forKey: deviceIDKey)
            return keychainID
        }
        
        // 3. New user: generate and store in both (never delete)
        let newID: String
        #if canImport(UIKit)
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            newID = vendorID
        } else {
            newID = UUID().uuidString
        }
        #else
        newID = UUID().uuidString
        #endif
        _ = KeychainHelper.set(newID, forKey: deviceIDKey)
        userDefaults.set(newID, forKey: deviceIDKey)
        return newID
    }
}
