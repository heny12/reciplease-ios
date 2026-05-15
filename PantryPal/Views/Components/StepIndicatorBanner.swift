//
//  StepIndicatorBanner.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI

struct StepIndicatorBanner: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitle: String
    let stepDescription: String
    let actionRequired: Bool
    let actionText: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(actionRequired ? Color.pantrySecondary : Color.pantryPrimary)
                    .frame(width: 32, height: 32)
                
                Text("\(currentStep)")
                    .font(.pantryCaption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Step \(currentStep) of \(totalSteps)")
                        .font(.pantryCaption)
                        .fontWeight(.medium)
                        .foregroundColor(.pantryTextSecondary)
                    
                    if actionRequired, let actionText = actionText {
                        Text("•")
                            .font(.pantryCaption)
                            .foregroundColor(.pantryTextSecondary)
                        
                        Text(actionText)
                            .font(.pantryCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantrySecondary)
                    }
                }
                
                Text(stepTitle)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 6) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.pantryPrimary : Color.pantryTextSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pantrySurface)
                .shadow(color: Color.pantryShadow.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Compact Progress Bar

struct CompactProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.pantryTextSecondary.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        StepIndicatorBanner(
            currentStep: 1,
            totalSteps: 3,
            stepTitle: "Scan Your Ingredients",
            stepDescription: "Take photos of your fridge or pantry",
            actionRequired: true,
            actionText: "Add photos to continue"
        )
        
        StepIndicatorBanner(
            currentStep: 2,
            totalSteps: 3,
            stepTitle: "Review Your Pantry",
            stepDescription: "Confirm and edit detected ingredients",
            actionRequired: false,
            actionText: nil
        )
        
        StepIndicatorBanner(
            currentStep: 3,
            totalSteps: 3,
            stepTitle: "Generate Recipes",
            stepDescription: "Get personalized recipe suggestions",
            actionRequired: true,
            actionText: "Tap Generate Recipes"
        )
    }
    .padding()
    .background(Color.pantryBackground)
}
