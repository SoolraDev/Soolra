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
        VStack(spacing: 16) {
            // MARK: banner
            ZStack {
                Image("profile-view-banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                AsyncImage(
                    url: URL(string: "https://i.pravatar.cc/150")  // Example URL
                ) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .background(.gray)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.purple, lineWidth: 3)
                )
                .offset(x:-120, y: 60)
            }
            .padding(.bottom, 40)
            
            // MARK: profile info
            VStack(spacing: 16) {
                MetricBanner(
                    iconName: "target",
                    title: "Points Earned",
                    value: "\(userMetrics.points)"
                )
                
                MetricBanner(
                    iconName: "trophy.fill",
                    title: "Time Played Ranking",
                    value: "\(userMetrics.ranking)"
                )
                
                MetricBanner(
                    iconName: "hourglass",
                    title: "Total Time Played",
                    value: userMetrics.totalTimePlayed.toWordedString()
                )
            }.padding()
            Button("Dismiss") { isPresented = false }
                .padding()
                .tint(.white)
        }
        .purpleGradientBackground()
        .cornerRadius(20)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .padding()
        .edgesIgnoringSafeArea(.all)
        .background(.gray.opacity(0.5))
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var isPresented: Bool = true
        var body: some View {
            let userMetrics = UserMetrics(
                userId: "",
                points: 100,
                lastUpdated: Date(),
                ranking: 1,
                totalTimePlayed: 10000
            )
            return ProfileView(
                userMetrics: userMetrics,
                isPresented: $isPresented
            )
        }
    }
    return PreviewContainer()
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

extension View {
    /// Applies a custom purple vertical gradient as the background of a view.
    /// The gradient ignores safe areas to fill the entire screen.
    func purpleGradientBackground() -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 160 / 255, green: 158 / 255, blue: 181 / 255)
                        .opacity(0.29),
                    Color(red: 115 / 255, green: 46 / 255, blue: 210 / 255)
                        .opacity(0.89),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
