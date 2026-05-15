//
//  BundleImage.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI
import UIKit

struct BundleImage: View {
    let name: String
    let directory: String?
    
    init(_ name: String, inDirectory directory: String? = "Assets/Avi") {
        self.name = name
        self.directory = directory
    }
    
    var body: some View {
        Group {
            if let uiImage = loadImage() {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                // Fallback to system image if not found
                Image(systemName: "photo")
                    .foregroundColor(.pantryTextSecondary)
            }
        }
    }
    
    private func loadImage() -> UIImage? {
        // Try multiple paths to find the image
        var imagePath: String?
        
        // Try Assets/Avi/ directory first
        if let directory = directory,
           let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: directory) {
            imagePath = path
            print("✅ Found image in directory: \(directory)")
        }
        // Try Avi/ directory
        else if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Avi") {
            imagePath = path
            print("✅ Found image in directory: Avi")
        }
        // Try Assets/ directory
        else if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Assets") {
            imagePath = path
            print("✅ Found image in directory: Assets")
        }
        // Try root of bundle (if files were added as a group, not folder reference)
        else if let path = Bundle.main.path(forResource: name, ofType: "png") {
            imagePath = path
            print("✅ Found image in bundle root")
        }
        // Try UIImage(named:) as fallback (for asset catalog or if name includes path)
        else if let image = UIImage(named: name) {
            print("✅ Found image using UIImage(named:)")
            return image
        }
        // Try with full path in name
        else if let image = UIImage(named: "Assets/Avi/\(name)") {
            print("✅ Found image using UIImage(named:) with path")
            return image
        }
        
        guard let path = imagePath else {
            print("⚠️ Could not load image: \(name).png")
            print("   Tried paths: Assets/Avi/, Avi/, Assets/, bundle root, and UIImage(named:)")
            return nil
        }
        
        guard let image = UIImage(contentsOfFile: path) else {
            print("⚠️ Could not create UIImage from path: \(path)")
            return nil
        }
        
        print("✅ Loaded image: \(name).png from path: \(path)")
        return image
    }
}
