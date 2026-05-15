//
//  TipOfDayService.swift
//  PantryPal
//

import Combine
import Foundation

/// Loads and holds the tip of the day. Fetched once on app startup.
final class TipOfDayService: ObservableObject {
    static let shared = TipOfDayService()
    
    @Published private(set) var tipOfDay: TipOfDay?
    @Published private(set) var isLoading = false
    
    /// BASIC_ISO_DATE format: yyyyMMdd (e.g. 20250302)
    private static let basicISODateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()
    
    private init() {}
    
    /// Fetches the tip of the day (once per launch). Call from app startup.
    func loadTipOfDay() {
        guard !isLoading, tipOfDay == nil else { return }
        isLoading = true
        
        Task { @MainActor in
            defer { isLoading = false }
            let dateString = Self.basicISODateFormatter.string(from: Date())
            do {
                let tip = try await RecipeAPIService.shared.fetchTipOfDay(date: dateString)
                tipOfDay = tip
            } catch {
                print("⚠️ Tip of day failed: \(error.localizedDescription)")
            }
        }
    }
}
