//
//  TipOfDay.swift
//  PantryPal
//

import Foundation

/// Request body for the tip-of-day endpoint. Date is optional (BASIC_ISO_DATE format: yyyyMMdd).
struct TipOfDayRequest: Encodable {
    let date: String?
}

/// Tip of the day returned from the recipe API
struct TipOfDay: Codable {
    let title: String
    let content: String
}
