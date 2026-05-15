//
//  UIImage+Resize.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import UIKit

extension UIImage {
    /// Resizes the image to a maximum dimension while maintaining aspect ratio.
    /// Only resizes if the image is larger than the specified maximum dimension.
    /// 
    /// - Parameters:
    ///   - maxDimension: The maximum width or height in points. Default is 2560px for high-quality computer vision.
    ///   - scale: The scale factor to use. Default is 1.0 (maintains device scale).
    /// - Returns: A resized UIImage if the original was larger, or the original image if no resize was needed.
    func resized(to maxDimension: CGFloat, scale: CGFloat = 1.0) -> UIImage {
        let size = self.size
        
        // Calculate the longest dimension
        let longestDimension = max(size.width, size.height)
        
        // If image is already smaller than maxDimension, return original
        guard longestDimension > maxDimension else {
            return self
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = maxDimension / longestDimension
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        // Use UIGraphicsImageRenderer for better quality and performance
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
}
