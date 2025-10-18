//
//  GameWebView.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 11/08/2025.
//


import SwiftUI
import WebKit

struct GameWebView: UIViewRepresentable {
    let url: URL
    /// Provide a WKWebViewConfiguration so each game can inject its own JS, content rules, etc.
    var makeConfiguration: () -> WKWebViewConfiguration = { WKWebViewConfiguration() }
    var onWebViewReady: (WKWebView) -> Void = { _ in }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        onWebViewReady(webView)
        // inside GameWebView.makeUIView
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
