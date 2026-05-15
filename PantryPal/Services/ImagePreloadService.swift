//
//  ImagePreloadService.swift
//  Reciplease
//
//  Created by Henry Chipman on 2/13/26.
//

import Foundation
import UIKit

class ImagePreloadService {
    static let shared = ImagePreloadService()
    
    private var preloadingTasks: [String: Task<Void, Never>] = [:]
    private let cacheService = ImageCacheService.shared
    
    private init() {
        // Configure URLCache for additional in-memory caching
        let memoryCapacity = 50 * 1024 * 1024 // 50MB
        let diskCapacity = 200 * 1024 * 1024 // 200MB
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "recipe_images_cache")
    }
    
    /// Preloads images for a list of recipe image URLs
    func preloadImages(for imageURLs: [String]) {
        for imageURL in imageURLs {
            preloadImage(for: imageURL)
        }
    }
    
    /// Preloads a single image if not already cached
    func preloadImage(for imageURL: String) {
        // Skip if already cached
        if cacheService.hasCachedImage(for: imageURL) {
            return
        }
        
        // Skip if already preloading
        if preloadingTasks[imageURL] != nil {
            return
        }
        
        // Start preloading
        preloadingTasks[imageURL] = Task {
            guard let url = URL(string: imageURL) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        cacheService.saveImage(image, for: imageURL)
                        preloadingTasks.removeValue(forKey: imageURL)
                        print("✅ Preloaded image: \(imageURL)")
                    }
                }
            } catch {
                await MainActor.run {
                    preloadingTasks.removeValue(forKey: imageURL)
                    print("❌ Failed to preload image \(imageURL): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancels all preloading tasks
    func cancelAll() {
        for task in preloadingTasks.values {
            task.cancel()
        }
        preloadingTasks.removeAll()
    }
}
