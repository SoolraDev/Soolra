//
//  ProfileView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

struct ProfileView: View {
    private let userMetrics: UserMetrics = UserMetrics(
        userId: "",
        points: 100,
        lastUpdated: Date(),
        ranking: 100,
        totalTimePlayed: 100000
    )
    @Binding var isPresented: Bool
    @StateObject private var vv = overlayState

    var body: some View {
        VStack(spacing: 16) {
            // MARK: banner
            ZStack {
                Image("profile-view-banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()

                // TODO: Implement custom user icons using NFTs
                //                AsyncImage(
                //                    url: URL(string: "https://i.pravatar.cc/150")  // Example URL
                //                ) { image in
                //                    image.resizable()
                //                        .aspectRatio(contentMode: .fill)
                //                } placeholder: {
                //                    ProgressView()
                //                }
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(.gray)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.purple, lineWidth: 3)
                    )
                    .offset(x: -120, y: 60)
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

            Group {
                Text("Top 3 games")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                HStack {
                    ForEach(0..<3) { index in
                        CachedAsyncImage(
                            url: URL(
                                string:
                                    "https://random.danielpetrica.com/api/random?format=thumb"
                            )
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 111, height: 97)
                                .cornerRadius(10)
                                .gradientBorder(
                                    RoundedRectangle(cornerRadius: 10),
                                    colors: [
                                        Color(hex: "#FF00E1"),
                                        Color(hex: "#FCC4FF"),
                                    ]
                                )
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
            }

            VStack {
                Text("Treasures")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack {
                        ForEach(0..<10) { index in
                            CachedAsyncImage(
                                url: URL(
                                    string:
                                        "https://random.danielpetrica.com/api/random?format=thumb"
                                )
                            ) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 70, height: 70)
                                    .clipShape(.circle)
                                    .gradientBorder(
                                        Circle(),
                                        colors: [
                                            Color(hex: "#FF00E1"),
                                            Color(hex: "#FCC4FF"),
                                        ]
                                    )
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                }.padding(.horizontal)
            }.comingSoon()

            Button("Close") { withAnimation { isPresented.toggle() } }
                .padding()
                .tint(.white)
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
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
            return ProfileView(
                isPresented: $isPresented
            )
        }
    }
    return PreviewContainer()
}

struct ProfileViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    ProfileView(
                        isPresented: $isPresented
                    )
                    .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

extension View {
    func profileOverlay(isPresented: Binding<Bool>)
        -> some View
    {
        modifier(
            ProfileViewModifier(
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
                        .opacity(0.1),
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
