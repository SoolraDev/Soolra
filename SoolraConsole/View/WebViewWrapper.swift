import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    var onWebViewReady: (WKWebView) -> Void = { _ in }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()

        let js = """
        (function(){
          function updateRightOffset() {
            try {
              // Find size selector or any element showing the grid size
              var sel = document.querySelector('select'); // adjust selector if needed
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

          // Run at start
          updateRightOffset();

          // Observe DOM changes (covers changing from 4x4 → 6x6 in UI)
          var mo = new MutationObserver(updateRightOffset);
          mo.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['value']});

          // Also check on change events for dropdowns/buttons
          document.addEventListener('change', updateRightOffset, true);
        })();
        """

        cfg.userContentController.addUserScript(
          WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let webView = WKWebView(frame: .zero, configuration: cfg)
        onWebViewReady(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
