//
//  ProfileView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

struct ProfileView: View {
    let userMetrics: UserMetrics
    @Binding var isPresented: Bool

    var body: some View {
    }
}

struct ProfileViewModifier: ViewModifier {
    let userMetrics: UserMetrics
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    ProfileView(
                        userMetrics: userMetrics,
                        isPresented: $isPresented
                    )
                    .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

extension View {
    func profileOverlay(isPresented: Binding<Bool>, userMetrics: UserMetrics)
        -> some View
    {
        modifier(
            ProfileViewModifier(
                userMetrics: userMetrics,
                isPresented: isPresented
            )
        )
    }
}
