//
//  AppCheckTokenProvider.swift
//  Reciplease
//
//  Attaches a Firebase App Check token when that SDK is linked. Linux typechecks
//  of the API clients compile the same call sites without Firebase.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

enum AppCheckTokenProvider {
    static func attach(to request: inout URLRequest, logPrefix: String) async {
        #if canImport(FirebaseAppCheck)
        do {
            let tokenResult = try await AppCheck.appCheck().token(forcingRefresh: false)
            request.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
            print("🛡️ \(logPrefix) App Check token attached")
        } catch {
            print("⚠️ \(logPrefix) Failed to get App Check token: \(error.localizedDescription)")
        }
        #else
        _ = request
        _ = logPrefix
        #endif
    }
}
