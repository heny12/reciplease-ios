//
//  ImageCacheService.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
import UIKit

class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("recipe_images", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Returns the file URL for a cached image given its URL string
    private func fileURL(for imageURL: String) -> URL {
        // Create a safe filename from the URL using MD5 hash for uniqueness
        // This ensures consistent filenames and handles special characters
        let filename = imageURL.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            ?? imageURL.hash.description
        
        return cacheDirectory.appendingPathComponent("\(filename).png")
    }
    
    /// Saves an image to cache using its URL as the key
    func saveImage(_ image: UIImage, for imageURL: String) {
        guard let imageData = image.pngData() else {
            print("❌ Failed to convert image to PNG data for URL: \(imageURL)")
            return
        }
        
        let fileURL = fileURL(for: imageURL)
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
            // print("💾 Cached image for URL: \(imageURL)")
        } catch {
            print("❌ Failed to cache image for URL \(imageURL): \(error.localizedDescription)")
        }
    }
    
    /// Loads a cached image for a given URL
    func loadImage(for imageURL: String) -> UIImage? {
        let fileURL = fileURL(for: imageURL)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        // print("📂 Loaded cached image for URL: \(imageURL)")
        return image
    }
    
    /// Checks if an image is cached for a given URL
    func hasCachedImage(for imageURL: String) -> Bool {
        let fileURL = fileURL(for: imageURL)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Removes a cached image for a given URL
    func removeImage(for imageURL: String) {
        let fileURL = fileURL(for: imageURL)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                // print("🗑️ Removed cached image for URL: \(imageURL)")
            }
        } catch {
            print("❌ Failed to remove cached image for URL \(imageURL): \(error.localizedDescription)")
        }
    }
    
    /// Removes all cached images that are not in the provided set of URLs
    func cleanupUnusedImages(usedImageURLs: Set<String>) {
        guard let cachedFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        // Create a set of expected filenames from used URLs
        let usedFilenames = Set(usedImageURLs.map { imageURL in
            let filename = imageURL.data(using: .utf8)?.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
                ?? imageURL.hash.description
            return "\(filename).png"
        })
        
        var removedCount = 0
        for fileURL in cachedFiles {
            let filename = fileURL.lastPathComponent
            
            // Check if this file corresponds to a used URL
            if !usedFilenames.contains(filename) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    removedCount += 1
                } catch {
                    print("❌ Failed to remove unused cached image: \(error.localizedDescription)")
                }
            }
        }
        
        if removedCount > 0 {
            print("🧹 Cleaned up \(removedCount) unused cached images")
        }
    }
    
    /// Removes all cached images
    func clearAll() {
        guard let cachedFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in cachedFiles {
            try? fileManager.removeItem(at: fileURL)
        }
        
        print("🗑️ Cleared all cached images")
    }
}
