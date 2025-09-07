import SwiftUI
import WebKit

struct YabalaliWrapper: View {
    @StateObject var viewModel: YabalaliViewModel
    let onClose: () -> Void

    init(viewModel: YabalaliViewModel, onClose: @escaping () -> Void) {
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
                        return cfg
                    },
                    onWebViewReady: { web in viewModel.webView = web }
                )
                .frame(width: geo.size.width, height: geo.size.height * 0.6, alignment: .top) // ⬅ top half
                .clipped()
                .background(Color.black)

                Text("Press B to close")
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
            viewModel.dismiss = { onClose() }
        }
        .onDisappear {
            if BluetoothControllerService.shared.delegate === viewModel {
                HomeViewModel.shared.setAsDelegate()
            }
        }
    }
}
