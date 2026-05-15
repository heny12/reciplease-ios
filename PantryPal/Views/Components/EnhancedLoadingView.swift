//
//  EnhancedLoadingView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/28/26.
//

import SwiftUI

struct EnhancedLoadingView: View {
    let progressStages: [(stage: String, time: Double)]
    let funFacts: [String]
    let estimatedDuration: Double
    /// Optional GIF asset name (no extension). When set, shows this animated GIF instead of the circular spinner.
    let loadingImageName: String?

    @StateObject private var funFactManager: LoadingMessageManager
    @State private var progress: Double = 0.0
    @State private var timeElapsed: Double = 0.0
    @State private var currentStageIndex: Int = 0
    @State private var progressTimer: Timer?

    init(progressStages: [(stage: String, time: Double)], funFacts: [String], estimatedDuration: Double = 20.0, loadingImageName: String? = "avi_camera_animated") {
        self.progressStages = progressStages
        self.funFacts = funFacts
        self.estimatedDuration = estimatedDuration
        self.loadingImageName = loadingImageName
        _funFactManager = StateObject(wrappedValue: LoadingMessageManager(messages: funFacts))
    }

    var currentStage: String {
        guard currentStageIndex < progressStages.count else {
            return progressStages.last?.stage ?? "Processing..."
        }
        return progressStages[currentStageIndex].stage
    }

    var body: some View {
        ZStack {
            Color.pantryPrimary
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    if let imageName = loadingImageName {
                        GIFView(name: imageName)
                            .frame(width: 120, height: 120)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 5)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: progress)

                        ProgressView()
                            .scaleEffect(1.15)
                            .tint(.white)
                    }
                }

                Text(currentStage)
                    .font(.pantryHeadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 24)
                    .id(currentStage)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.28), value: currentStage)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.95))
                            .frame(width: max(6, geometry.size.width * progress), height: 6)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 44)

                VStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.pantryCaption)
                        .foregroundColor(.white.opacity(0.75))

                    Text(funFactManager.currentMessage)
                        .font(.pantrySubheadline)
                        .foregroundColor(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 36)
                        .padding(.horizontal, 36)
                        .id(funFactManager.currentMessage)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: funFactManager.currentMessage)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 56)
        }
        .onAppear {
            funFactManager.start()
            startProgress()
        }
        .onDisappear {
            funFactManager.stop()
            progressTimer?.invalidate()
        }
    }

    private func startProgress() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            timeElapsed += 0.1
            progress = min(timeElapsed / estimatedDuration, 1.0)

            var newStageIndex = 0
            for (index, stage) in progressStages.enumerated() {
                if timeElapsed >= stage.time {
                    newStageIndex = index
                } else {
                    break
                }
            }

            if newStageIndex != currentStageIndex && newStageIndex < progressStages.count {
                withAnimation(.easeInOut(duration: 0.28)) {
                    currentStageIndex = newStageIndex
                }
            }

            if timeElapsed >= estimatedDuration {
                timer.invalidate()
            }
        }
    }
}
