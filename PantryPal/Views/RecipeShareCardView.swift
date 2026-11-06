//
//  RecipeShareCardView.swift
//  Reciplease
//
//  Visual share card rendered with ImageRenderer and handed to the share sheet with the link.
//

import SwiftUI

struct RecipeShareCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECIPLEASE")
                .font(.caption)
                .fontWeight(.heavy)
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.85))
            Text(recipe.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(recipe.hook ?? recipe.description)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(4)
            Spacer(minLength: 0)
            HStack {
                if let minutes = recipe.totalTimeMinutes {
                    Text("\(minutes) min")
                }
                if let servings = recipe.servings {
                    Text("· \(servings) servings")
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.white)
            Text("reciplease.info")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(28)
        .frame(width: 360, height: 450, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.45, blue: 0.32), Color(red: 0.05, green: 0.22, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct RecipeShareButton: View {
    let recipe: Recipe

    var body: some View {
        Button {
            presentCard(with: RecipeShareLink.url(for: recipe.id))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                Text("Share")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.pantryTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.pantrySurface))
            .overlay(Capsule().stroke(Color.pantryBorder.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func renderedCard() -> UIImage {
        let renderer = ImageRenderer(content: RecipeShareCardView(recipe: recipe))
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }

    private func presentCard(with url: URL) {
        let image = renderedCard()
        let activity = UIActivityViewController(activityItems: [image, url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(activity, animated: true)
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
