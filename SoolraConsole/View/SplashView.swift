//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import AVKit

struct SplashView: View {
    @Binding var isShowingSplash: Bool

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all) // Ensure black background
            VideoPlayerView(videoName: "launchvideo", isShowingSplash: $isShowingSplash)
                .edgesIgnoringSafeArea(.all)
        }
        .onTapGesture {
            withAnimation {
                isShowingSplash = false // Skip video when tapped
            }
        }
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let videoName: String
    @Binding var isShowingSplash: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .black // Set background color of controller
        
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("🚨 Video not found: \(videoName).mp4")
            isShowingSplash = false // Skip splash if video is missing
            return controller
        }
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill

        // Adjust frame: Full width, 200px bottom padding
        let screenSize = UIScreen.main.bounds
        playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height - 200)

        controller.view.layer.addSublayer(playerLayer)
        player.play()

        // Auto-skip when video finishes
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            isShowingSplash = false
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
