//
//  FreshPicksView.swift
//  Reciplease
//
//  Tonight's Picks session tray. Generated ideas stay here until they are saved.
//

import SwiftUI

struct FreshPicksView: View {
    @ObservedObject var viewModel: PantryViewModel
    @State private var openRecipe: FreshPickNavigation?
    @State private var proNudgeVisible = false

    private var activeSession: GenerationSession? {
        if let id = viewModel.activeGenerationSessionId {
            return viewModel.generationSessions.first { $0.sessionId == id }
        }
        return viewModel.generationSessions.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                if viewModel.generationSessions.isEmpty {
                    emptyState
                } else {
                    sessionPills
                    if proNudgeVisible {
                        proNudge
                    }
                    if let session = activeSession {
                        Text(session.summaryLabel)
                            .font(.pantryTitle2)
                            .fontWeight(.bold)
                        Text("\(session.visiblePitches.count) fresh ideas")
                            .font(.pantrySubheadline)
                            .foregroundStyle(Color.pantryTextSecondary)
                        if viewModel.isExpandingPitch {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(viewModel.expandingPitchTitle.map { "Prepping \($0)..." } ?? "Prepping your recipe...")
                                    .font(.pantryBody)
                            }
                            .padding(.vertical, 8)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(session.visiblePitches) { pitch in
                                pitchCard(pitch, session: session)
                            }
                        }
                        if viewModel.isDealingMorePitches {
                            ProgressView("Finding a few more...")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            Task { await viewModel.dealMorePitches(in: session.sessionId, like: nil) }
                        } label: {
                            Text("Deal 3 More")
                                .font(.pantryHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().stroke(Color.pantryPrimary, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isDealingMorePitches)
                    }
                }
            }
            .padding(DesignTokens.spacingMD)
        }
        .background(Color.pantryBackground)
        .navigationTitle("Fresh Picks")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openRecipe) { item in
            RecipeDetailView(viewModel: viewModel, recipeId: item.id, isFromFavorites: viewModel.isFavorite(recipeId: item.id))
        }
        .onAppear {
            let key = "Reciplease.ProNudgeAfterFirstRecipes.Dismissed"
            proNudgeVisible = !viewModel.generationSessions.isEmpty
                && !RevenueCatService.shared.isProMember
                && !UserDefaults.standard.bool(forKey: key)
        }
    }

    private var sessionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.generationSessions) { session in
                    Button {
                        viewModel.activeGenerationSessionId = session.sessionId
                    } label: {
                        Text(session.summaryLabel)
                            .font(.pantryCaption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(session.sessionId == activeSession?.sessionId ? Color.pantryPrimary : Color.pantrySurface))
                            .foregroundStyle(session.sessionId == activeSession?.sessionId ? Color.white : Color.pantryTextPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pitchCard(_ pitch: RecipePitch, session: GenerationSession) -> some View {
        let isNew = !session.viewedPitchIds.contains(pitch.pitchId)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pitch.laneTitle)
                    .font(.pantryCaption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.pantrySecondary.opacity(0.15)))
                    .foregroundStyle(Color.pantrySecondary)
                Spacer()
                if isNew {
                    Text("NEW")
                        .font(.pantryCaption2)
                        .fontWeight(.heavy)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.pantryPrimary))
                }
            }
            Text(pitch.title)
                .font(.pantryHeadline)
                .foregroundStyle(Color.pantryTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let hook = pitch.hook, !hook.isEmpty {
                Text(hook)
                    .font(.pantryCaption)
                    .foregroundStyle(Color.pantryTextSecondary)
                    .lineLimit(3)
            }
            HStack(spacing: 8) {
                if let minutes = pitch.totalTimeMinutes {
                    Label("\(minutes)m", systemImage: "clock")
                }
                Text(pitch.difficultyLabel)
            }
            .font(.pantryCaption2)
            .foregroundStyle(Color.pantryTextSecondary)
            Text(pitch.matchPill())
                .font(.pantryCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pantryPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await open(pitch, session: session) }
            } label: {
                Text("See recipe")
                    .font(.pantryCaption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.pantryPrimary))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            HStack {
                Button("Save") { Task { await viewModel.savePitchToCookbook(pitch.pitchId, sessionId: session.sessionId) } }
                Spacer()
                Button("Cook") { Task { await viewModel.cookPitchTonight(pitch.pitchId, sessionId: session.sessionId) } }
            }
            .font(.pantryCaption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pantryPrimary)
            HStack {
                Button("More like this") { Task { await viewModel.dealMorePitches(in: session.sessionId, like: pitch) } }
                Spacer()
                Button("Dismiss") { viewModel.dismissPitch(pitch.pitchId, in: session.sessionId) }
            }
            .font(.pantryCaption2)
            .foregroundStyle(Color.pantryTextSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.pantrySurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.pantryBorder.opacity(0.4), lineWidth: 1))
    }

    private func open(_ pitch: RecipePitch, session: GenerationSession) async {
        AppAnalytics.log(.pitchSelected, parameters: ["title": pitch.title, "lane": pitch.lane ?? ""])
        if let recipe = await viewModel.expandPitch(pitchId: pitch.pitchId, in: session.sessionId) {
            openRecipe = FreshPickNavigation(id: recipe.id)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No fresh picks yet")
                .font(.pantryTitle3)
            Text("Ask what sounds good tonight and your ideas will land here, not in a cookbook, until you save one.")
                .font(.pantryBody)
                .foregroundStyle(Color.pantryTextSecondary)
        }
    }

    private var proNudge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These ideas are on the house.")
                .font(.pantryHeadline)
            Text("You can cook from the weekly free allowance. Pro adds modifications and a higher generation cap, whenever you want it.")
                .font(.pantryCaption)
                .foregroundStyle(Color.pantryTextSecondary)
            Button("Not now") {
                UserDefaults.standard.set(true, forKey: "Reciplease.ProNudgeAfterFirstRecipes.Dismissed")
                proNudgeVisible = false
            }
            .font(.pantryCaption)
            .fontWeight(.semibold)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pantryPrimary.opacity(0.08)))
    }
}

struct FreshPickNavigation: Identifiable, Hashable {
    let id: UUID
}
