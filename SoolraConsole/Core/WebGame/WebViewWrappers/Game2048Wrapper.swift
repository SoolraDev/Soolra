import SwiftUI
import WebKit

struct Game2048Wrapper: View {
    @StateObject var viewModel: Game2048ViewModel
    let onClose: () -> Void

    init(viewModel: Game2048ViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {   // ⬅ overlay label on top-left of webview
                GameWebView(
                    url: viewModel.startURL,
                    makeConfiguration: {
                        let cfg = WKWebViewConfiguration()
                        let js = """
                        (function(){
                          function updateRightOffset() {
                            try {
                              var sel = document.querySelector('select');
                              var size = sel ? parseInt(sel.value, 10) : null;
                              var gc = document.querySelector('.game-container');
                              if (gc) {
                                if (size === 6) {
                                  gc.style.right = '100px';
                                } else {
                                  gc.style.right = '';
                                }
                              }
                            } catch(e) { console.error(e); }
                          }
                          updateRightOffset();
                          var mo = new MutationObserver(updateRightOffset);
                          mo.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['value']});
                          document.addEventListener('change', updateRightOffset, true);
                        })();
                        """
                        cfg.userContentController.addUserScript(
                            WKUserScript(
                                source: js,
                                injectionTime: .atDocumentEnd,
                                forMainFrameOnly: true
                            )
                        )
                        return cfg
                    },
                    onWebViewReady: { webView in
                        viewModel.webView = webView
                    }
                )
                .clipped()
                .background(Color.black)
                .ignoresSafeArea()

                // ⬇︎ Top-left label over the webview
                Text("Press B to close")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 51)      // ↓ a bit lower
                    .padding(.leading, 6)  // → a bit to the right
                    .allowsHitTesting(false)
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
}
