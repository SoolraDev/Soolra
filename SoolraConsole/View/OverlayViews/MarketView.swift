//
//  MarketView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//

import SwiftUI

struct MarketView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = MarketViewModel()
    @State private var selectedTab: Int = 0 // 0 = ALL, 1 = FILTER...
    @State private var selectedListing: MarketplaceListing?

    var body: some View {
        ZStack {
            // LAYER 1: Main Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Soolra Market")
                        .foregroundStyle(.white)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding()

                // Balance Info
                HStack {
                    Text("SOOL BALANCE")
                    Spacer()
                    Text("0.0") // TODO: Hook up to real balance
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

                // Tabs (Using your AngledBannerShape if available)
                HStack(spacing: 0) {
                    TabButton(title: "ALL ITEMS", isSelected: selectedTab == 0) {
                        selectedTab = 0
                        // Trigger filter logic if needed
                    }
                    
                    TabButton(title: "MY ITEMS", isSelected: selectedTab == 1) {
                        selectedTab = 1
                        // Trigger filter logic if needed
                    }
                }
                .clipShape(AngledBannerShape())
                .gradientBorder(
                    AngledBannerShape(),
                    colors: [
                        Color(hex: "#FF00E1"),
                        Color(hex: "#FCC4FF"),
                    ]
                )
                .padding(.horizontal)
                .zIndex(1)

                // Listings Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.listings) { listing in
                            ListingCard(listing: listing) {
                                withAnimation(.spring()) {
                                    selectedListing = listing
                                }
                            }
                            .onAppear {
                                // Pagination Trigger
                                if listing.id == viewModel.listings.last?.id {
                                    Task { await viewModel.fetchListings() }
                                }
                            }
                        }
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.listings.isEmpty {
                            Text("No items found")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding()
                    .padding(.top, 10)
                }
                .refreshable {
                    await viewModel.fetchListings(reset: true)
                }
            }
            .purpleGradientBackground()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .frame(maxWidth: 400, maxHeight: .infinity)
            .padding()
            
            // LAYER 2: Details Overlay
            if let listing = selectedListing {
                // Dimmer
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { selectedListing = nil }
                    }
                    .zIndex(2)
                
                // Detail Card
                if #available(iOS 17.0, *) {
                    ListingDetailView(
                        listing: listing,
                        viewModel: viewModel,
                        onClose: {
                            withAnimation { selectedListing = nil }
                        }
                    )
                    .zIndex(3)
                    .transition(.scale(0.9))
                } else {
                    // Fallback on earlier versions
                }
            }
            
            // LAYER 3: Toast Notification
            if viewModel.showToast, let msg = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(viewModel.isErrorToast ? Color.red : Color.green)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .padding(.bottom, 50)
                }
                .zIndex(4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // External Overlay Close Button (Matches your original design)
        .overlay(alignment: .topTrailing) {
            if selectedListing == nil {
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
        .task {
            // Initial Fetch on load
            if viewModel.listings.isEmpty {
                await viewModel.fetchListings(reset: true)
            }
        }
    }
}

// MARK: - Subcomponents

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(isSelected ? Color.purple : Color.clear)
        }
    }
}

struct ListingCard: View {
    let listing: MarketplaceListing
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Image
                CachedAsyncImage(url: URL(string: listing.metadata?.image ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "cube.box")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(height: 140)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Text(listing.price.token)
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(4)
                        .padding(4)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.metadata?.name ?? "Unknown Item")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("\(listing.price.formatted)")
                        .font(.callout.bold())
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ListingDetailView: View {
    let listing: MarketplaceListing
    @ObservedObject var viewModel: MarketViewModel
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Large Image
            CachedAsyncImage(url: URL(string: listing.metadata?.image ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView().tint(.white))
            }
            .frame(height: 250)
            .clipped()
            
            VStack(alignment: .leading, spacing: 16) {
                // Title Row
                HStack(alignment: .top) {
                    Text(listing.metadata?.name ?? "Unknown Item")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.title2)
                    }
                }
                
                // Price Tag
                HStack(spacing: 6) {
                    Text(listing.price.formatted)
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                    Text(listing.price.token)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // Metadata
                if let desc = listing.metadata?.description {
                    Text("Description")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
                
                Spacer()
                
                // Action Button
                if viewModel.isProcessingAction {
                    HStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Text("Processing...").font(.caption).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button(action: {
                        Task {
                            // If isOwner -> viewModel.delistItem(listing: listing)
                            // Else ->
                            await viewModel.purchaseItem(listing: listing)
                            if !viewModel.isErrorToast { onClose() }
                        }
                    }) {
                        Text("Purchase Now")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(Color(hex: "#1a1a2e")) // Dark background
        }
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .frame(maxWidth: 350)
        .shadow(radius: 20)
    }
}

// MARK: - Modifiers & Extensions

struct MarketViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    MarketView(isPresented: $isPresented)
                    // If you have an overlayBackground modifier, append it here
                        .background(Color.black.opacity(0.5).ignoresSafeArea())
                }
            }
    }
}

struct MarketViewPreview: View {
    @State var isPresented: Bool = true

    var body: some View {
        MarketView(isPresented: $isPresented)
    }
}

extension View {
    func marketOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(MarketViewModifier(isPresented: isPresented))
    }
}

// MARK: - Previews

#Preview("Market Main") {
    MarketViewPreview()
}

#Preview("Detail View (Mock)") {
    ZStack {
        Color.black.ignoresSafeArea()
        ListingDetailView(
            listing: .mock,
            viewModel: MarketViewModel(),
            onClose: {}
        )
    }
}

#Preview("Listing Card (Mock)") {
    ZStack {
        Color.gray.ignoresSafeArea()
        ListingCard(listing: .mock) {
            print("Tapped")
        }
        .frame(width: 170)
        .padding()
    }
}

// MARK: - Mock Data Helper
extension MarketplaceListing {
    static let mock = MarketplaceListing(
        id: "1",
        seller: "0x123...",
        nftAddress: "0xabc...",
        tokenId: "420",
        price: ListingPrice(raw: "1000", formatted: "150.0", token: "SOOL"),
        paymentToken: .SOOL,
        active: true,
        metadata: NFTMetadata(
            name: "Cosmic Shield #420",
            description: "A legendary shield forged in the nebula. Grants +50 defense.",
            image: "https://via.placeholder.com/500",
            attributes: [],
        )
    )
}
