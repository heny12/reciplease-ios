//
//  CookbookRecipeScanView.swift
//  Reciplease
//
//  Created by Cursor on 3/22/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct CookbookRecipeScanView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss

    private let maxPhotosAllowed: Int = 4

    @State private var activePickerSource: ImagePickerSource?
    @State private var cameraCaptureRequest = 0
    @State private var showingTipsSheet = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var captureControls: some View {
        HStack {
            Button {
                HapticFeedback.light()
                activePickerSource = .library
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.pantryCustom(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                guard isCameraAvailable, viewModel.selectedImages.count < maxPhotosAllowed else {
                    return
                }
                HapticFeedback.medium()
                cameraCaptureRequest += 1
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(
                            viewModel.selectedImages.count >= maxPhotosAllowed
                                ? Color.white.opacity(0.35) : Color.white.opacity(0.95)
                        )
                        .frame(width: 58, height: 58)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isCameraAvailable || viewModel.selectedImages.count >= maxPhotosAllowed)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                if viewModel.selectedImages.count >= maxPhotosAllowed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.pantryCustom(size: 22))
                        .foregroundColor(.pantrySuccess)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var scanButton: some View {
        Button {
            HapticFeedback.medium()
            Task {
                await viewModel.scanCookbookRecipesFromSelectedImages()
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isScanningCookbookRecipes {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "book.pages")
                        .font(.pantryCustom(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(viewModel.isScanningCookbookRecipes ? "Scanning..." : "Scan Cookbook Recipe")
                        .font(.pantryHeadline)
                        .fontWeight(.semibold)
                    if viewModel.selectedImages.count > 0 {
                        Text("Scanning \(viewModel.selectedImages.count) photo\(viewModel.selectedImages.count == 1 ? "" : "s")")
                            .font(.pantrySubheadline)
                            .opacity(0.9)
                    } else {
                        Text("Add at least one photo")
                            .font(.pantrySubheadline)
                            .opacity(0.9)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .foregroundColor(.white)
            .background(
                (viewModel.isScanningCookbookRecipes || !viewModel.allImagesUploaded)
                    ? Color.gray.opacity(0.35)
                    : Color.pantryPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LayoutHelpers.horizontalPadding)
        .disabled(!viewModel.allImagesUploaded || viewModel.isScanningCookbookRecipes)
    }

    var body: some View {
        ZStack {
            Group {
                if isCameraAvailable {
                    FullScreenCameraView(captureTrigger: $cameraCaptureRequest) { image in
                        Task { @MainActor in
                            viewModel.addImage(image)
                        }
                    }
                } else {
                    Color.black
                    VStack(spacing: 10) {
                        Image(systemName: "camera.slash.fill")
                            .font(.pantryTitle)
                            .foregroundColor(.white.opacity(0.9))
                        Text("Camera unavailable")
                            .font(.pantryHeadline)
                            .foregroundColor(.white)
                        Text("Use Library to add photos.")
                            .font(.pantrySubheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(viewModel.selectedImages.count)/\(maxPhotosAllowed)")
                            .font(.pantrySubheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(10)

                        Button {
                            HapticFeedback.light()
                            showingTipsSheet = true
                        } label: {
                            HStack(spacing: DesignTokens.spacingSM) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.pantrySubheadline.weight(.semibold))
                                Text("Tips")
                                    .font(.pantrySubheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignTokens.spacingMD)
                            .padding(.vertical, DesignTokens.spacingSM)
                            .background(Color.pantryPrimary.opacity(0.9))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    if !viewModel.selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.element.id) { index, imageWithURL in
                                    PhotoThumbnailItem(
                                        imageWithURL: imageWithURL,
                                        onRemove: {
                                            HapticFeedback.light()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                viewModel.removeImage(at: index)
                                            }
                                        }
                                    ) {}
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 86)
                    }

                    captureControls
                    scanButton

                    if !viewModel.allImagesUploaded && !viewModel.selectedImages.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Uploading photos...")
                                .font(.pantryCaption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(
                    Color.black.opacity(0.25)
                        .overlay(
                            Rectangle()
                                .fill(.ultraThinMaterial.opacity(0.15))
                        )
                )
            }
        }
        .onAppear {
            // Always start this flow with a clean photo selection.
            viewModel.selectedImages = []
            viewModel.errorMessage = nil
            viewModel.showNoRecipesAlert = false
        }
        .onChange(of: viewModel.shouldNavigateToCookbooks) { cookbookId in
            if cookbookId != nil {
                dismiss()
            }
        }
        .sheet(item: $activePickerSource) { source in
            switch source {
            case .camera:
                ImagePicker(viewModel: viewModel, sourceType: .camera, onDismiss: { activePickerSource = nil })
            case .library:
                PhotoLibraryPicker(viewModel: viewModel, maxPhotosAllowed: maxPhotosAllowed, onDismiss: { activePickerSource = nil })
            }
        }
        .sheet(isPresented: $showingTipsSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                        Text("Tips for best results")
                            .font(.pantryTitle3)
                            .fontWeight(.semibold)
                            .foregroundColor(.pantryTextPrimary)

                        TipRow(icon: "camera.viewfinder", text: "Capture full recipe pages clearly")
                        TipRow(icon: "text.viewfinder", text: "Keep text sharp and in focus")
                        TipRow(icon: "sun.max.fill", text: "Use good lighting to reduce shadows")
                        TipRow(icon: "square.grid.2x2.fill", text: "Use up to 4 photos for long recipes")
                    }
                    .padding(LayoutHelpers.horizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.pantryBackground)
                .navigationTitle("Scanning Tips")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingTipsSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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
        .alert("No Recipes Detected", isPresented: $viewModel.showNoRecipesAlert) {
            Button("Try Again") {
                viewModel.showNoRecipesAlert = false
            }
        } message: {
            Text("We couldn't detect any recipes from your photos. Please try clearer photos with the full recipe page visible.")
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isScanningCookbookRecipes },
                set: { _ in }
            )
        ) {
            let (stages, duration) = LoadingMessages.detectIngredientsStages(imageCount: viewModel.selectedImages.count)
            EnhancedLoadingView(
                progressStages: stages,
                funFacts: LoadingMessages.allFunFacts,
                estimatedDuration: duration,
                loadingImageName: "avi_magnifying_glass_animated"
            )
            .background(Color.pantryBackground.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) {
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.pantryHeadline)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(Color.black.opacity(0.2))
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}
