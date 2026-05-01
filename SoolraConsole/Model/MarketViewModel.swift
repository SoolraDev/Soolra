//
//  MarketViewModel.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

enum MarketFilter {
    case all
    case mine
}

@MainActor
class MarketViewModel: ObservableObject {
    @Published var listings: [MarketplaceListing] = []
    @Published var isLoading = false
    @Published var isProcessingAction = false // For buy/list/delist spinners
    @Published var filter: MarketFilter = .all

    // Pagination (only used for the .all feed; .mine returns the full set)
    @Published var offset = 0
    let limit = 20
    @Published var hasMore = true

    // Toast State
    @Published var toastMessage: String?
    @Published var showToast = false
    @Published var isErrorToast = false

    private let apiClient = ApiClient()

    // MARK: - Data Fetching

    func setFilter(_ newFilter: MarketFilter) async {
        guard newFilter != filter else { return }
        filter = newFilter
        await fetchListings(reset: true)
    }

    func fetchListings(reset: Bool = false) async {
        if reset {
            offset = 0
            listings = []
            hasMore = true
        }

        guard hasMore && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        switch filter {
        case .all:
            if let newItems = await apiClient.fetchMarketplaceListings(offset: offset, limit: limit) {
                if newItems.count < limit {
                    hasMore = false
                }

                var currentIds = Set(listings.map { $0.id })
                for item in newItems {
                    if !currentIds.contains(item.id) {
                        listings.append(item)
                        currentIds.insert(item.id)
                    }
                }

                offset += newItems.count
            }
        case .mine:
            // The /listings/me endpoint returns the full set in one call.
            if let items = await apiClient.fetchMyMarketplaceListings() {
                listings = items
            }
            hasMore = false
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
