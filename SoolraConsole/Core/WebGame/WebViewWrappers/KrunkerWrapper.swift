//
//  KrunkerWrapper.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 25/08/2025.
//


import SwiftUI
import WebKit

struct KrunkerWrapper: View {
    @StateObject var viewModel: KrunkerViewModel
    let onClose: () -> Void

    init(viewModel: KrunkerViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameWebView(
                url: viewModel.startURL,
                makeConfiguration: {
                    let cfg = WKWebViewConfiguration()
                    // Krunker prefers pointer lock; allow inline media if needed
                    cfg.allowsInlineMediaPlayback = true
                    return cfg
                },
                onWebViewReady: { webView in
                    viewModel.webView = webView
                }
            )
            .background(Color.black)
            .ignoresSafeArea()

            // Small helper label
            Text("Press B to close")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.top, 51)
                .padding(.leading, 6)
                .allowsHitTesting(false)
        }
        .onAppear {
            forceLandscape(true)
            BluetoothControllerService.shared.delegate = viewModel
            viewModel.dismiss = { onClose() }
        }
        .onDisappear {
            if BluetoothControllerService.shared.delegate === viewModel {
                HomeViewModel.shared.setAsDelegate()
            }
            forceLandscape(false)
        }
    }
}

private func forceLandscape(_ enabled: Bool) {
    let orientation: UIInterfaceOrientation = enabled ? .landscapeRight : .portrait
    UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
    UIViewController.attemptRotationToDeviceOrientation()
}
