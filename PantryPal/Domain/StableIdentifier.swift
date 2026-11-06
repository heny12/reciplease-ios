//
//  StableIdentifier.swift
//  Reciplease
//
//  Maps server ids (UUID strings or opaque keys) onto a stable local UUID so
//  sharing and re-opening keep the same identity.
//

import Foundation

enum StableIdentifier {
    static func uuid(from string: String) -> UUID {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmed) {
            return uuid
        }
        var hashA: UInt64 = 14_695_981_039_346_656_037
        var hashB: UInt64 = 10_995_116_282_111
        for byte in trimmed.utf8 {
            hashA ^= UInt64(byte)
            hashA = hashA &* 1_099_511_628_211
            hashB ^= UInt64(byte)
            hashB = hashB &* 14_695_981_039_346_656_037
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((hashA >> (8 * index)) & 0xff)
            bytes[8 + index] = UInt8((hashB >> (8 * index)) & 0xff)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
