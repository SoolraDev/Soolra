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
    
    // MARK: - Stable ID Generation
    
    private func stableID(for item: LibraryItem) -> String {
        if let rom = item as? Rom {
            return "rom-\(rom.objectID.uriRepresentation().absoluteString)"
        } else if let webGame = item as? WebGame {
            return "web-\(webGame.name)" // Use name, not UUID id
        }
        return "unknown-\(item.displayName)"
    }
    
    // MARK: - Public Methods
    
    func isFavorite(_ item: LibraryItem) -> Bool {
        return favoriteIds.contains(stableID(for: item))
    }
    
    func toggleFavorite(_ item: LibraryItem) {
        let id = stableID(for: item)
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        saveFavorites()
    }
    
    func addToFavorites(_ item: LibraryItem) {
        favoriteIds.insert(stableID(for: item))
        saveFavorites()
    }
    
    func removeFromFavorites(_ item: LibraryItem) {
        favoriteIds.remove(stableID(for: item))
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
