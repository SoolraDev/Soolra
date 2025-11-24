//
//  ProfileView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

struct ProfileView: View {
    @Binding var isPresented: Bool
    @StateObject private var vv = overlayState

    // State for the image picker flow
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false

    // A unique ID to force AsyncImage to reload after an upload
    @State private var imageId = UUID()

    var body: some View {
        VStack(spacing: 16) {
            // MARK: banner
            ZStack {
                Image("profile-view-banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()

                Button(action: {
                    isShowingImagePicker = true
                }) {
                    profileImageView
                        .overlay {
                            // Show a loading spinner overlay while uploading
                            if isUploading {
                                ZStack {
                                    Color.black.opacity(0.4)
                                    ProgressView()
                                        .tint(.white)
                                        .foregroundStyle(.white)
                                }
                                .clipShape(.circle)
                                .ignoresSafeArea()
                            }
                        }
                }
                .offset(x: -120, y: 60)
            }
            .padding(.bottom, 40)

            // MARK: profile info
            VStack(spacing: 16) {
                MetricBanner(
                    iconName: "target",
                    title: "Points Earned",
                    //                    value: "\(dataManager.userMetrics?.points, default: "0")"
                    value: "Coming soon"
                )

                MetricBanner(
                    iconName: "trophy.fill",
                    title: "Time Played Ranking",
                    value: "\(dataManager.userMetrics?.ranking, default: "0")"
                )

                MetricBanner(
                    iconName: "hourglass",
                    title: "Total Time Played",
                    value: dataManager.userMetrics?.totalTimePlayed
                        .toWordedString() ?? "0"
                )
            }.padding()
                .task {
                    await dataManager.refresh()
                }

            VStack {
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
            }.comingSoon()

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
            
            // NOTE: Previous "Close" button was removed from here
            Spacer().frame(height: 20)
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        // MARK: Close Button Overlay
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { isPresented.toggle() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
                    .shadow(radius: 2)
            }
        }
        .frame(maxWidth: 400, maxHeight: .infinity)
        .padding()
        .edgesIgnoringSafeArea(.all)
        .background(.gray.opacity(0.5))
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _ in
            guard let image = selectedImage else { return }
            Task {
                await uploadImage(image)
            }
        }
    }

    /// A computed property for the user's profile image view.
    @ViewBuilder
    private var profileImageView: some View {
        // Construct the stable redirect URL for the user's image.
        let imageUrlString =
            "\(Configuration.soolraBackendURL)/v1/users/\(walletManager.privyUser?.id ?? "")/image"

        AsyncImage(url: URL(string: imageUrlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                // Fallback icon if the image fails to load or doesn't exist.
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundStyle(.white)
            @unknown default:
                // Placeholder while loading.
                ProgressView()
            }
        }
        .id(imageId)  // The key to forcing a reload on demand
        .frame(width: 80, height: 80)
        .background(.gray)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.purple, lineWidth: 3)
        )
    }

    /// The function that handles the upload task.
    private func uploadImage(_ image: UIImage) async {
        guard let userId = walletManager.privyUser?.id else { return }

        isUploading = true
        defer {
            isUploading = false
            selectedImage = nil  // Clear the selection after attempting upload
        }

        do {
            _ = try await ProfileImageUploader.upload(image: image, for: userId)
            // On success, change the imageId to force the AsyncImage to reload from the URL.
            imageId = UUID()
            print("✅ Image uploaded successfully.")
        } catch {
            print("❌ Failed to upload image: \(error.localizedDescription)")
            // Optionally show an error alert to the user here.
        }
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
