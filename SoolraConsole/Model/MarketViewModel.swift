//
//  MarketViewModel.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

@MainActor
class MarketViewModel: ObservableObject {
    @Published var listings: [MarketplaceListing] = []
    @Published var isLoading = false
    @Published var isProcessingAction = false // For buy/list/delist spinners
    
    // Pagination
    @Published var offset = 0
    let limit = 20
    @Published var hasMore = true
    
    // Toast State
    @Published var toastMessage: String?
    @Published var showToast = false
    @Published var isErrorToast = false

    private let apiClient = ApiClient()
    
    // MARK: - Data Fetching
    
    func fetchListings(reset: Bool = false) async {
        if reset {
            offset = 0
            listings = []
            hasMore = true
        }
        
        guard hasMore && !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        if let newItems = await apiClient.fetchMarketplaceListings(offset: offset, limit: limit) {
            if newItems.count < limit {
                hasMore = false
            }
            
            // Append and deduplicate based on ID just in case
            var currentIds = Set(listings.map { $0.id })
            for item in newItems {
                if !currentIds.contains(item.id) {
                    listings.append(item)
                    currentIds.insert(item.id)
                }
            }
            
            offset += newItems.count
        }
    }
    
    // MARK: - Actions
    
    func purchaseItem(listing: MarketplaceListing) async {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        
        if await apiClient.purchaseListing(listingId: listing.id) != nil {
            showToast(message: "Purchase successful!", isError: false)
            // Remove from local list immediately for better UX
            removeListingLocally(id: listing.id)
        } else {
            showToast(message: "Purchase failed. Check balance.", isError: true)
        }
        
        isProcessingAction = false
    }
    
    func delistItem(listing: MarketplaceListing) async {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        
        if await apiClient.delistItem(listingId: listing.id) != nil {
            showToast(message: "Item delisted.", isError: false)
            removeListingLocally(id: listing.id)
        } else {
            showToast(message: "Delisting failed.", isError: true)
        }
        
        isProcessingAction = false
    }
    
    // Helper to update UI without re-fetching
    private func removeListingLocally(id: String) {
        withAnimation {
            listings.removeAll { $0.id == id }
        }
    }
    
    // MARK: - Toast Helper
    private func showToast(message: String, isError: Bool) {
        self.toastMessage = message
        self.isErrorToast = isError
        withAnimation {
            self.showToast = true
        }
        
        // Auto hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showToast = false
            }
        }
    }
}
