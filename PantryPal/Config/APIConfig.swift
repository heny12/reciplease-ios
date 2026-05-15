//
//  APIConfig.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct APIConfig {
    static let baseURL = AppConfig.recipeAPIBaseURL
    static let ingredientsEndpoint = "/api/recipe/ingredients/images"
    static let cookbookScanEndpoint = "/api/recipe/scan/cookbook"
    static let scanWebRecipeEndpoint = "/api/recipe/scan/url"
    static let recipesEndpoint = "/api/recipe/generate"
    static let mealPlanEndpoint = "/api/recipe/meal-plan"
    static let modifyRecipeEndpoint = "/api/recipe/modify"
    static let recipeImageEndpoint = "/api/recipe/image/generate"
    static let recipeEndpoint = "/api/recipe"
    static let insightsEndpoint = "/api/recipe/insights"
    static let nutritionEndpoint = "/api/recipe/nutrition"
    static let tipOfDayEndpoint = "/api/tip-of-day"
    
    static var ingredientsURL: URL {
        URL(string: baseURL + ingredientsEndpoint)!
    }
    
    static var recipesURL: URL {
        URL(string: baseURL + recipesEndpoint)!
    }

    static var mealPlanURL: URL {
        URL(string: baseURL + mealPlanEndpoint)!
    }

    static var cookbookScanURL: URL {
        URL(string: baseURL + cookbookScanEndpoint)!
    }

    static var scanWebRecipeURL: URL {
        URL(string: baseURL + scanWebRecipeEndpoint)!
    }
    
    static var modifyRecipeURL: URL {
        URL(string: baseURL + modifyRecipeEndpoint)!
    }
    
    static var recipeImageURL: URL {
        URL(string: baseURL + recipeImageEndpoint)!
    }
    
    static var recipeURL: URL {
        URL(string: baseURL + recipeEndpoint)!
    }
    
    static var insightsURL: URL {
        URL(string: baseURL + insightsEndpoint)!
    }

    static var nutritionURL: URL {
        URL(string: baseURL + nutritionEndpoint)!
    }
    
    static var tipOfDayURL: URL {
        URL(string: baseURL + tipOfDayEndpoint)!
    }
}
