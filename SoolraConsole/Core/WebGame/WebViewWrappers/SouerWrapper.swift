import SwiftUI
import WebKit

struct SouerWrapper: View {
    @StateObject var viewModel: SouerViewModel
    let onClose: () -> Void

    init(viewModel: SouerViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                GameWebView(
                    url: viewModel.startURL,
                    makeConfiguration: {
                        let cfg = WKWebViewConfiguration()
                        cfg.allowsInlineMediaPlayback = true
                        cfg.mediaTypesRequiringUserActionForPlayback = []
                        cfg.preferences.javaScriptEnabled = true
                        cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
                        cfg.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
                        cfg.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

                        return cfg
                    },
                    onWebViewReady: { web in
                        viewModel.webView = web
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            viewModel.configureCanvas()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.configureCanvas()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            viewModel.configureCanvas()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            viewModel.configureCanvas()
                        }
                        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

                    }
                )
//                .frame(width: geo.size.width, height: geo.size.height * 0.6, alignment: .top) // ⬅ top half
                .clipped()
                .background(Color.black)

                Text("Press X to close")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 51).padding(.leading, 6)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            BluetoothControllerService.shared.delegate = viewModel
            BluetoothControllerService.shared.joystickDelegate = viewModel
            viewModel.dismiss = { onClose() }
        }
        .onDisappear {
            if BluetoothControllerService.shared.delegate === viewModel {
                HomeViewModel.shared.setAsDelegate()
            }
        }
    }
}
