//
//  RecipeAPIService.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

// MARK: - API Error Response

struct APIErrorResponse: Codable {
    let error: String
    let message: String?
    let code: String?
    /// Some routes return `error_code` instead of or in addition to `code`.
    let error_code: String?

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case code
        case error_code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? "error"
        message = try c.decodeIfPresent(String.self, forKey: .message)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        error_code = try c.decodeIfPresent(String.self, forKey: .error_code)
    }

    /// Prefer server `error_code`, then `code`, then top-level `error` string.
    var resolvedApiCode: String? {
        if let error_code, !error_code.isEmpty { return error_code }
        if let code, !code.isEmpty { return code }
        return error.isEmpty ? nil : error
    }
}

// MARK: - API Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String?, String?, QuotaExceededDetails?) // status code, error code, message, quota
    case clientError(Int, String?, String?, QuotaExceededDetails?) // status code, error code, message, quota
    case decodingError(Error)
    case networkError(Error)
    /// Client-side validation before calling the recipe API (e.g. nutrition / generate payload).
    case invalidIngredients(String)
    
    /// User-friendly error message based on API error codes
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "We couldn't reach our kitchen. Please check your connection and try again."
        case .invalidResponse:
            return "We received an unexpected response. Please try again."
        case .serverError(let statusCode, let errorCode, let message, let quota):
            return errorMessageForCode(statusCode: statusCode, errorCode: errorCode, message: message, quota: quota)
        case .clientError(let statusCode, let errorCode, let message, let quota):
            return errorMessageForCode(statusCode: statusCode, errorCode: errorCode, message: message, quota: quota)
        case .decodingError:
            return "We had trouble reading that recipe. Please try again."
        case .networkError(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return "No internet connection. Please check your network and try again."
            } else if (error as NSError).code == NSURLErrorTimedOut {
                return "Our chefs are taking a bit longer than usual. Please try again."
            }
            return "We're having trouble connecting. Please check your connection and try again."
        case .invalidIngredients(let message):
            return message
        }
    }
    
    /// Returns user-friendly error message based on API error code
    private func errorMessageForCode(statusCode: Int, errorCode: String?, message: String?, quota: QuotaExceededDetails? = nil) -> String {
        // Use specific error code if available, otherwise fall back to status code
        guard let errorCode = errorCode else {
            return genericErrorMessage(statusCode: statusCode)
        }
        
        switch errorCode {
        case "VALIDATION_ERROR":
            return "We couldn't understand that request. Please check your input and try again."
        case "INVALID_REQUEST":
            return "Something went wrong with that request. Please try again."
        case "CONTENT_BLOCKED":
            return "We couldn't process that content. Please try modifying your request."
        case "RATE_LIMIT":
            return "You're cooking up a storm! Please wait a moment before trying again."
        case "QUOTA_EXCEEDED":
            let snapshot = AllowanceSnapshot(
                remaining: quota?.remaining ?? 0,
                limit: quota?.limit ?? 0,
                isPro: false,
                resetAtMs: quota?.resetAtMs,
                serverMessage: quota?.message ?? message
            )
            if quota != nil || message != nil {
                return AllowanceCopy.detail(snapshot)
            }
            return "You've used this week's free recipe allowance."
        case "SERVICE_UNAVAILABLE":
            return "Our kitchen is temporarily closed. Please try again in a moment."
        case "PARSE_ERROR":
            return "We had trouble reading that recipe. Please try again."
        case "INTERNAL_ERROR":
            return "Something went wrong in our kitchen. Please try again later."
        default:
            // For unknown error codes, use generic message based on status code
            // Never expose raw API messages or error codes to users
            return genericErrorMessage(statusCode: statusCode)
        }
    }
    
    /// Returns generic error message based on HTTP status code
    /// Never exposes technical details like status codes or error codes to users
    private func genericErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "We couldn't understand that request. Please check your input and try again."
        case 401:
            return "We couldn't verify your request. Please try again."
        case 403:
            return "We couldn't access that resource. Please try again."
        case 404:
            return "We couldn't find what you're looking for. Please try again."
        case 429:
            return "You're cooking up a storm! Please wait a moment before trying again."
        case 413:
            return "That request was too large. Try fewer ingredients or shorter names."
        case 500:
            return "Something went wrong in our kitchen. Please try again later."
        case 502:
            return "Our kitchen is temporarily closed. Please try again in a moment."
        case 503:
            return "Our kitchen is temporarily closed. Please try again in a moment."
        case 504:
            return "Our chefs are taking a bit longer than usual. Please try again."
        default:
            // Generic message that doesn't expose status codes
            return "Something went wrong. Please try again later."
        }
    }
    
    /// Returns the API error code if available
    var quotaDetails: QuotaExceededDetails? {
        switch self {
        case .serverError(_, _, _, let quota), .clientError(_, _, _, let quota):
            return quota
        default:
            return nil
        }
    }

    var apiErrorCode: String? {
        switch self {
        case .serverError(_, let errorCode, _, _), .clientError(_, let errorCode, _, _):
            return errorCode
        case .invalidIngredients:
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Recipe API Service

class RecipeAPIService {
    static let shared = RecipeAPIService()
    
    private init() {}
    
    /// Creates an APIError from an HTTP response
    func handleHTTPError(statusCode: Int, data: Data) -> APIError {
        let responseBody = String(data: data, encoding: .utf8)
        
        // Try to parse the error response to extract error code and message
        var errorCode: String? = nil
        var errorMessage: String? = nil
        
        if let data = responseBody?.data(using: .utf8) {
            do {
                let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                errorCode = errorResponse.resolvedApiCode
                errorMessage = errorResponse.message
                print("📋 Parsed error code: \(errorCode ?? "none"), message: \(errorMessage ?? "none")")
            } catch {
                // If parsing fails, try to extract error code from JSON manually
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    errorCode = (json["error_code"] as? String)
                        ?? (json["code"] as? String)
                        ?? (json["error"] as? String)
                    errorMessage = json["message"] as? String
                }
            }
        }
        
        let quota = QuotaEnvelopeParser.parse(data: data)

        if (500...599).contains(statusCode) {
            print("🔴 Server Error (\(statusCode))")
            if let code = errorCode {
                print("   Error Code: \(code)")
            }
            if let body = responseBody {
                print("   Response: \(body)")
            }
            return .serverError(statusCode, errorCode, errorMessage, quota)
        } else if (400...499).contains(statusCode) {
            print("🟠 Client Error (\(statusCode))")
            if let code = errorCode {
                print("   Error Code: \(code)")
            }
            if let body = responseBody {
                print("   Response: \(body)")
            }
            return .clientError(statusCode, errorCode, errorMessage, quota)
        }
        
        return .clientError(statusCode, errorCode, errorMessage, quota)
    }
    
    // MARK: - Request Configuration
    
    /// Configures a URLRequest with common headers including device ID and App Check token
    func configureRequest(_ request: inout URLRequest) async {
        // Set Content-Type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add device ID for usage tracking and rate limiting
        let deviceID = DeviceIDManager.shared.deviceID
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        
        // Add App Check token. Proceed without one if App Check fails so the app does not crash.
        await AppCheckTokenProvider.attach(to: &request, logPrefix: "[RecipeAPI]")
        
        print("📱 Device ID header: \(deviceID)")
    }
    
    // MARK: - API Methods
    
    /// Detects ingredients from image URLs
    func detectIngredients(imageURLs: [String]) async throws -> [Ingredient] {
        let url = APIConfig.ingredientsURL
            print("🔍 Detecting ingredients from \(imageURLs.count) image(s)")
            print("🌐 API URL: \(url.absoluteString)")
            
            for (index, imageURL) in imageURLs.enumerated() {
                print("   [\(index + 1)] \(imageURL)")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 60 // Increase timeout for image processing
            
            let requestBody: [String: Any] = [
                "image_urls": imageURLs
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                print("📤 Sending request with \(imageURLs.count) image URL(s)...")
            } catch {
                print("❌ Failed to serialize request body: \(error.localizedDescription)")
                throw APIError.networkError(error)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
            
            do {
                let ingredientResponse = try JSONDecoder().decode(IngredientResponse.self, from: data)
                print("✅ Successfully decoded \(ingredientResponse.ingredients.count) ingredient(s)")
                return ingredientResponse.ingredients
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Decoding error. Response: \(responseString)")
                }
                print("❌ Decoding error: \(error.localizedDescription)")
                throw APIError.decodingError(error)
            }
    }
    
    /// Generates recipes from ingredients
    func generateRecipes(
        ingredients: [Ingredient],
        prompt: String? = nil,
        strictness: MealPlanStrictness? = nil
    ) async throws -> [Recipe] {
        let url = APIConfig.recipesURL
            print("🍳 Generating recipes from \(ingredients.count) ingredient(s)")
            print("🌐 API URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 90 // Recipes take longer to generate
            
            let ingredientsDict = ingredients.map { ingredient in
                var dict: [String: Any] = [
                    "generalName": ingredient.generalName
                ]
                if let specificName = ingredient.specificName {
                    dict["specificName"] = specificName
                }
                if let quantity = ingredient.quantity {
                    dict["quantity"] = quantity
                }
                return dict
            }
            
            var requestBody: [String: Any] = [
                "ingredients": ingredientsDict
            ]
            
            // Add prompt if provided
            if let prompt = prompt, !prompt.isEmpty {
                requestBody["prompt"] = prompt
                print("📝 Custom prompt: \(prompt)")
            }

            if let strictness {
                requestBody["strictness"] = strictness.rawValue
                print("🥫 Pantry strictness: \(strictness.rawValue)")
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 Sending recipe generation request...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
            
            do {
                // Debug: Print the raw JSON response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 API Response JSON: \(jsonString)")
                }
                
                let recipeResponse = try JSONDecoder().decode(RecipeResponse.self, from: data)
                
                // Debug: Print decoded recipes
                for recipe in recipeResponse.recipes {
                    print("📝 Decoded recipe: \(recipe.name)")
                    print("   - prepTimeMinutes: \(recipe.prepTimeMinutes?.description ?? "nil")")
                    print("   - cookTimeMinutes: \(recipe.cookTimeMinutes?.description ?? "nil")")
                    print("   - servings: \(recipe.servings?.description ?? "nil")")
                    print("   - difficulty: \(recipe.difficulty?.description ?? "nil")")
                }
                
                print("✅ Successfully generated \(recipeResponse.recipes.count) recipe(s)")
                return recipeResponse.recipes
            } catch {
                print("❌ Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: \(key.stringValue) at \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type) at \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type) at \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at \(context.codingPath)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                throw APIError.decodingError(error)
            }
    }

    /// Generates a structured meal plan from pantry ingredients (`POST /api/recipe/meal-plan`).
    /// Request `counts` includes breakfast, lunch, dinner, snack, and dessert; response returns matching recipe arrays.
    /// Same transport as `generateRecipes`: base URL, App Check, device ID, JSON body, shared HTTP errors.
    func generateMealPlan(_ mealPlanRequest: MealPlanRequest) async throws -> MealPlanResult {
        guard !mealPlanRequest.ingredients.isEmpty else {
            throw APIError.invalidIngredients("Add at least one ingredient to generate a meal plan.")
        }
        guard mealPlanRequest.counts.total > 0 else {
            throw APIError.invalidIngredients("Choose at least one meal slot to generate.")
        }

        let url = APIConfig.mealPlanURL
        print("🗓️ Meal plan request: \(mealPlanRequest.counts.total) total slots (b:\(mealPlanRequest.counts.breakfast) l:\(mealPlanRequest.counts.lunch) d:\(mealPlanRequest.counts.dinner) s:\(mealPlanRequest.counts.snack) dessert:\(mealPlanRequest.counts.dessert))")
        print("🌐 API URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 120

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(mealPlanRequest)
            print("📤 Sending meal plan request (\(mealPlanRequest.ingredients.count) ingredient(s))...")
        } catch {
            print("❌ Failed to encode meal plan request: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📥 Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 Meal plan response JSON (truncated): \(String(jsonString.prefix(2000)))")
            }
            let result = try JSONDecoder().decode(MealPlanResult.self, from: data)
            let n = result.allRecipes.count
            print("✅ Meal plan decoded \(n) recipe(s) (breakfast:\(result.breakfast.count) lunch:\(result.lunch.count) dinner:\(result.dinner.count) snack:\(result.snack.count) dessert:\(result.dessert.count))")
            return result
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Meal plan decoding error. Response: \(responseString.prefix(1500))")
            }
            print("❌ Meal plan decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    /// Convenience wrapper building `MealPlanRequest` from pantry ingredients (same shape as `generateRecipes`).
    func generateMealPlan(
        ingredients: [Ingredient],
        prompt: String? = nil,
        strictness: MealPlanStrictness? = nil,
        counts: MealTypeCounts
    ) async throws -> MealPlanResult {
        try await generateMealPlan(
            MealPlanRequest(ingredients: ingredients, prompt: prompt, strictness: strictness, counts: counts)
        )
    }

    /// Scans cookbook recipe photos and returns parsed recipes.
    func scanCookbookRecipes(imageURLs: [String]) async throws -> [Recipe] {
        let url = APIConfig.cookbookScanURL
            print("📚 Scanning cookbook recipes from \(imageURLs.count) image(s)")
            print("🌐 API URL: \(url.absoluteString)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 90

            let requestBody: [String: Any] = [
                "image_urls": imageURLs
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                print("📤 Sending cookbook scan request with \(imageURLs.count) image URL(s)...")
            } catch {
                print("❌ Failed to serialize cookbook scan request body: \(error.localizedDescription)")
                throw APIError.networkError(error)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            print("📥 Response status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            do {
                let recipeResponse = try JSONDecoder().decode(RecipeResponse.self, from: data)
                print("✅ Cookbook scan decoded \(recipeResponse.recipes.count) recipe(s)")
                return recipeResponse.recipes
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Cookbook scan decoding error. Response: \(responseString)")
                }
                print("❌ Cookbook scan decoding error: \(error.localizedDescription)")
                throw APIError.decodingError(error)
            }
    }

    /// Scans a recipe webpage URL and returns parsed recipes.
    func scanRecipesFromWebURL(urlString: String) async throws -> [Recipe] {
        let url = APIConfig.scanWebRecipeURL
            print("🌐 Scanning recipe webpage URL")
            print("🔗 Input URL: \(urlString)")
            print("🌐 API URL: \(url.absoluteString)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 90

            let requestBody: [String: Any] = [
                "url": urlString
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                print("📤 Sending web recipe scan request...")
            } catch {
                print("❌ Failed to serialize web recipe scan request body: \(error.localizedDescription)")
                throw APIError.networkError(error)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            print("📥 Response status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            do {
                let recipeResponse = try JSONDecoder().decode(RecipeResponse.self, from: data)
                print("✅ Web recipe scan decoded \(recipeResponse.recipes.count) recipe(s)")
                return recipeResponse.recipes
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Web recipe scan decoding error. Response: \(responseString)")
                }
                print("❌ Web recipe scan decoding error: \(error.localizedDescription)")
                throw APIError.decodingError(error)
            }
    }
    
    /// Fetches pantry insights for the given ingredients
    func fetchInsights(ingredients: [Ingredient]) async throws -> [String] {
        let url = APIConfig.insightsURL
        print("💡 Fetching pantry insights for \(ingredients.count) ingredient(s)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 30
        
        let ingredientsDict = ingredients.map { ingredient in
            var dict: [String: Any] = [
                "generalName": ingredient.generalName
            ]
            if let specificName = ingredient.specificName {
                dict["specificName"] = specificName
            }
            if let quantity = ingredient.quantity {
                dict["quantity"] = quantity
            }
            return dict
        }
        
        let requestBody: [String: Any] = [
            "ingredients": ingredientsDict
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        struct InsightsResponse: Codable {
            let insights: [String]
        }
        
        let decoded = try JSONDecoder().decode(InsightsResponse.self, from: data)
        print("✅ Received \(decoded.insights.count) insight(s)")
        return decoded.insights
    }

    /// Builds the `ingredients` array for `/generate` and `/insights` (pantry-style payload).
    private func recipeRequestIngredientsPayload(_ ingredients: [Ingredient]) -> [[String: Any]] {
        ingredients.map { ingredient in
            var dict: [String: Any] = [
                "generalName": ingredient.generalName
            ]
            if let specificName = ingredient.specificName {
                dict["specificName"] = specificName
            }
            if let quantity = ingredient.quantity {
                dict["quantity"] = quantity
            }
            return dict
        }
    }

    /// Client-side checks for `/api/recipe/nutrition` when the body includes a full `recipe` object.
    func validateRecipeForNutritionRequest(_ recipe: Recipe) -> String? {
        let lines = recipe.nonEmptyRecipeIngredientLines
        guard !lines.isEmpty else {
            return "Add at least one ingredient first."
        }
        guard lines.count <= AppConfig.maxIngredients else {
            return "You can have at most \(AppConfig.maxIngredients) ingredients."
        }
        for line in lines {
            guard line.name.count <= AppConfig.maxIngredientNameLength else {
                return "Each ingredient name can be at most \(AppConfig.maxIngredientNameLength) characters."
            }
        }
        return nil
    }

    /// JSON object for the nested `recipe` field (modify + nutrition endpoints).
    private func recipeJSONObjectForNestedRecipePayload(_ recipe: Recipe) -> [String: Any] {
        var recipeDict: [String: Any] = [
            "name": recipe.name,
            "description": recipe.description,
            "ingredients": recipe.ingredients.map { [
                "name": $0.name,
                "quantity": $0.quantity
            ]},
            "steps": recipe.steps
        ]
        if let prep = recipe.prepTimeMinutes { recipeDict["prepTimeMinutes"] = prep }
        if let cook = recipe.cookTimeMinutes { recipeDict["cookTimeMinutes"] = cook }
        if let servings = recipe.servings { recipeDict["servings"] = servings }
        if let difficulty = recipe.difficulty { recipeDict["difficulty"] = difficulty }
        recipeDict["id"] = recipe.id.uuidString
        if let tips = recipe.tips, !tips.isEmpty {
            recipeDict["tips"] = tips
        }
        if let source = recipe.source {
            var sourceDict: [String: Any] = ["name": source.name]
            if let url = source.url { sourceDict["url"] = url }
            recipeDict["source"] = sourceDict
        }
        if let imageURL = recipe.imageURL, !imageURL.isEmpty {
            recipeDict["imageURL"] = imageURL
        }
        return recipeDict
    }

    /// Estimates nutrition totals from a full recipe payload (LLM + USDA; may be slow on first request).
    func fetchNutritionTotals(recipe: Recipe, prompt: String? = nil) async throws -> PantryNutritionResult {
        if let message = validateRecipeForNutritionRequest(recipe) {
            throw APIError.invalidIngredients(message)
        }

        let url = APIConfig.nutritionURL
        print("🥗 Fetching nutrition totals for recipe: \(recipe.name) (\(recipe.nonEmptyRecipeIngredientLines.count) ingredient lines)")
        print("🌐 API URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 120

        var requestBody: [String: Any] = [
            "recipe": recipeJSONObjectForNestedRecipePayload(recipe)
        ]
        if let prompt = prompt, !prompt.isEmpty {
            requestBody["prompt"] = prompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        print("📤 Sending nutrition request (full recipe body)...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📥 Nutrition response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoded = try JSONDecoder().decode(RecipeNutritionAPIResponse.self, from: data)
            print("✅ Decoded nutrition response (disclaimer length: \(decoded.disclaimer?.count ?? 0))")
            return PantryNutritionResult(api: decoded)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Nutrition decoding error. Response: \(responseString)")
            }
            print("❌ Nutrition decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }
    
    /// Modifies a recipe based on user prompt
    func modifyRecipe(recipe: Recipe, prompt: String) async throws -> Recipe {
        let url = APIConfig.modifyRecipeURL
            print("✏️ Modifying recipe: \(recipe.name)")
            print("🌐 API URL: \(url.absoluteString)")
            print("📝 Modification prompt: \(prompt)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 60

            var requestBody: [String: Any] = [
                "recipe": recipeJSONObjectForNestedRecipePayload(recipe),
                "prompt": prompt
            ]
            let exclusions = DietaryConstraint.wireExclusions(from: RecipeGenerationFormOptionData.preferredDietaryIdsFromStorage())
            if !exclusions.isEmpty {
                requestBody["dietaryExclusions"] = exclusions
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 Sending recipe modification request...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
            
            do {
                let modifiedRecipe = try JSONDecoder().decode(Recipe.self, from: data)
                print("✅ Successfully modified recipe: \(modifiedRecipe.name)")
                return modifiedRecipe
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Decoding error. Response: \(responseString)")
                }
                print("❌ Decoding error: \(error.localizedDescription)")
                throw APIError.decodingError(error)
            }
    }
    
    /// Generates an image for a recipe
    func generateRecipeImage(recipe: Recipe) async throws -> String {
        let url = APIConfig.recipeImageURL
            print("🖼️ Generating image for recipe: \(recipe.name)")
            print("🌐 API URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            await self.configureRequest(&request)
            request.timeoutInterval = 120 // Image generation can take a while
            
            var requestBody: [String: Any] = [
                "name": recipe.name,
                "description": recipe.description,
                "ingredients": recipe.ingredients.map { [
                    "name": $0.name,
                    "quantity": $0.quantity
                ]},
                "steps": recipe.steps
            ]

            // Include recipe id so the backend can correlate image generations.
            requestBody["id"] = recipe.id.uuidString
            
            print("📤 Request body - Ingredients count: \(recipe.ingredients.count)")
            print("📤 Request body - Steps count: \(recipe.steps.count)")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("📡 Sending request to image generation API...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw self.handleHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
            
            do {
                let imageResponse = try JSONDecoder().decode(RecipeImageResponse.self, from: data)
                print("📥 Decoded response - image_urls count: \(imageResponse.image_urls.count)")
                guard let imageURL = imageResponse.image_urls.first, !imageURL.isEmpty else {
                    print("❌ No image URLs in response or URL is empty")
                    throw APIError.invalidResponse
                }
                print("✅ Image URL extracted: \(imageURL)")
                return imageURL
            } catch let error as APIError {
                throw error
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Decoding error. Response: \(responseString)")
                }
                print("❌ Decoding error: \(error.localizedDescription)")
                throw APIError.decodingError(error)
            }
    }
    
    /// Fetches the tip of the day. Pass a date in BASIC_ISO_DATE format (yyyyMMdd), or nil for today.
    func fetchTipOfDay(date: String? = nil) async throws -> TipOfDay {
        let url = APIConfig.tipOfDayURL
        print("💡 Fetching tip of day")
        print("🌐 API URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 15
        
        let requestBody = TipOfDayRequest(date: date)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        do {
            let tip = try JSONDecoder().decode(TipOfDay.self, from: data)
            print("✅ Tip of day: \(tip.title)")
            return tip
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Tip of day decoding error. Response: \(responseString)")
            }
            throw APIError.decodingError(error)
        }
    }

    struct TonightMenuFetchResult {
        var sessionId: String?
        var pitches: [RecipePitch]
        var expandedByPitchId: [String: Recipe]
        var usedV1Fallback: Bool
        var status: String?
        var reasonCodes: [String]
    }

    /// Asks for pitch cards. A 404 on `/api/v2/recipe/pitches` falls back to `/api/recipe/generate`.
    func fetchTonightMenu(_ wire: TonightMenuWireRequest) async throws -> TonightMenuFetchResult {
        var request = URLRequest(url: APIConfig.recipePitchesURL)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(wire)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 404 {
            print("↩️ Pitches endpoint returned 404. Falling back to /api/recipe/generate")
            return try await fetchTonightMenuLegacy(wire.withCount(5))
        }
        guard (200...299).contains(http.statusCode) else {
            throw handleHTTPError(statusCode: http.statusCode, data: data)
        }
        let decoded = try JSONDecoder().decode(PitchDeckResponse.self, from: data)
        let sessionId = decoded.sessionId ?? wire.sessionId
        return TonightMenuFetchResult(
            sessionId: sessionId,
            pitches: decoded.pitches,
            expandedByPitchId: [:],
            usedV1Fallback: false,
            status: decoded.status,
            reasonCodes: decoded.reasonCodes
        )
    }

    func expandPitch(
        sessionId: String?,
        pitch: RecipePitch,
        wire: TonightMenuWireRequest
    ) async throws -> (recipe: Recipe, cached: Bool) {
        var body: [String: Any] = [
            "pitchId": pitch.pitchId,
            "pitch": [
                "pitchId": pitch.pitchId,
                "lane": pitch.lane as Any,
                "title": pitch.title,
                "hook": pitch.hook as Any,
                "totalTimeMinutes": pitch.totalTimeMinutes as Any,
                "prepTimeMinutes": pitch.prepTimeMinutes as Any,
                "cookTimeMinutes": pitch.cookTimeMinutes as Any,
                "difficulty": pitch.difficulty as Any,
                "servings": pitch.servings as Any,
                "cuisine": pitch.cuisine as Any,
                "technique": pitch.technique as Any,
                "pantryIngredientsUsed": pitch.pantryIngredientsUsed,
                "staplesUsed": pitch.staplesUsed,
                "extraIngredients": pitch.extraIngredients
            ]
        ]
        if let sessionId { body["sessionId"] = sessionId }
        body["strictness"] = wire.strictness
        body["dietaryExclusions"] = wire.dietaryExclusions
        body["confirmedStaples"] = wire.confirmedStaples
        body["ingredients"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(wire.ingredients))
        if let servings = wire.servings { body["servings"] = servings }

        var request = URLRequest(url: APIConfig.recipeExpandURL)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw handleHTTPError(statusCode: http.statusCode, data: data)
        }
        if let envelope = try? JSONDecoder().decode(ExpandRecipeResponse.self, from: data) {
            return (envelope.recipe, envelope.cached ?? false)
        }
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        return (recipe, false)
    }

    private func fetchTonightMenuLegacy(_ wire: TonightMenuWireRequest) async throws -> TonightMenuFetchResult {
        var request = URLRequest(url: APIConfig.recipesURL)
        request.httpMethod = "POST"
        await configureRequest(&request)
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(wire)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard GenerationCreditPolicy.shouldConsumeCredit(httpStatus: http.statusCode) else {
            throw handleHTTPError(statusCode: http.statusCode, data: data)
        }
        let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)
        var pitches: [RecipePitch] = []
        var expanded: [String: Recipe] = [:]
        for recipe in decoded.recipes {
            let pitch = recipe.pitchCard()
            pitches.append(pitch)
            expanded[pitch.pitchId] = recipe
        }
        return TonightMenuFetchResult(
            sessionId: nil,
            pitches: pitches,
            expandedByPitchId: expanded,
            usedV1Fallback: true,
            status: pitches.isEmpty ? "limited" : "ok",
            reasonCodes: pitches.isEmpty ? ["no_recipes"] : []
        )
    }
}

// MARK: - Response Types

struct RecipeImageResponse: Codable {
    let image_urls: [String]
}
