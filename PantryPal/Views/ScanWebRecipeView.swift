//
//  ScanWebRecipeView.swift
//  Reciplease
//
//  Created by Cursor on 3/22/26.
//

import SwiftUI

struct ScanWebRecipeView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var hasSubmitted = false
    @FocusState private var isURLFieldFocused: Bool
    
    @State private var currentPage = 0
    private let totalPages = 1

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isURLValid: Bool {
        viewModel.isValidWebRecipeURL(trimmedURL)
    }

    private var showInlineValidation: Bool {
        hasSubmitted && !trimmedURL.isEmpty && !isURLValid
    }

    private var canSubmit: Bool {
        !trimmedURL.isEmpty && isURLValid && !viewModel.isScanningWebRecipes
    }

    var body: some View {
        PantryGenerateWizardShell(
            currentPage: currentPage,
            totalPages: totalPages,
            title: "What recipe would you like to import?",
            onBack: { },
            onCancel: {
                dismiss()
            },
            footerButtonTitle: viewModel.isScanningWebRecipes ? "Scanning…" : "Scan web page",
            footerButtonAction: {
                submit()
            },
            isFooterButtonDisabled: !canSubmit,
            isFooterButtonLoading: viewModel.isScanningWebRecipes,
            showSparklesOnLastPage: false
        ) {
            Group {
                switch currentPage {
                case 0:
                    urlPage
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
        }
        .onAppear {
            isURLFieldFocused = true
            viewModel.errorMessage = nil
        }
        .onChange(of: viewModel.shouldNavigateToCookbooks) { cookbookId in
            if cookbookId != nil {
                dismiss()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isScanningWebRecipes },
                set: { _ in }
            )
        ) {
            EnhancedLoadingView(
                progressStages: LoadingMessages.generateRecipesStages,
                funFacts: LoadingMessages.allFunFacts,
                estimatedDuration: 12.0,
                loadingImageName: "avi_magnifying_glass_animated"
            )
            .background(Color.pantryBackground.ignoresSafeArea())
        }
    }

    private var urlPage: some View {
        PantryGenerateSheetFormSection(
            title: nil,
            subtitle: "Paste the URL of the recipe you want to import",
            showsTrailingDivider: false
        ) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.pantryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                showInlineValidation ? Color(red: 1, green: 0.88, blue: 0.86) : Color.white.opacity(0.35),
                                lineWidth: 1
                            )
                    )

                TextField("https://example.com/recipe", text: $urlText)
                    .font(.pantryBody)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .focused($isURLFieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.pantryTextPrimary)
                    .onSubmit { submit() }
            }

            if showInlineValidation {
                Text("Please enter a valid URL starting with http:// or https://.")
                    .font(.pantryCaption)
                    .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
            }
        }
    }

    private func submit() {
        hasSubmitted = true
        viewModel.errorMessage = nil

        guard isURLValid else { return }
        Task {
            await viewModel.scanRecipesFromWebPage(urlString: trimmedURL)
        }
    }
}
