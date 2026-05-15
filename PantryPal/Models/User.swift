//
//  User.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation

// MARK: - User Model

struct User: Codable {
    let deviceId: String
    let platform: String
    let lastActive: String
    let membership: Membership
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case platform
        case lastActive = "last_active"
        case membership
    }
}

// MARK: - Membership Model

struct Membership: Codable {
    let history: [MembershipHistoryItem]
}

// MARK: - Membership History Item Model

struct MembershipHistoryItem: Codable {
    let timestamp: String
    let product: String
    let event: String
    let id: String
}
