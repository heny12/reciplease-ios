//
//  UserService.swift
//  PantryPal
//
//  Created by Henry Chipman on 1/28/26.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

/// Service for fetching and managing user data from the backend
class UserService {
    static let shared = UserService()
    
    private let baseURL = AppConfig.recipleaseAPIBaseURL
    private let userEndpoint = "/api/user"
    private let feedbackEndpoint = "/api/feedback"
    private let recipeEndpoint = "/api/recipe"
    
    private let userDefaults = UserDefaults.standard
    private let userDataKey = "Reciplease.UserData"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetches user data from the backend API (single attempt).
    /// This is optional and will not block app loading if it fails
    func fetchUserData() async {
        let deviceID = DeviceIDManager.shared.deviceID
        
        do {
            let user = try await performUserDataRequest(deviceId: deviceID)
            saveUserData(user)
            print("✅ Successfully fetched and saved user data")
        } catch {
            print("⚠️ Failed to fetch user data (non-blocking): \(error.localizedDescription)")
            // Don't throw - this is optional and shouldn't block app loading
        }
    }
    
    /// Gets the stored user data, if available
    var storedUserData: User? {
        guard let data = userDefaults.data(forKey: userDataKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(User.self, from: data)
        } catch {
            print("⚠️ Failed to decode stored user data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Submits feedback to the backend API (single attempt).
    /// This is optional and will not block app loading if it fails
    /// - Parameters:
    ///   - type: Optional feedback type (e.g., "bug", "feature", "general")
    ///   - content: Optional feedback content/message
    func submitFeedback(type: String? = nil, content: String? = nil) async {
        let deviceID = DeviceIDManager.shared.deviceID
        
        do {
            try await performFeedbackRequest(deviceId: deviceID, type: type, content: content)
            print("✅ Successfully submitted feedback")
        } catch {
            print("⚠️ Failed to submit feedback (non-blocking): \(error.localizedDescription)")
            // Don't throw - this is optional and shouldn't block app loading
        }
    }
    
    /// Fetches a single recipe by its backend id string from the Reciplease API.
    /// This surfaces APIError so callers get user-friendly error messages.
    func fetchRecipe(id: String) async throws -> Recipe {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let backendId = trimmedId.lowercased()
        
        guard !backendId.isEmpty else {
            throw APIError.clientError(400, "INVALID_REQUEST", "Missing recipe id", nil)
        }
        
        guard let url = URL(string: baseURL + recipeEndpoint) else {
            throw APIError.invalidURL
        }
        
        print("📖 [UserService] Fetching recipe with backend id: \(backendId)")
        print("🌐 [UserService] Recipe API URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add device ID header for consistency
        let deviceID = DeviceIDManager.shared.deviceID
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        
        await AppCheckTokenProvider.attach(to: &request, logPrefix: "[UserService] recipe")
        
        let body: [String: Any] = [
            "id": backendId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        print("📤 [UserService] Sending single recipe fetch request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [UserService] Invalid response type for recipe request")
            throw APIError.invalidResponse
        }
        
        print("📥 [UserService] Recipe response status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Map error into APIError so callers can show friendly messages
            let responseBody = String(data: data, encoding: .utf8)
            var errorCode: String? = nil
            var errorMessage: String? = nil
            
            if let raw = responseBody?.data(using: .utf8) {
                if let parsed = try? JSONDecoder().decode(APIErrorResponse.self, from: raw) {
                    errorCode = parsed.code ?? parsed.error
                    errorMessage = parsed.message
                } else if let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
                    errorCode = json["error"] as? String ?? json["code"] as? String
                    errorMessage = json["message"] as? String
                }
            }
            
            if (500...599).contains(httpResponse.statusCode) {
                print("🔴 [UserService] Recipe server error (\(httpResponse.statusCode)), code=\(errorCode ?? "none"), body=\(responseBody ?? "none")")
                throw APIError.serverError(httpResponse.statusCode, errorCode, errorMessage, nil)
            } else if (400...499).contains(httpResponse.statusCode) {
                print("🟠 [UserService] Recipe client error (\(httpResponse.statusCode)), code=\(errorCode ?? "none"), body=\(responseBody ?? "none")")
                throw APIError.clientError(httpResponse.statusCode, errorCode, errorMessage, nil)
            } else {
                throw APIError.clientError(httpResponse.statusCode, errorCode, errorMessage, nil)
            }
        }
        
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            print("✅ [UserService] Successfully fetched recipe: \(recipe.name)")
            return recipe
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [UserService] Decoding error for single recipe. Response: \(responseString)")
            }
            print("❌ [UserService] Decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Instacart

    /// Sends unchecked grocery items to the Reciplease API and returns an Instacart shopping-list URL.
    /// The backend proxies the Instacart Developer Platform API and embeds the partner tracking token.
    func fetchInstacartShoppingListURL(items: [(name: String, quantity: String)]) async throws -> URL {
        guard let url = URL(string: baseURL + "/api/instacart/shopping-list") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceID = DeviceIDManager.shared.deviceID
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")

        await AppCheckTokenProvider.attach(to: &request, logPrefix: "[UserService] Instacart")

        let lineItems = items.map { item -> [String: String] in
            var dict: [String: String] = ["name": item.name]
            if !item.quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dict["quantity"] = item.quantity
            }
            return dict
        }

        let body: [String: Any] = ["items": lineItems]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        print("📤 [UserService] Sending Instacart shopping-list request with \(items.count) item(s)…")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📥 [UserService] Instacart response status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorCode: String? = nil
            var errorMessage: String? = nil
            if let parsed = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                errorCode = parsed.resolvedApiCode
                errorMessage = parsed.message
            }
            if (500...599).contains(httpResponse.statusCode) {
                throw APIError.serverError(httpResponse.statusCode, errorCode, errorMessage, nil)
            } else {
                throw APIError.clientError(httpResponse.statusCode, errorCode, errorMessage, nil)
            }
        }

        struct InstacartResponse: Decodable {
            let url: String
        }

        let decoded = try JSONDecoder().decode(InstacartResponse.self, from: data)
        guard let resultURL = URL(string: decoded.url) else {
            throw APIError.decodingError(
                NSError(domain: "UserService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Instacart response contained an invalid URL"])
            )
        }

        print("✅ [UserService] Instacart shopping-list URL: \(resultURL.absoluteString)")
        return resultURL
    }

