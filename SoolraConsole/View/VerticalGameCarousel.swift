
//  VerticalGameCarousel.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 23/10/2025.
//
import SwiftUI
// MARK: - Public wrapper
/// Drop-in vertical game picker with iOS 17+ paging and an iOS 16 fallback.
/// - Use VerticalGameCarousel(focusedIndex:onOpen:) anywhere in your UI.
/// - Bind focusedIndex to your existing viewModel.focusedButtonIndex.
/// - Supply your items in display order via the items parameter.
struct VerticalGameCarousel: View {
    @Binding var focusedIndex: Int
    let items: [(LibraryKind, LibraryItem)]
    let onOpen: (LibraryKind, LibraryItem) -> Void
    let indexOffset: Int // Offset to convert HomeView index to carousel index
    // Layout knobs
    private let cardSizeFocused = CGSize(width: 220, height: 220)
    private let cardSizeUnfocused = CGSize(width: 120, height: 120)
    private let spacing: CGFloat = 22
    init(
        focusedIndex: Binding<Int>,
        items: [(LibraryKind, LibraryItem)],
        indexOffset: Int = 4, // Default offset for nav buttons
        onOpen: @escaping (LibraryKind, LibraryItem) -> Void
    ) {
        self._focusedIndex = focusedIndex
        self.items = items
        self.indexOffset = indexOffset
        self.onOpen = onOpen
    }
    var body: some View {
        if #available(iOS 17, *) {
            VerticalCarousel_iOS17(
                focusedIndex: $focusedIndex,
                items: items,
                indexOffset: indexOffset,
                onOpen: onOpen,
                cardSizeFocused: cardSizeFocused,
                cardSizeUnfocused: cardSizeUnfocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        } else {
            EmptyView()
        }
    }
}
// MARK: - iOS 17+ implementation
@available(iOS 17, *)
fileprivate struct VerticalCarousel_iOS17: View {
    @Binding var focusedIndex: Int
    let items: [(LibraryKind, LibraryItem)]
    let indexOffset: Int
    let onOpen: (LibraryKind, LibraryItem) -> Void
    // Layout
    private let reveal: CGFloat = 100
    private let extraGap: CGFloat = -100
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    // Paging & selection sync
    @State private var selectedID: UUID?
    @State private var currentSelectedIndex: Int = 0
    @State private var pendingScrollTask: Task<Void, Never>?
    // Live depth ordering: distance of each card's midY from viewport center
    @State private var distances: [UUID: CGFloat] = [:]
    private struct CardDistanceKey: PreferenceKey {
        static var defaultValue: [UUID: CGFloat] = [:]
        static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }
    var body: some View {
        let overlapAmount: CGFloat = 20 // How much cards overlap
        let cardSpacing = cardSizeUnfocused.height - overlapAmount
        let viewportHeight = cardSizeFocused.height + 2 * reveal
        let verticalMargin = viewportHeight / 2 - cardSizeFocused.height / 2
        let focusedScale: CGFloat = 0.75
        let unfocusedScale: CGFloat = (cardSizeUnfocused.height / cardSizeFocused.height) * 0.75
        GeometryReader { outer in
            ScrollView(.vertical) {
                // Use ZStack for proper z-index control
                ZStack(alignment: .top) {
                    // Create cards in reverse order so higher indices naturally appear on top
                    ForEach(Array(items.enumerated()), id: \.offset) { index, tuple in
                        let (kind, item) = tuple
                        let isFocused = (index == currentSelectedIndex)
                        
                        // Calculate card position
                        let yOffset = CGFloat(index) * cardSpacing
                        
                        CarouselCard(
                            kind: kind,
                            item: item,
                            isFocused: isFocused,
                            cardSizeFocused: cardSizeFocused,
                            cardSizeUnfocused: cardSizeUnfocused
                        )
                        .onTapGesture { onOpen(kind, item) }
                        .id(item.id)
                        .modifier(ScaleOnScroll(focusedScale: focusedScale, unfocusedScale: unfocusedScale))
                        .background(
                            GeometryReader { cardGeo in
                                let cardMidY = cardGeo.frame(in: .global).midY
                                let viewportMid = outer.frame(in: .global).midY
                                Color.clear
                                    .preference(key: CardDistanceKey.self,
                                                value: [item.id: cardMidY - viewportMid])
                            }
                        )
                        .offset(y: yOffset)
                        .zIndex(zFor(item.id))
                        .overlay(
                            VStack {
                                Text("z: \(Int(zFor(item.id)))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                                if let d = distances[item.id] {
                                    Text(String(format: "dy: %.0f", d))
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(8),
                            alignment: .bottomTrailing
                        )
                        // Don't use compositingGroup as it can interfere with z-index
                    }
                    
                    // Invisible view to define scrollable content size
                    Color.clear
                        .frame(height: CGFloat(items.count - 1) * cardSpacing + cardSizeFocused.height)
                }
                .frame(minHeight: CGFloat(items.count - 1) * cardSpacing + cardSizeFocused.height)
            }
            .frame(height: viewportHeight)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.vertical, verticalMargin)
            .scrollIndicators(.hidden)
            .clipped()
            .transaction { $0.animation = nil }
        }
        .onPreferenceChange(CardDistanceKey.self) { newDistances in
            distances = newDistances
        }
        .onAppear {
            // Convert HomeView index to carousel index
            let carouselIndex = max(0, focusedIndex - indexOffset)
            currentSelectedIndex = carouselIndex
            // CRITICAL: Always initialize selectedID to first item so scrollPosition works
            // Even if focusedIndex is 0 (nav area), we still need a valid starting point
            if !items.isEmpty {
                selectedID = items[0].1.id
            }
            print("🎬 Carousel onAppear - focusedIndex: \(focusedIndex), carouselIndex: \(carouselIndex), items.count: \(items.count), selectedID: \(String(describing: selectedID))")
        }
        .onChange(of: items.count) { oldCount, newCount in
            print("📦 Items count changed: \(oldCount) → \(newCount)")
            // If items just loaded and selectedID is still nil, initialize it
            if selectedID == nil && !items.isEmpty {
                selectedID = items[0].1.id
                print("✨ Initialized selectedID to first item: \(String(describing: selectedID))")
            }
        }
        .scrollPosition(id: $selectedID, anchor: .center)
        .onChange(of: focusedIndex) { oldValue, newValue in
            // Convert HomeView index to carousel index
            let carouselIndex = max(0, newValue - indexOffset)
            currentSelectedIndex = carouselIndex
            // Cancel any pending scroll
            pendingScrollTask?.cancel()
            // Immediate update for responsive feel
            pendingScrollTask = Task { @MainActor in
                guard !Task.isCancelled else { return }
                let targetID = items[safe: carouselIndex]?.1.id
                // Match animation duration to timer interval for smooth continuous scroll
                withAnimation(.easeOut(duration: 0.08)) {
                    selectedID = targetID
                }
            }
        }
        .onChange(of: selectedID) { _, newID in
            if let i = items.firstIndex(where: { $0.1.id == newID }) {
                currentSelectedIndex = i
                // Convert carousel index back to HomeView index
                focusedIndex = i + indexOffset
            }
        }
    }
    
    private func zFor(_ id: UUID) -> Double {
        // The card closest to the viewport center gets the highest z-index
        // This ensures the middle card overlaps cards both above and below
        
        guard let distance = distances[id] else {
            // Default low z-index for cards without distance info yet
            return 0
        }
        
        let absDistance = abs(distance)
        
        // Use a very high base z-index to ensure proper layering
        // The middle card (smallest distance) gets the highest value
        let maxZ = 100000.0
        
        // Invert the distance so closer cards have much higher z-indices
        // This creates a strong layering effect
        let zIndex = maxZ - min(absDistance * 10, maxZ - 1)
        
        return zIndex
    }
}
/// Tiny modifier that applies a scroll-driven transform (stateless, buttery smooth)
@available(iOS 17, *)
private struct ScaleOnScroll: ViewModifier {
    let focusedScale: CGFloat
    let unfocusedScale: CGFloat
    func body(content: Content) -> some View {
        content.scrollTransition(.interactive, axis: .vertical) { c, phase in
            c
                .scaleEffect(phase.isIdentity ? focusedScale : unfocusedScale)
                .opacity(phase.isIdentity ? 1.0 : 0.95)
        }
    }
}
// MARK: - Card (shared)
fileprivate struct CarouselCard: View {
    let kind: LibraryKind
    let item: LibraryItem
    let isFocused: Bool
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    var body: some View {
        let strokeOpacity = isFocused ? 0.85 : 0.20
        let strokeWidth: CGFloat = isFocused ? 3 : 1
        ZStack(alignment: .bottomLeading) {
            artwork
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: strokeWidth)
                )
            // Add shadow to help with depth perception
            .shadow(color: .black.opacity(isFocused ? 0.3 : 0.1), radius: isFocused ? 10 : 5, y: 2)
            
            // Show wifi badge for web games
            if case .web = kind {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "wifi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.70), in: Circle())
                            .padding(8)
                    }
                }
            }
            Text(item.displayName)
                .font(.system(size: isFocused ? 16 : 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
        }
        .frame(width: cardSizeFocused.width, height: cardSizeFocused.height)
    }
    @ViewBuilder
    private var artwork: some View {
        if let ui = item.iconImage {
            Image(uiImage: ui).resizable()
        } else {
            ZStack {
                Color.gray.opacity(0.25)
                Image(systemName: "gamecontroller.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(36)
                    .foregroundStyle(.white)
            }
        }
    }
}
// MARK: - Utilities
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
