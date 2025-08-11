import SwiftUI
import WebKit

struct Game2048Wrapper: View {
    @StateObject var viewModel: Game2048ViewModel
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    init(viewModel: Game2048ViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }
    var body: some View {
        ZStack {
            GameWebView(
                url: viewModel.startURL,
                makeConfiguration: {
                    let cfg = WKWebViewConfiguration()

                    // Your old DOM adjustment script for 6x6 layout
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
                        WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                    )
                    return cfg
                },
                onWebViewReady: { webView in
                    viewModel.webView = webView   // keep your link for JS injections
                }
            )
            .ignoresSafeArea()

            // Optional overlay UI (Close button)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(12)
                    }
                }
                Spacer()
            }
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
