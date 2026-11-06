//
//  FlexibleDecoding.swift
//  Reciplease
//
//  Tolerant JSON number/bool readers so v1 and v2 payloads decode together.
//

import Foundation

enum FlexibleDecoding {
    static func decodeDouble<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Double? {
        if (try? container.decodeNil(forKey: key)) == true { return nil }
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    static func decodeInt<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Int? {
        if (try? container.decodeNil(forKey: key)) == true { return nil }
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(Double.self, forKey: key) { return Int(value.rounded()) }
        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    static func decodeBool<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Bool? {
        if (try? container.decodeNil(forKey: key)) == true { return nil }
        if let value = try? container.decode(Bool.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return value != 0 }
        if let value = try? container.decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    static func decodeString<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> String? {
        if (try? container.decodeNil(forKey: key)) == true { return nil }
        if let value = try? container.decode(String.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return String(value) }
        if let value = try? container.decode(Double.self, forKey: key) {
            return RecipeQuantityScaling.formatQuantityValue(value)
        }
        return nil
    }
}
