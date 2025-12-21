//
//  FavoritesManager.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 21/12/2025.
//


//
//  SOOLRA - Favorites Manager
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import Combine

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published private(set) var favoriteIds: Set<String> = []
    
    private let userDefaultsKey = "soolra.favorites"
    
    private init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    func isFavorite(_ item: LibraryItem) -> Bool {
        return favoriteIds.contains(item.id)
    }
    
    func toggleFavorite(_ item: LibraryItem) {
        if favoriteIds.contains(item.id) {
            favoriteIds.remove(item.id)
        } else {
            favoriteIds.insert(item.id)
        }
        saveFavorites()
    }
    
    func addToFavorites(_ item: LibraryItem) {
        favoriteIds.insert(item.id)
        saveFavorites()
    }
    
    func removeFromFavorites(_ item: LibraryItem) {
        favoriteIds.remove(item.id)
        saveFavorites()
    }
    
    // MARK: - Persistence
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            favoriteIds = Set(data)
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: userDefaultsKey)
    }
}

// MARK: - LibraryItem Extension for Favorites

extension LibraryItem {
    var id: String {
        // Generate unique ID based on item type
        if let rom = self as? Rom {
            return "rom-\(rom.objectID.uriRepresentation().absoluteString)"
        } else if let webGame = self as? WebGame {
            return "web-\(webGame.id)"
        }
        return UUID().uuidString
    }
}