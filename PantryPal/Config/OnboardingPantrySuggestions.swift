//
//  OnboardingPantrySuggestions.swift
//  PantryPal
//
//  Common pantry starters shown during first-run onboarding (multi-select).
//

import Foundation

struct OnboardingPantrySuggestion: Identifiable, Hashable {
    let id: String
    let generalName: String
    let quantity: String
}

enum OnboardingPantrySuggestions {
    static let all: [OnboardingPantrySuggestion] = [
        OnboardingPantrySuggestion(id: "eggs", generalName: "Eggs", quantity: "12"),
        OnboardingPantrySuggestion(id: "milk", generalName: "Milk", quantity: "1 gal"),
        OnboardingPantrySuggestion(id: "butter", generalName: "Butter", quantity: "1 lb"),
        OnboardingPantrySuggestion(id: "onion", generalName: "Yellow onion", quantity: "2"),
        OnboardingPantrySuggestion(id: "garlic", generalName: "Garlic", quantity: "1 bulb"),
        OnboardingPantrySuggestion(id: "olive_oil", generalName: "Olive oil", quantity: "1 bottle"),
        OnboardingPantrySuggestion(id: "salt", generalName: "Salt", quantity: "1"),
        OnboardingPantrySuggestion(id: "pepper", generalName: "Black pepper", quantity: "1"),
        OnboardingPantrySuggestion(id: "flour", generalName: "All-purpose flour", quantity: "5 lb"),
        OnboardingPantrySuggestion(id: "sugar", generalName: "Sugar", quantity: "1 bag"),
        OnboardingPantrySuggestion(id: "rice", generalName: "Rice", quantity: "2 lb"),
        OnboardingPantrySuggestion(id: "pasta", generalName: "Pasta", quantity: "1 lb"),
        OnboardingPantrySuggestion(id: "chicken", generalName: "Chicken breast", quantity: "2 lb"),
        OnboardingPantrySuggestion(id: "ground_beef", generalName: "Ground beef", quantity: "1 lb"),
        OnboardingPantrySuggestion(id: "cheese", generalName: "Cheddar cheese", quantity: "8 oz"),
        OnboardingPantrySuggestion(id: "yogurt", generalName: "Greek yogurt", quantity: "32 oz"),
        OnboardingPantrySuggestion(id: "bread", generalName: "Bread", quantity: "1 loaf"),
        OnboardingPantrySuggestion(id: "tomatoes", generalName: "Tomatoes", quantity: "4"),
        OnboardingPantrySuggestion(id: "potatoes", generalName: "Potatoes", quantity: "5 lb"),
        OnboardingPantrySuggestion(id: "carrots", generalName: "Carrots", quantity: "1 bag"),
        OnboardingPantrySuggestion(id: "spinach", generalName: "Spinach", quantity: "1 bag"),
        OnboardingPantrySuggestion(id: "lemons", generalName: "Lemons", quantity: "4"),
        OnboardingPantrySuggestion(id: "soy_sauce", generalName: "Soy sauce", quantity: "1 bottle"),
        OnboardingPantrySuggestion(id: "beans", generalName: "Black beans", quantity: "2 cans"),
        OnboardingPantrySuggestion(id: "broth", generalName: "Chicken broth", quantity: "32 oz"),
        OnboardingPantrySuggestion(id: "apples", generalName: "Apples", quantity: "6"),
        OnboardingPantrySuggestion(id: "bananas", generalName: "Bananas", quantity: "1 bunch"),
        OnboardingPantrySuggestion(id: "avocado", generalName: "Avocados", quantity: "4"),
        OnboardingPantrySuggestion(id: "bell_pepper", generalName: "Bell peppers", quantity: "3"),
        OnboardingPantrySuggestion(id: "celery", generalName: "Celery", quantity: "1 bunch"),
        OnboardingPantrySuggestion(id: "green_onion", generalName: "Green onions", quantity: "1 bunch"),
        OnboardingPantrySuggestion(id: "jalapeno", generalName: "Jalapeños", quantity: "4"),
        OnboardingPantrySuggestion(id: "bacon", generalName: "Bacon", quantity: "12 oz"),
        OnboardingPantrySuggestion(id: "chicken_thighs", generalName: "Chicken thighs", quantity: "2 lb"),
        OnboardingPantrySuggestion(id: "tuna", generalName: "Canned tuna", quantity: "4 cans"),
        OnboardingPantrySuggestion(id: "frozen_peas", generalName: "Frozen peas", quantity: "1 bag"),
        OnboardingPantrySuggestion(id: "parmesan", generalName: "Parmesan cheese", quantity: "8 oz"),
        OnboardingPantrySuggestion(id: "cream", generalName: "Heavy cream", quantity: "16 oz"),
        OnboardingPantrySuggestion(id: "tortillas", generalName: "Flour tortillas", quantity: "1 pack"),
        OnboardingPantrySuggestion(id: "oats", generalName: "Rolled oats", quantity: "18 oz"),
        OnboardingPantrySuggestion(id: "peanut_butter", generalName: "Peanut butter", quantity: "1 jar"),
        OnboardingPantrySuggestion(id: "honey", generalName: "Honey", quantity: "1 bottle"),
        OnboardingPantrySuggestion(id: "mayo", generalName: "Mayonnaise", quantity: "1 jar"),
        OnboardingPantrySuggestion(id: "mustard", generalName: "Dijon mustard", quantity: "1 jar"),
        OnboardingPantrySuggestion(id: "vinegar", generalName: "Apple cider vinegar", quantity: "16 oz"),
    ]
}
