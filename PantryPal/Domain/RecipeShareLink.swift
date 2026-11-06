//
//  RecipeShareLink.swift
//  Reciplease
//
//  Custom-scheme links and https://reciplease.info universal links.
//

import Foundation

enum RecipeShareLink {
    static func url(for recipeID: UUID) -> URL {
        URL(string: "https://reciplease.info/recipes/shared/\(recipeID.uuidString.lowercased())")!
    }

    static func recipeID(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "reciplease" {
            if url.host?.lowercased() == "recipe" {
                return url.pathComponents.first { $0 != "/" && !$0.isEmpty }
            }
            return nil
        }
        guard scheme == "https" || scheme == "http" else { return nil }
        guard url.host?.lowercased() == "reciplease.info" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 3, parts[0] == "recipes", parts[1] == "shared" else { return nil }
        return parts[2]
    }
}
