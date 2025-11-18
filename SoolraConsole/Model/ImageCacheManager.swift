//
//  ImageCacheManager.swift
//  SOOLRA
//
//  Created by Michael Essiet on 16/11/2025.
//
import UIKit

/// A thread-safe, in-memory image cache.
class ImageCache {
    /// The shared singleton instance.
    static let shared = ImageCache()

    /// The underlying NSCache for storing UIImages.
    /// NSCache is used because it's thread-safe and automatically handles memory warnings.
    private let cache = NSCache<NSURL, UIImage>()

    /// Private initializer to ensure singleton usage.
    private init() {}

    /// Retrieves an image from the cache for a given URL.
    /// - Parameter url: The URL of the image to retrieve.
    /// - Returns: An optional UIImage if it exists in the cache.
    func get(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    /// Stores an image in the cache for a given URL.
    /// - Parameters:
    ///   - image: The UIImage to store.
    ///   - url: The URL to associate with the image.
    func set(image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
