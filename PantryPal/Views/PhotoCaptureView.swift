//
//  PhotoCaptureView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

enum ImagePickerSource: Identifiable {
    case camera
    case library
    var id: Self { self }
}

struct PhotoCaptureView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss
    private let maxPhotosAllowed: Int = 4

    @State private var activePickerSource: ImagePickerSource?
    @State private var showingIngredientChoiceDialog = false
    @State private var cameraCaptureRequest = 0
    @State private var showingTipsSheet = false

    // MARK: - Extracted Subviews

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
        Button(action: {
            HapticFeedback.medium()
            if !viewModel.ingredients.isEmpty {
                showingIngredientChoiceDialog = true
            } else {
                Task {
                    await viewModel.detectIngredients(mergeWithExisting: false)
                }
            }
        }) {
            HStack(spacing: 10) {
                if viewModel.isDetectingIngredients {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "sparkles")
                        .font(.pantryCustom(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(viewModel.isDetectingIngredients ? "Scanning..." : "Scan for Ingredients")
                        .font(.pantryHeadline)
                        .fontWeight(.semibold)
                    if viewModel.selectedImages.count > 0 {
                        Text(
                            "Scanning \(viewModel.selectedImages.count) photo\(viewModel.selectedImages.count == 1 ? "" : "s")"
                        )
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
                (viewModel.isDetectingIngredients || !viewModel.allImagesUploaded)
                    ? Color.gray.opacity(0.35)
                    : Color.pantryPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LayoutHelpers.horizontalPadding)
        .disabled(!viewModel.allImagesUploaded || viewModel.isDetectingIngredients)
    }

    // MARK: - Body

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
                                ForEach(
                                    Array(viewModel.selectedImages.enumerated()), id: \.element.id
                                ) { index, imageWithURL in
                                    PhotoThumbnailItem(
                                        imageWithURL: imageWithURL,
                                        onRemove: {
                                            HapticFeedback.light()
                                            withAnimation(
                                                .spring(response: 0.3, dampingFraction: 0.6)
                                            ) {
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
            // Prevent stale parent navigation state from auto-closing this screen.
            viewModel.shouldNavigateToIngredients = false
        }
        .sheet(item: $activePickerSource) { source in
            switch source {
            case .camera:
                ImagePicker(
                    viewModel: viewModel, sourceType: .camera,
                    onDismiss: { activePickerSource = nil })
            case .library:
                PhotoLibraryPicker(
                    viewModel: viewModel, maxPhotosAllowed: maxPhotosAllowed,
                    onDismiss: { activePickerSource = nil })
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

                        TipRow(icon: "sun.max.fill", text: "Good lighting helps accuracy")
                        TipRow(
                            icon: "square.grid.2x2.fill", text: "Include multiple items per photo")
                        TipRow(
                            icon: "camera.viewfinder",
                            text: "Keep ingredients centered and in focus")
                        TipRow(icon: "sparkles", text: "Add spices too for better recipes")
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
        .confirmationDialog(
            "What would you like to do with detected ingredients?",
            isPresented: $showingIngredientChoiceDialog,
            titleVisibility: .visible
        ) {
            Button("Add to Pantry") {
                HapticFeedback.medium()
                Task {
                    await viewModel.detectIngredients(mergeWithExisting: true)
                }
            }
            Button("Replace Pantry") {
                HapticFeedback.medium()
                Task {
                    await viewModel.detectIngredients(mergeWithExisting: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "You have \(viewModel.ingredients.count) ingredients in your pantry. Would you like to add the new ingredients or replace your current pantry?"
            )
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
        .alert("No Ingredients Detected", isPresented: $viewModel.showNoIngredientsAlert) {
            Button("Try Again") {
                viewModel.showNoIngredientsAlert = false
            }
        } message: {
            Text(
                "We couldn't identify any ingredients from your photos. Please try taking clearer photos with better lighting, or make sure food items are visible."
            )
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isDetectingIngredients },
                set: { _ in }
            )
        ) {
            let imageCount = viewModel.selectedImages.count
            let (stages, duration) = LoadingMessages.detectIngredientsStages(imageCount: imageCount)
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

// Full-screen live camera view using AVCaptureSession for a less-zoomed, edge-to-edge preview.
struct FullScreenCameraView: UIViewControllerRepresentable {
    @Binding var captureTrigger: Int
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.configureSessionIfNeeded()
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Trigger a capture when captureTrigger changes.
        guard context.coordinator.lastCaptureTrigger != captureTrigger else { return }
        context.coordinator.lastCaptureTrigger = captureTrigger
        uiViewController.capturePhoto()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastCaptureTrigger: Int = 0
    }

    final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
        private let session = AVCaptureSession()
        private let photoOutput = AVCapturePhotoOutput()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        var onCapture: ((UIImage) -> Void)?
        private var isConfigured = false

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        func configureSessionIfNeeded() {
            guard !isConfigured else { return }
            isConfigured = true

            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(photoOutput)

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }

        func capturePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard error == nil,
                let data = photo.fileDataRepresentation(),
                let image = UIImage(data: data)
            else {
                return
            }
            onCapture?(image)
        }
    }
}

// ImagePicker for Camera (single photo)
struct ImagePicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PantryViewModel
    var sourceType: UIImagePickerController.SourceType
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onDismiss: onDismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let viewModel: PantryViewModel
        let onDismiss: (() -> Void)?

        init(viewModel: PantryViewModel, onDismiss: (() -> Void)?) {
            self.viewModel = viewModel
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let selectedImage = info[.originalImage] as? UIImage {
                viewModel.addImage(selectedImage)
            }
            picker.dismiss(animated: true)
            onDismiss?()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onDismiss?()
        }
    }
}

// PhotoLibraryPicker for Photo Library (multiple photos)
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PantryViewModel
    let maxPhotosAllowed: Int
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        // Calculate how many more photos can be selected
        let remainingSlots = max(1, maxPhotosAllowed - viewModel.selectedImages.count)
        configuration.selectionLimit = remainingSlots
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, maxPhotosAllowed: maxPhotosAllowed, onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let viewModel: PantryViewModel
        let maxPhotosAllowed: Int
        let onDismiss: (() -> Void)?

        init(viewModel: PantryViewModel, maxPhotosAllowed: Int, onDismiss: (() -> Void)?) {
            self.viewModel = viewModel
            self.maxPhotosAllowed = maxPhotosAllowed
            self.onDismiss = onDismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onDismiss?()

            guard !results.isEmpty else { return }

            // Check if we're at the limit
            let remainingSlots = maxPhotosAllowed - viewModel.selectedImages.count
            guard remainingSlots > 0 else {
                Task { @MainActor in
                    viewModel.errorMessage = "Maximum of \(maxPhotosAllowed) photos allowed"
                    HapticFeedback.error()
                }
                return
            }

            // Process selected images (up to the remaining slots)
            let imagesToProcess = Array(results.prefix(remainingSlots))

            for result in imagesToProcess {
                result.itemProvider.loadObject(ofClass: UIImage.self) {
                    [weak self] (object: Any?, error: Error?) in
                    if let error = error {
                        print("❌ Error loading image: \(error.localizedDescription)")
                        return
                    }

                    guard let image = object as? UIImage else { return }

                    Task { @MainActor in
                        self?.viewModel.addImage(image)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
            Image(systemName: icon)
                .font(.pantrySubheadline.weight(.semibold))
                .foregroundColor(.pantryPrimary)
                .frame(minWidth: 24, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(.pantryBody)
                .foregroundColor(.pantryTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HowItWorksStep: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Number circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.pantryHeadline)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(title)
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)

                Text(description)
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(number)
                .font(.pantryTitle2)
                .fontWeight(.bold)
                .foregroundColor(color.opacity(0.3))
        }
    }
}

struct PhotoThumbnailItem: View {
    let imageWithURL: ImageWithURL
    let onRemove: () -> Void
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                PhotoImageContent(imageWithURL: imageWithURL)
                    .frame(width: 72, height: 72)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.pantryBorderSubtle.opacity(0.9), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if imageWithURL.isUploading {
                ProgressView()
                    .scaleEffect(0.75)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if imageWithURL.uploadedURL != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.pantryCustom(size: 14))
                    .foregroundColor(.pantrySuccess)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.pantryCustom(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

private struct PhotoImageContent: View {
    let imageWithURL: ImageWithURL

    var body: some View {
        let isPlaceholder = imageWithURL.image.size == .zero || imageWithURL.image.cgImage == nil

        Group {
            if isPlaceholder, let urlString = imageWithURL.uploadedURL,
                let url = URL(string: urlString)
            {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.pantrySurface)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(Color.pantrySurface)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.pantryTextSecondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(uiImage: imageWithURL.image)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}
