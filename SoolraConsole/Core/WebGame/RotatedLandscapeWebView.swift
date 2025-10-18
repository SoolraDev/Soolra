//
//  RotatedLandscapeWebView.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 25/08/2025.
//


import SwiftUI
import WebKit

/// A WKWebView rotated 90° inside its container, so it *looks* landscape
/// even when the app stays portrait.
struct RotatedLandscapeWebView: UIViewRepresentable {
    let url: URL
    var makeConfiguration: () -> WKWebViewConfiguration = { WKWebViewConfiguration() }
    var onWebViewReady: (WKWebView) -> Void = { _ in }

    func makeUIView(context: Context) -> RotatingContainer {
        let cfg = makeConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black

        let container = RotatingContainer(webView: web)
        onWebViewReady(web)
        web.load(URLRequest(url: url))
        return container
    }

    func updateUIView(_ uiView: RotatingContainer, context: Context) {}
}

/// Hosts and rotates the WKWebView; keeps it centered and clipped.
final class RotatingContainer: UIView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        addSubview(webView)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Rotate the webView 90 degrees (clockwise)
        webView.transform = CGAffineTransform(rotationAngle: 0)

        // After rotation, the webView’s "logical" width/height swap.
        // Make the web content fill our container’s width and height.
        let W = bounds.width
        let H = bounds.height
        // Set the webView’s *unrotated* bounds to the swapped size
        webView.bounds = CGRect(x: 0, y: 0, width: H, height: W)
        webView.center = CGPoint(x: W / 2, y: H / 2)
    }
}
