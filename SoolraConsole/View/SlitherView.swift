//
//  SlitherView.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 04/08/2025.
//


import SwiftUI

struct SlitherView: View {
    @StateObject private var viewModel = SlitherViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
//            WebViewWrapper(url: URL(string: "http://slither.com")!) { webView in
            WebViewWrapper(url: URL(string: "https://axilleasiv.github.io/vue2048/")!) { webView in

                viewModel.webView = webView
            }
            .frame(height: UIScreen.main.bounds.height / 2)
            .background(Color(.systemBackground))

            Spacer()

            Button("Close") {
                dismiss()
            }
            .padding()
        }
        .onAppear {
            BluetoothControllerService.shared.delegate = viewModel
            viewModel.dismiss = { dismiss() }

        }
        .onDisappear {
            if BluetoothControllerService.shared.delegate === viewModel {
                HomeViewModel.shared.setAsDelegate()
            }
        }
        .ignoresSafeArea()
    }
}
