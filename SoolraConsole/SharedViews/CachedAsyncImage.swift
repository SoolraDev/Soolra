//
//  CachedAsyncImage.swift
//  SOOLRA
//
//  Created by Michael Essiet on 16/11/2025.
//
import SwiftUI

/// A view that asynchronously loads, caches, and displays an image.
/// It implements a "stale-while-revalidate" strategy: if an image is in the cache,
/// it is displayed immediately, but a network request is still fired in the background
/// to fetch the latest version.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        
        // 1. Check cache first and show it immediately if it exists.
        if let cachedImage = ImageCache.shared.get(for: url) {
            self.image = cachedImage
            // Do NOT return here. We want to continue to fetch the latest version.
        }
        
        // 2. Always start download to revalidate/update content
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use a specific URLRequest to bypass local caching protocols if necessary,
            // or rely on standard URLSession behavior.
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let downloadedImage = UIImage(data: data) {
                // 3. Update UI and Cache with the fresh image
                // Only trigger a UI update if the data actually changed or if we didn't have an image before
                if downloadedImage != self.image {
                    ImageCache.shared.set(image: downloadedImage, for: url)
                    withAnimation {
                        self.image = downloadedImage
                    }
                }
            }
        } catch {
            print("Failed to load image from \(url): \(error.localizedDescription)")
        }
    }
}
