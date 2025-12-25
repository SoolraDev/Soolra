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

    @ObservedObject private var datamanager = dataManager

    // State for the image picker flow
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false

    // A unique ID to force AsyncImage to reload after an upload
    @State private var imageId = UUID()
    
    // MARK: - NFT State
    @State private var nfts: [NFTMetadata] = []
    @State private var isLoadingNFTs = false
    @State private var selectedNFT: NFTMetadata? = nil

    var body: some View {
        ZStack {
            // MARK: Main Content
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
                        value: "\(datamanager.userMetrics?.points ?? 0)"
                    )

                    MetricBanner(
                        iconName: "trophy.fill",
                        title: "Time Played Ranking",
                        value: "\(datamanager.userMetrics?.ranking ?? 0)"
                    )

                    MetricBanner(
                        iconName: "hourglass",
                        title: "Total Time Played",
                        value: datamanager.userMetrics?.totalTimePlayed
                            .toWordedString() ?? "0"
                    )
                }.padding()
                    .task {
                        await datamanager.refresh()
                        await loadNFTs()
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
                                url: URL(string: "https://random.danielpetrica.com/api/random?format=thumb")
                            ) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 111, height: 97)
                                    .cornerRadius(10)
                                    .gradientBorder(
                                        RoundedRectangle(cornerRadius: 10),
                                        colors: [Color(hex: "#FF00E1"), Color(hex: "#FCC4FF")]
                                    )
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                }.comingSoon()

                // MARK: - Treasures (NFTs)
                VStack {
                    Text("Treasures")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if isLoadingNFTs {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else if nfts.isEmpty {
                        Text("No treasures yet")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(nfts) { nft in
                                    Button {
                                        withAnimation(.spring()) {
                                            selectedNFT = nft
                                        }
                                    } label: {
                                        CachedAsyncImage(url: URL(string: nft.image)) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 70, height: 70)
                                                .clipShape(.circle)
                                                .gradientBorder(
                                                    Circle(),
                                                    colors: [Color(hex: "#FF00E1"), Color(hex: "#FCC4FF")]
                                                )
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 70, height: 70)
                                                .overlay(ProgressView().tint(.white))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                Spacer().frame(height: 20)
            }
            
            // MARK: - NFT Detail Overlay
            if let nft = selectedNFT {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { selectedNFT = nil }
                    }
                    .zIndex(100)
                
                NFTDetailOverlay(
                    nft: nft,
                    onClose: {
                        withAnimation { selectedNFT = nil }
                    },
                    onSetProfile: { image in
                        // Close the overlay
                        withAnimation { selectedNFT = nil }
                        // Trigger upload
                        Task { await uploadImage(image) }
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(101)
                .padding()
            }
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            if selectedNFT == nil {
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

    @ViewBuilder
    private var profileImageView: some View {
        let imageUrlString =
            "\(Configuration.soolraBackendURL)/v1/users/\(walletManager.privyUser?.id ?? "")/image"

        CachedAsyncImage(url: URL(string: imageUrlString)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.crop.circle")
                .resizable()
                .foregroundStyle(.white)
        }
        .id(imageId)
        .frame(width: 80, height: 80)
        .background(.gray)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.purple, lineWidth: 3)
        )
    }

    private func uploadImage(_ image: UIImage) async {
        guard let userId = walletManager.privyUser?.id else { return }
        isUploading = true
        defer {
            isUploading = false
            selectedImage = nil
        }
        do {
            _ = try await ProfileImageUploader.upload(image: image, for: userId)
            imageId = UUID()
            print("✅ Image uploaded successfully.")
        } catch {
            print("❌ Failed to upload image: \(error.localizedDescription)")
        }
    }
    
    private func loadNFTs() async {
        guard let userId = walletManager.privyUser?.id else { return }
        isLoadingNFTs = true
        let client = ApiClient()
        if let fetchedNFTs = await client.fetchUserNFTs(userId: userId) {
            withAnimation {
                self.nfts = fetchedNFTs
            }
        }
        isLoadingNFTs = false
    }
}

// MARK: - NFT Detail Overlay Component

struct NFTDetailOverlay: View {
    let nft: NFTMetadata
    let onClose: () -> Void
    let onSetProfile: (UIImage) -> Void
    
    @State private var loadedImage: UIImage?
    @State private var showingSaveAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Image
            Group {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(height: 250)
            .clipped()
            
            // Info Content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(nft.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title2)
                    }
                }
                
                Text(nft.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().background(Color.white.opacity(0.2))
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: saveToPhotos) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(loadedImage == nil)
                    
                    Button(action: {
                        if let img = loadedImage {
                            onSetProfile(img)
                        }
                    }) {
                        Label("Set as Avatar", systemImage: "person.crop.circle")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(8)
                    }
                    .disabled(loadedImage == nil)
                }
                .padding(.vertical, 4)

                Divider().background(Color.white.opacity(0.2))

                
                // Attributes Grid
                Text("Attributes")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(nft.attributes, id: \.trait_type) { attr in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attr.trait_type.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(attributeValueString(attr.value))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(20)
            .background(Color(red: 45/255, green: 10/255, blue: 90/255))
        }
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .shadow(radius: 20)
        .frame(maxWidth: 350)
        .task {
            // Load the actual UIImage object for processing
            await loadImageData()
        }
        .alert("Image Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image has been saved to your photos.")
        }
    }
    
    private func loadImageData() async {
        guard let url = URL(string: nft.image) else { return }
        
        // 1. Try Cache
        if let cached = ImageCache.shared.get(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 2. Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.set(image: image, for: url)
                self.loadedImage = image
            }
        } catch {
            print("Failed to load NFT image data: \(error)")
        }
    }
    
    private func saveToPhotos() {
        guard let image = loadedImage else { return }
        let saver = ImageSaver()
        saver.onSuccess = {
            showingSaveAlert = true
        }
        saver.onError = { error in
            print("Error saving to photos: \(error.localizedDescription)")
        }
        saver.writeToPhotoAlbum(image: image)
    }
    
    private func attributeValueString(_ value: AnyCodable) -> String {
        if let str = value.value as? String { return str }
        if let int = value.value as? Int { return String(int) }
        if let dbl = value.value as? Double { return String(dbl) }
        return "Unknown"
    }
}

class ImageSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
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