    // MARK: - Private Methods
    
    private func performUserDataRequest(deviceId: String) async throws -> User {
        guard let url = URL(string: baseURL + userEndpoint) else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Create request body
        let requestBody: [String: String] = [
            "deviceId": deviceId,
            "platform": "iOS"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body"])
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add device ID header for consistency with RecipeAPIService
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        await AppCheckTokenProvider.attach(to: &request, logPrefix: "[UserService]")
        
        request.httpBody = jsonData
        request.timeoutInterval = 10.0
        
        print("📱 Device ID header: \(deviceId)")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "UserService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode): \(errorMessage)"]
            )
        }
        
        // Decode response
        do {
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)
            return user
        } catch {
            print("❌ Failed to decode user data: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Response: \(jsonString)")
            }
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])
        }
    }
    
    private func performFeedbackRequest(deviceId: String, type: String?, content: String?) async throws {
        guard let url = URL(string: baseURL + feedbackEndpoint) else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Create request body with optional fields
        var requestBody: [String: Any] = [:]
        requestBody["device_id"] = deviceId
        if let type = type {
            requestBody["type"] = type
        }
        if let content = content {
            requestBody["content"] = content
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body"])
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add device ID header for consistency with RecipeAPIService
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        await AppCheckTokenProvider.attach(to: &request, logPrefix: "[UserService] feedback")
        
        request.httpBody = jsonData
        request.timeoutInterval = 10.0
        
        print("📱 Feedback request - Device ID header: \(deviceId)")
        if let type = type {
            print("   Type: \(type)")
        }
        if let content = content {
            print("   Content: \(content.prefix(50))\(content.count > 50 ? "..." : "")")
        }
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "UserService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode): \(errorMessage)"]
            )
        }
        
        print("✅ Feedback submitted successfully")
    }
    
    /// Saves user data to UserDefaults
    private func saveUserData(_ user: User) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(user)
            userDefaults.set(data, forKey: userDataKey)
            print("💾 Saved user data to UserDefaults")
        } catch {
            print("❌ Failed to save user data: \(error.localizedDescription)")
        }
    }
}
