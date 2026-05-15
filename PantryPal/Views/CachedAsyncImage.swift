//
//  CachedAsyncImage.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let url = url, let cachedImage = cachedImage {
                // Use cached image if available
                content(Image(uiImage: cachedImage))
            } else if let url = url {
                // Fall back to AsyncImage if not cached, and cache when it loads
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let loadedImage):
                        // Cache the image when it loads
                        let _ = cacheImageFromURL(url)
                        content(loadedImage)
                    case .failure:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadCachedImage()
        }
        .onChange(of: url?.absoluteString) { _ in
            // Reload cache when URL changes
            loadCachedImage()
        }
    }
    
    private func loadCachedImage() {
        guard let url = url else { return }
        let urlString = url.absoluteString
        
        // Load from cache asynchronously to ensure UI updates
        Task { @MainActor in
            if let cached = ImageCacheService.shared.loadImage(for: urlString) {
                self.cachedImage = cached
                // print("✅ CachedAsyncImage: Loaded cached image for \(urlString)")
            } else {
                print("⚠️ CachedAsyncImage: No cached image found for \(urlString), will use AsyncImage")
                // Preload in background if not cached
                ImagePreloadService.shared.preloadImage(for: urlString)
            }
        }
    }
    
    private func cacheImageFromURL(_ url: URL) {
        let urlString = url.absoluteString
        
        // Download and cache the image
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        ImageCacheService.shared.saveImage(image, for: urlString)
                        cachedImage = image
                    }
                }
            } catch {
                print("❌ Failed to cache image from URL: \(error.localizedDescription)")
            }
        }
    }
}
