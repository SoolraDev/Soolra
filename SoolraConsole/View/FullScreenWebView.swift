import SwiftUI
import WebKit

struct HalfScreenWebView: View {
    @Environment(\.dismiss) var dismiss

    var timestamp: String {
        String(Int(Date().timeIntervalSince1970))
    }

    var body: some View {
        VStack(spacing: 0) {
            WebView(url: URL(string: "http://192.168.1.167:54741?cacheBust=\(timestamp)")!)
                .frame(height: UIScreen.main.bounds.height)
                .background(Color(.systemBackground))

            Spacer()

            Button("Close") {
                dismiss()
            }
            .padding()
        }
    }
}



struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            webView.becomeFirstResponder()
        }
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
