import SwiftUI
import WebKit

struct PlatformerWrapper: View {
    @StateObject var viewModel: PlatformerViewModel
    let onClose: () -> Void

    init(viewModel: PlatformerViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                GameWebView(
                    url: viewModel.startURL,
                    makeConfiguration: {
                        let cfg = WKWebViewConfiguration()
                        cfg.allowsInlineMediaPlayback = true
                        return cfg
                    },
                    onWebViewReady: { web in
                        viewModel.webView = web
                        web.navigationDelegate = viewModel
                    }
                )
                .clipped()
                .background(Color.black)

                if viewModel.isLoading {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
                }

                Text("Press X to close")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 51)
                    .padding(.trailing, 6)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            BluetoothControllerService.shared.delegate = viewModel
            viewModel.dismiss = { onClose() }
        }
        .onDisappear {
            if BluetoothControllerService.shared.delegate === viewModel {
                HomeViewModel.shared.setAsDelegate()
            }
        }
    }
}
