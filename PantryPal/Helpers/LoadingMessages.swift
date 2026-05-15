//
//  LoadingMessages.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
import SwiftUI
import Combine

class LoadingMessageManager: ObservableObject {
    @Published var currentMessage: String = ""
    
    private var messages: [String] = []
    private var timer: Timer?
    private var currentIndex = 0
    
    init(messages: [String]) {
        self.messages = messages
        if !messages.isEmpty {
            self.currentMessage = messages[0]
        }
    }
    
    func start() {
        guard messages.count > 1 else { return }
        
        timer?.invalidate()
        currentIndex = Int.random(in: 0..<messages.count)
        currentMessage = messages[currentIndex]
        
        timer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Randomly select a different message
                var nextIndex = self.currentIndex
                while nextIndex == self.currentIndex && self.messages.count > 1 {
                    nextIndex = Int.random(in: 0..<self.messages.count)
                }
                self.currentIndex = nextIndex
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.currentMessage = self.messages[self.currentIndex]
                }
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct LoadingMessages {
    // Progress stages for ingredient detection - duration scales with image count
    // Base duration: 20 seconds for 1 image, +10 seconds per additional image
    static func detectIngredientsStages(imageCount: Int) -> (stages: [(stage: String, time: Double)], duration: Double) {
        let baseDuration: Double = 20.0
        let additionalDurationPerImage: Double = 5.0
        let totalDuration = baseDuration + (Double(max(0, imageCount - 1)) * additionalDurationPerImage)
        
        // Calculate stage intervals (4 stages total)
        let stageInterval = totalDuration / 4.0
        
        let stages: [(stage: String, time: Double)] = [
            ("Analyzing images...", 0.0),
            ("Identifying ingredients...", stageInterval),
            ("Organizing your pantry...", stageInterval * 2.0),
            ("Almost done...", stageInterval * 3.0)
        ]
        
        return (stages, totalDuration)
    }
    
    
    // Progress stages for recipe generation (20 seconds total, ~5 seconds per stage)
    static let generateRecipesStages: [(stage: String, time: Double)] = [
        ("Cooking up ideas...", 0.0),
        ("Finding perfect recipes...", 3.0),
        ("Crafting combinations...", 6.0),
        ("Almost ready...", 10.0)
    ]
    
    
    // Progress stages for recipe modification (5 seconds total, ~1.25 seconds per stage)
    static let modifyRecipeStages: [(stage: String, time: Double)] = [
        ("Adjusting recipe...", 0.0),
        ("Crafting changes...", 1.25),
        ("Personalizing...", 2.5),
        ("Almost ready...", 3.75)
    ]
    
    static let allFunFacts: [String] = [
        "Did you know: Tomatoes are actually a fruit!",
        "Fun fact: Honey never spoils!",
        "Did you know: Bananas are berries!",
        "Fun fact: Carrots were originally purple!",
        "Did you know: Peanuts are legumes, not nuts!",
        "Fun fact: Strawberries aren't actually berries!",
        "Did you know: Avocados are technically berries!",
        "Fun fact: Pineapples take 2-3 years to grow!",
        "Did you know: Apples float because 25% of their volume is air!",
        "Fun fact: Cucumbers are 96% water!",
        "Did you know: Bell peppers have more vitamin C than oranges!",
        "Fun fact: Potatoes were the first vegetable grown in space!",
        "Did you know: Onions release a gas that makes you cry!",
        "Fun fact: Garlic can improve your memory!",
        "Did you know: Spinach has more iron than most meats!",
        "Fun fact: Broccoli contains more protein than steak!",
        "Did you know: Watermelons are 92% water!",
        "Fun fact: Lemons can power a small LED light!",
        "Did you know: One corn kernel has one strand of silk!",
        "Fun fact: Eggplants are technically berries!",
        "Did you know: The world's largest fruit is the jackfruit!",
        "Fun fact: Mushrooms are more closely related to humans than plants!",
        "Did you know: A single strawberry has about 200 seeds!",
        "Fun fact: Celery has negative calories!",
        "Did you know: The world's hottest pepper is 2.2 million Scoville units!",
        "Fun fact: One head of lettuce contains 95% water!",
        "Did you know: Asparagus can make your urine smell!",
        "Fun fact: The average person eats 35 tons of food in their lifetime!",
        "Did you know: Radishes are 95% water!",
        "Fun fact: Artichokes are actually flower buds!",
        "Did you know: The world's smallest fruit is the Wolffia!",
        "Fun fact: Cauliflower is just white broccoli!",
        "Did you know: Zucchinis are technically fruits!",
        "Fun fact: The world's most expensive spice is saffron!",
        "Did you know: One pomegranate can have over 600 seeds!",
        "Fun fact: Beets can turn your urine pink!",
        "Did you know: The world's largest vegetable is a pumpkin!",
        "Fun fact: Kale is one of the most nutrient-dense foods!",
        "Did you know: Brussels sprouts are named after Brussels, Belgium!",
        "Did you know: The oldest recipe is 4,000 years old!",
        "Fun fact: Chocolate chip cookies were invented by accident!",
        "Did you know: Pizza was originally a breakfast food!",
        "Fun fact: The first cookbook was written in 62 AD!",
        "Did you know: The word 'restaurant' means 'restore' in French!",
        "Fun fact: Sushi means 'sour rice' in Japanese!",
        "Did you know: The Caesar salad was invented in Mexico!",
        "Fun fact: Fortune cookies were invented in America, not China!",
        "Did you know: The sandwich was named after the Earl of Sandwich!",
        "Fun fact: Macaroni and cheese was Thomas Jefferson's favorite!",
        "Did you know: The first ice cream cone was made in 1904!",
        "Fun fact: Pasta was brought to Italy by Marco Polo!",
        "Did you know: The croissant was invented in Austria, not France!",
        "Fun fact: The first recipe for chocolate cake was in 1764!",
        "Did you know: The word 'chef' comes from 'chief'!",
        "Fun fact: The first restaurant opened in Paris in 1765!",
        "Did you know: The world's oldest known recipe is for beer!",
        "Fun fact: The first recipe website had 1,000 recipes in 1993!",
        "Did you know: The word 'gourmet' means 'wine taster' in French!",
        "Fun fact: The first cookbook in English was published in 1390!",
        "Did you know: The world's most expensive meal costs $2,000!",
        "Fun fact: The first food truck was a horse-drawn wagon in 1866!",
        "Did you know: The word 'cuisine' means 'kitchen' in French!",
        "Fun fact: The first frozen food was sold in 1930!",
        "Did you know: The world's largest pizza was 13,580 square feet!",
        "Fun fact: The first recipe app was created in 2008!",
        "Did you know: The word 'appetizer' comes from 'appetite'!",
        "Fun fact: The first food blog was started in 1997!",
        "Did you know: The world's longest noodle was 3,084 feet long!",
        "Fun fact: The first recipe video was posted in 2005!",
        "Did you know: The word 'dessert' means 'to clear the table'!",
        "Fun fact: The first food delivery service started in 1922!",
        "Did you know: The world's largest burger weighed 2,014 pounds!",
        "Fun fact: The first cooking show was 'The French Chef' in 1963!",
        "Did you know: The word 'brunch' combines breakfast and lunch!",
        "Fun fact: The first recipe book sold 1 million copies!",
        "Did you know: The world's most expensive spice costs $5,000 per pound!",
        "Fun fact: The first food emoji was the pizza emoji in 2010!",
        "Did you know: The word 'supper' comes from 'soup'!",
        "Fun fact: The first recipe search engine launched in 1999!",
        "Did you know: Recipes have been shared for thousands of years!",
        "Fun fact: The word 'recipe' comes from Latin meaning 'take'!",
        "Did you know: Recipe sharing dates back to ancient Mesopotamia!",
        "Fun fact: The first written recipes were on clay tablets!",
        "Did you know: Recipes were originally passed down orally!",
        "Fun fact: The oldest cookbook still in use is from 1st century AD!",
        "Did you know: Cooking is one of the oldest human activities!",
        "Fun fact: The word 'cook' comes from Latin 'coquus'!",
        "Did you know: Recipes help preserve cultural traditions!",
        "Fun fact: The first TV cooking show aired in 1946!",
    ]
}
