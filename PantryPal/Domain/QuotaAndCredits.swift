//
//  QuotaAndCredits.swift
//  Reciplease
//
//  Server quota envelope and the rule that failed calls never spend a credit.
//

import Foundation

struct QuotaExceededDetails: Codable, Equatable {
    var message: String?
    var remaining: Int?
    var limit: Int?
    var resetAtMs: Int64?

    var isQuotaExceeded: Bool { true }
}

enum QuotaEnvelopeParser {
    static func parse(data: Data) -> QuotaExceededDetails? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let error = (json["error"] as? String) ?? ""
        let code = (json["code"] as? String) ?? (json["error_code"] as? String) ?? ""
        guard error == "QUOTA_EXCEEDED" || code == "QUOTA_EXCEEDED" else { return nil }
        return QuotaExceededDetails(
            message: json["message"] as? String,
            remaining: json["remaining"] as? Int,
            limit: json["limit"] as? Int,
            resetAtMs: int64(json["resetAtMs"])
        )
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }
}

enum GenerationCreditPolicy {
    /// A generation credit is spent only after a successful recipe response.
    static func shouldConsumeCredit(httpStatus: Int) -> Bool {
        (200...299).contains(httpStatus)
    }
}

struct AllowanceSnapshot: Equatable {
    var remaining: Int
    var limit: Int
    var isPro: Bool
    var resetAtMs: Int64?
    var serverMessage: String?
}

enum AllowanceCopy {
    static func sheetTitle(isPro: Bool) -> String {
        isPro ? "Pro Allowance" : "Weekly Free Allowance"
    }

    static func settingsLabel(isPro: Bool) -> String {
        isPro ? "Recipe generations this subscription period" : "Recipe generations this week"
    }

    static func detail(_ snapshot: AllowanceSnapshot, now: Date = Date()) -> String {
        let noun = snapshot.isPro ? "this subscription period" : "this week"
        var text = "\(snapshot.remaining) of \(snapshot.limit) recipe generations and imports left \(noun) for pantry ideas, cookbook pages, and web links."
        if let message = snapshot.serverMessage, !message.isEmpty, snapshot.remaining == 0 {
            text = message
        }
        if let reset = resetPhrase(resetAtMs: snapshot.resetAtMs, now: now) {
            text += " " + reset
        }
        return text
    }

    static func resetPhrase(resetAtMs: Int64?, now: Date = Date()) -> String? {
        guard let resetAtMs else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(resetAtMs) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if date < now {
            return "The allowance was scheduled to reset \(formatter.string(from: date))."
        }
        return "Resets \(formatter.string(from: date))."
    }
}
