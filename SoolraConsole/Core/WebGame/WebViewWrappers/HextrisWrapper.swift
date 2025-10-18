//
//  Game2048Wrapper.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 26/08/2025.
//


import SwiftUI
import WebKit

struct HextrisWrapper: View {
    @StateObject var viewModel: HextrisViewModel
    let onClose: () -> Void

    init(viewModel: HextrisViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // ⬇︎ WebView only in TOP HALF (no full-screen ignoreSafeArea)
                GameWebView(
                    url: viewModel.startURL,
                    makeConfiguration: {
                        let cfg = WKWebViewConfiguration()
                        cfg.allowsInlineMediaPlayback = true
                        let css = """
                        /* Lift the pause button a bit, above the home indicator */
                        #pauseBtn {
                        top: 10px !important;
                          margin-bottom: 0 !important;       /* ignore original margin */
                          z-index: 3000 !important;          /* ensure on top (their CSS sets 99 later) */
                        }
                        /* If safe-area inset is available, add it */
                        @supports (bottom: calc(env(safe-area-inset-bottom) + 1px)) {
                          #pauseBtn { bottom: calc(env(safe-area-inset-bottom) + 14px) !important; }
                        }
                        #restartBtn {
                            top: 75px !important;
                          margin-bottom: 0 !important;       /* ignore original margin */
                          z-index: 3000 !important;          /* ensure on top (their CSS sets 99 later) */
                        }
                        #restart {
                            top: 75px !important;
                          margin-bottom: 0 !important;       /* ignore original margin */
                          z-index: 3000 !important;          /* ensure on top (their CSS sets 99 later) */
                        }
                        #socialShare {
                            display:none !important;    
                        }
                        """
                        let js = """
                        (function(){
                          var s = document.createElement('style');
                          s.id = 'hextris-pause-tweak';
                          s.textContent = `\(css)`;
                          (document.head || document.documentElement).appendChild(s);
                        })();
                        """
                        cfg.userContentController.addUserScript(
                          WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                        )

                        return cfg
                    },
                    onWebViewReady: { webView in
                        
                        webView.customUserAgent =
                          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                          "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
                        viewModel.webView = webView
                    }
                )
                .frame(
                    width: geo.size.width,
                    height: geo.size.height * 0.6, // ⬅ top half only
                    alignment: .top
                )
                .clipped()
                .background(Color.black)

                // Small helper label (keep or remove)
                Text("Press X to close")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 50)
                    .padding(.leading, 6)
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
