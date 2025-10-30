//
//  MarketView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct MarketView: View {
    @Binding var isPresented: Bool

    var body: some View {
        Text("Hello, World!")
    }
}

struct MarketViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    MarketView(isPresented: $isPresented)
                        .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

extension View {
    func presentMarket(isPresented: Binding<Bool>) -> some View {
        modifier(MarketViewModifier(isPresented: isPresented))
    }
}
