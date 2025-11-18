//
//  OverlayBackgroundView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct OverlayBackgroundView: View {
    @Binding var isPresented: Bool

    var body: some View {
        GeometryReader { geometry in
            Color.black
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
        }
        .onTapGesture {
            isPresented.toggle()
        }
    }
}

struct OverlayBackgroundViewModifier: ViewModifier {
    var isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        content.background(OverlayBackgroundView(isPresented: isPresented))
    }
}

extension View {
    func overlayBackground(isPresented: Binding<Bool>) -> some View {
        modifier(OverlayBackgroundViewModifier(isPresented: isPresented))
    }
}
