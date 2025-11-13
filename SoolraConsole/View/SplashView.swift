import AVFoundation
import SwiftUI

struct SplashView: View {
    @Binding var isShowingSplash: Bool
    @EnvironmentObject var dataController: CoreDataController
    @StateObject private var defaultRomsLoadingState = DefaultRomsLoadingState.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VideoPlayerView(videoName: "splashvideo", isShowingSplash: $isShowingSplash)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isShowingSplash = false }
        }
        .task {
            Task.detached(priority: .userInitiated) {
                await defaultRomsLoadingState.loadIfNeeded {
                    await dataController.romManager.initDefaultRoms()
                }
            }
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let videoName: String
    @Binding var isShowingSplash: Bool

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator {
        var player: AVPlayer?
        var endObs: NSObjectProtocol?
        init() {}
        deinit {
            if let p = player { p.pause() }
            if let endObs { NotificationCenter.default.removeObserver(endObs) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.backgroundColor = .black

        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("🚨 Video not found: \(videoName).mp4")
            DispatchQueue.main.async { isShowingSplash = false }
            return v
        }

        let player = AVPlayer(url: url)
        context.coordinator.player = player

        let layer = v.playerLayer
        layer.player = player
        layer.videoGravity = .resizeAspectFill // fill screen, crop as needed

        // Start playback
        player.play()

        // Auto-dismiss on end
        context.coordinator.endObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            isShowingSplash = false
        }

        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        // Nothing needed; SwiftUI drives sizing. The layer fills bounds automatically.
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        if let endObs = coordinator.endObs {
            NotificationCenter.default.removeObserver(endObs)
        }
    }
}



@MainActor
final class DefaultRomsLoadingState: ObservableObject {
    static let shared = DefaultRomsLoadingState()

    @Published private(set) var isLoading: Bool = true

    func loadIfNeeded(_ loadBlock: @escaping () async -> Void) async {
        guard isLoading else { return }
        await loadBlock()
        isLoading = false
    }
}
