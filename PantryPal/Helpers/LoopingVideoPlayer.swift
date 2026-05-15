//
//  LoopingVideoPlayer.swift
//  Reciplease
//
//  Created by Cursor on 3/2/26.
//

import SwiftUI
import AVFoundation

/// Container that updates the player layer's frame in layoutSubviews so it gets correct bounds from SwiftUI.
private final class VideoPlayerContainerView: UIView {
    var playerLayer: AVPlayerLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let layer = playerLayer {
                layer.videoGravity = .resizeAspect
                layer.frame = bounds
                self.layer.addSublayer(layer)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

/// Plays a video from the app bundle in a loop. Use for onboarding or demo clips.
struct LoopingVideoPlayer: UIViewRepresentable {
    let resourceName: String
    var withExtension: String = "mp4"
    var subdirectory: String? = "Assets"
    
    func makeUIView(context: Context) -> UIView {
        let container = VideoPlayerContainerView()
        container.backgroundColor = .clear
        
        let url = Bundle.main.url(forResource: resourceName, withExtension: withExtension, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: resourceName, withExtension: withExtension)
        
        guard let url = url else {
            print("⚠️ LoopingVideoPlayer: Could not find \(resourceName).\(withExtension) in bundle (subdirectory: \(subdirectory ?? "nil"))")
            return container
        }
        
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        let layer = AVPlayerLayer(player: queuePlayer)
        container.playerLayer = layer
        
        context.coordinator.looper = looper
        context.coordinator.player = queuePlayer
        context.coordinator.container = container
        
        // Start playback after a short delay so the view is in the hierarchy (can reduce FigApplicationStateMonitor issues)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            queuePlayer.play()
        }
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? VideoPlayerContainerView)?.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper = nil
        coordinator.player = nil
        coordinator.container?.playerLayer = nil
        coordinator.container = nil
    }
    
    class Coordinator {
        var looper: AVPlayerLooper?
        var player: AVQueuePlayer?
        fileprivate weak var container: VideoPlayerContainerView?
    }
}
