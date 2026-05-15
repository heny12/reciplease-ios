//
//  FeedbackFormView.swift
//  Reciplease
//
//  Created by Henry Chipman on 2/13/26.
//

import SwiftUI

enum FeedbackType: String {
    case feedback = "feedback"
    case bug = "bug"
    case feature = "feature"
    
    var title: String {
        switch self {
        case .feedback:
            return "Submit Feedback"
        case .bug:
            return "Report a Bug"
        case .feature:
            return "Suggest a Feature"
        }
    }
    
    var subtitle: String {
        switch self {
        case .feedback:
            return "We'd love to hear from you!"
        case .bug:
            return "We apologize for the inconvenience. Please describe the bug you encountered and include steps to reproduce if possible."
        case .feature:
            return "We value your input. Please share your ideas for making Reciplease even better!"
        }
    }
    
    var placeholder: String {
        switch self {
        case .feedback:
            return "Tell us what you think about Reciplease..."
        case .bug:
            return "Describe the bug you encountered. Include steps to reproduce if possible..."
        case .feature:
            return "What feature would you like to see in Reciplease?..."
        }
    }
    
    var icon: String {
        switch self {
        case .feedback:
            return "envelope.fill"
        case .bug:
            return "exclamationmark.triangle.fill"
        case .feature:
            return "lightbulb.fill"
        }
    }
}

struct FeedbackFormView: View {
    let feedbackType: FeedbackType
    @Environment(\.dismiss) private var dismiss
    
    @State private var content: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    
    private let maxCharacterCount = 2000
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.pantryBackground
                    .ignoresSafeArea()
                
                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle(feedbackType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if !showSuccess {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Submit") {
                            submitFeedback()
                        }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        .opacity(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting ? 0.6 : 1.0)
                    }
                }
            }
        }
    }
    
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                // Header
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: feedbackType.icon)
                        .font(.pantryTitle2.weight(.semibold))
                        .foregroundColor(feedbackType == .bug ? .red : (feedbackType == .feature ? .yellow : .blue))
                    
                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        Text(feedbackType.title)
                            .font(.pantryHeadline)
                            .foregroundColor(.pantryTextPrimary)
                        
                        Text(feedbackType.subtitle)
                            .font(.pantrySubheadline)
                            .foregroundColor(.pantryTextSecondary)
                    }
                }
                .padding(.horizontal, LayoutHelpers.horizontalPadding)
                .padding(.top, DesignTokens.spacingLG)
                
                // Text Editor
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text(feedbackType.placeholder)
                                .font(.pantryBody)
                                .foregroundColor(.pantryTextSecondary.opacity(0.6))
                                .padding(.horizontal, DesignTokens.spacingMD)
                                .padding(.vertical, DesignTokens.spacingLG)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $content)
                            .font(.pantryBody)
                            .foregroundColor(.pantryTextPrimary)
                            .frame(minHeight: 200)
                            .padding(DesignTokens.spacingSM)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color.pantrySurface)
                    .cornerRadius(DesignTokens.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .stroke(content.isEmpty ? Color.pantryTextSecondary.opacity(0.2) : Color.pantryPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(isSubmitting)
                    
                    HStack {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.pantryCaption)
                                .foregroundColor(.red)
                        } else {
                            Spacer()
                        }
                        
                        Text("\(content.count)/\(maxCharacterCount)")
                            .font(.pantryCaption)
                            .foregroundColor(content.count > maxCharacterCount ? .red : .pantryTextSecondary)
                    }
                }
                .padding(.horizontal, LayoutHelpers.horizontalPadding)
                
                // Info Section
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "info.circle.fill")
                            .font(.pantryCustom(size: DesignTokens.iconSmall, weight: .medium))
                            .foregroundColor(.pantryPrimary)
                        
                        Text("Your feedback helps us improve Reciplease")
                            .font(.pantryCaption)
                            .foregroundColor(.pantryTextSecondary)
                    }
                    
                    if feedbackType == .bug {
                        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.pantrySubheadline.weight(.medium))
                                .foregroundColor(.pantryPrimary)
                                .padding(.top, 2)
                            
                            Text("Please include steps to reproduce the bug if possible")
                                .font(.pantrySubheadline)
                                .foregroundColor(.pantryTextSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, LayoutHelpers.horizontalPadding)
                .padding(.top, DesignTokens.spacingSM)
                
                Spacer(minLength: 40)
            }
        }
        .overlay {
            if isSubmitting {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.pantryPrimary)
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.pantryCustom(size: 64, weight: .regular))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Thank You!")
                    .font(.pantryTitle)
                    .foregroundColor(.pantryTextPrimary)
                
                Text("Your \(feedbackType == .bug ? "bug report" : feedbackType == .feature ? "feature suggestion" : "feedback") has been submitted successfully.")
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LayoutHelpers.horizontalPadding)
            }
            
            Spacer()
            
            // Close Button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.pantryPrimary, Color.pantrySecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, LayoutHelpers.horizontalPadding)
            .padding(.bottom, 40)
        }
    }
    
    private func submitFeedback() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else {
            errorMessage = "Please enter your feedback"
            return
        }
        
        guard trimmedContent.count <= maxCharacterCount else {
            errorMessage = "Feedback must be \(maxCharacterCount) characters or less"
            return
        }
        
        errorMessage = nil
        isSubmitting = true
        HapticFeedback.light()
        
        Task {
            await UserService.shared.submitFeedback(
                type: feedbackType.rawValue,
                content: trimmedContent
            )
            
            await MainActor.run {
                isSubmitting = false
                HapticFeedback.success()
                
                switch feedbackType {
                case .feedback:
                    AppAnalytics.log(.feedbackSubmitted, parameters: [
                        "content_length": trimmedContent.count
                    ])
                case .bug:
                    AppAnalytics.log(.bugReported, parameters: [
                        "content_length": trimmedContent.count
                    ])
                case .feature:
                    AppAnalytics.log(.featureSuggested, parameters: [
                        "content_length": trimmedContent.count
                    ])
                }
                
                // Show success view after a brief delay
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSuccess = true
                }
            }
        }
    }
}

#Preview {
    FeedbackFormView(feedbackType: .feedback)
}
