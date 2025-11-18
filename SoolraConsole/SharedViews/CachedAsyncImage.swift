//
//  CachedAsyncImage.swift
//  SOOLRA
//
//  Created by Michael Essiet on 16/11/2025.
//
import SwiftUI

/// A view that asynchronously loads, caches, and displays an image.
///
/// This view first checks an in-memory cache for the image. If the image is found,
/// it's displayed immediately. Otherwise, it downloads the image from the given URL,
/// stores it in the cache, and then displays it.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    // Use the @StateObject pattern if you were to create a more complex loader object.
    // For this direct implementation, @State is sufficient.
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
        if let image = image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .task(id: url) { // .task is recommended for async operations in SwiftUI
                    await loadImage()
                }
        }
    }
    
    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        
        // 1. Check cache first
        if let cachedImage = ImageCache.shared.get(for: url) {
            self.image = cachedImage
            return
        }
        
        // 2. If not in cache, start download
        isLoading = true
        defer { isLoading = false } // Ensure isLoading is reset
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                // 3. Save to cache and update UI
                ImageCache.shared.set(image: downloadedImage, for: url)
                self.image = downloadedImage
            }
        } catch {
            print("Failed to load image from \(url): \(error.localizedDescription)")
            // Handle error state if needed, e.g., show a different placeholder
        }
    }
}
