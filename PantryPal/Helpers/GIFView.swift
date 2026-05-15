//
//  GIFView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI
import UIKit
import ImageIO

struct GIFView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // Constrain imageView to container
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        // Try multiple paths to find the GIF
        var gifPath: String?
        
        // Try Assets/Avi/ directory first
        if let path = Bundle.main.path(forResource: name, ofType: "gif", inDirectory: "Assets/Avi") {
            gifPath = path
        }
        // Try Avi/ directory
        else if let path = Bundle.main.path(forResource: name, ofType: "gif", inDirectory: "Avi") {
            gifPath = path
        }
        // Try root of bundle
        else if let path = Bundle.main.path(forResource: name, ofType: "gif") {
            gifPath = path
        }
        
        guard let path = gifPath,
              let data = NSData(contentsOfFile: path),
              let source = CGImageSourceCreateWithData(data, nil) else {
            print("⚠️ Could not load GIF: \(name).gif")
            print("   Tried paths: Assets/Avi/, Avi/, and root")
            return containerView
        }
        
        print("✅ Loaded GIF: \(name).gif from path: \(path)")
        configureAnimatedImageView(imageView, from: source)
        return containerView
    }
    
    private func configureAnimatedImageView(_ imageView: UIImageView, from source: CGImageSource) {
        // Get frame count
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                // Get frame duration
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                    totalDuration += delayTime
                } else {
                    // Default delay if not specified
                    totalDuration += 0.1
                }
            }
        }
        
        // Create animated image
        imageView.animationImages = images
        imageView.animationDuration = totalDuration > 0 ? totalDuration : 1.0
        imageView.animationRepeatCount = 0 // Infinite loop
        imageView.startAnimating()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the imageView and restart animation if needed
        if let imageView = uiView.subviews.first as? UIImageView, !imageView.isAnimating {
            imageView.startAnimating()
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.stopAnimating()
            imageView.animationImages = nil
        }
    }
}
