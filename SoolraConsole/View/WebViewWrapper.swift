import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    var onWebViewReady: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        onWebViewReady(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
