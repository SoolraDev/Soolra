//
//  SOOLRA - Favoritable Carousel Item
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct FavoritableCarouselItem<Content: View>: View {
    let item: LibraryItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let content: () -> Content
    
    @State private var showFavoriteDialog = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
            
            // Star indicator for favorited items
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 30))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .offset(x: 25, y: -25)
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            showFavoriteDialog = true
        }
        .confirmationDialog(
            "",
            isPresented: $showFavoriteDialog,
            titleVisibility: .hidden
        ) {
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
