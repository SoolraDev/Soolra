//
//  WalletView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct WalletView: View {
    @Binding var isPresented: Bool

    var body: some View {

    }
}

struct WalletViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    WalletView(isPresented: $isPresented)
                        .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

extension View {
    func walletOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(WalletViewModifier(isPresented: isPresented))
    }
}
