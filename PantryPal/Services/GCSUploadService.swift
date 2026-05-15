//
//  GCSUploadService.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation
import UIKit
import FirebaseStorage

enum GCSUploadError: Error {
    case uploadFailed(String)
    case imageConversionFailed
}

class GCSUploadService {
    static let shared = GCSUploadService()
    
    private init() {}
    
    /// Uploads an image to Firebase Storage and returns the public URL
    func uploadImage(_ image: UIImage) async throws -> String {
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let storagePath = "\(GCSConfig.storagePath)/\(filename)"
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GCSUploadError.imageConversionFailed
        }
        
        // Get Firebase Storage reference
        let storageRef = Storage.storage().reference().child(storagePath)
        
        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload the file
        do {
            let _ = try await storageRef.putData(imageData, metadata: metadata)
            
            // Brief delay so Storage can finish processing before resolving the download URL (single fetch).
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            do {
                let downloadURL = try await storageRef.downloadURL()
                return downloadURL.absoluteString
            } catch {
                print("⚠️ [GCSUpload] downloadURL failed once: \(error.localizedDescription); using constructed public URL")
            }
            
            // Fallback: construct URL using the bucket name from storage
            let bucket = Storage.storage().reference().bucket
            // Simply replace "/" with "%2F" - don't encode the segments themselves
            let encodedPath = storagePath.replacingOccurrences(of: "/", with: "%2F")
            
            let publicURL = "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(encodedPath)?alt=media"
            return publicURL
        } catch {
            throw GCSUploadError.uploadFailed(error.localizedDescription)
        }
    }
}
