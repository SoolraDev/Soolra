//
//  VerticalGameCarousel.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 23/10/2025.
//

import SwiftUI

// MARK: - Public wrapper
/// Drop-in vertical game picker with iOS 17+ paging and an iOS 16 fallback.
/// - Use `VerticalGameCarousel(focusedIndex:onOpen:)` anywhere in your UI.
/// - Bind `focusedIndex` to your existing `viewModel.focusedButtonIndex`.
/// - Supply your items in display order via the `items` parameter.
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

    // Live depth ordering: distance of each card's midY from viewport center
    @State private var distances: [UUID: CGFloat] = [:]

    private struct CardDistanceKey: PreferenceKey {
        static var defaultValue: [UUID: CGFloat] = [:]
        static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    var body: some View {
        let overlapSpacing = -(cardSizeUnfocused.height - reveal) + extraGap
        let viewportHeight = cardSizeFocused.height + 2 * reveal
        let verticalMargin = viewportHeight / 2 - cardSizeFocused.height / 2
        let focusedScale: CGFloat = 0.75
        let unfocusedScale: CGFloat = (cardSizeUnfocused.height / cardSizeFocused.height) * 0.75

        GeometryReader { outer in
            ScrollView(.vertical) {
                LazyVStack(spacing: overlapSpacing) {
                    ForEach(items.indices, id: \.self) { index in
                        let (kind, item) = items[index]
                        let isFocused = (index == currentSelectedIndex)
                        
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
                        .zIndex(zFor(item.id))
                        .overlay(
                            VStack {
                                Text("z: \(zFor(item.id)))")
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
                        .compositingGroup()
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: viewportHeight)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.vertical, verticalMargin)
            .scrollIndicators(.hidden)
            .clipped()
            .transaction { $0.animation = nil }
        }
        .onPreferenceChange(CardDistanceKey.self) { distances = $0 }
        .onAppear {
            // Convert HomeView index to carousel index
            let carouselIndex = max(0, focusedIndex - indexOffset)
            currentSelectedIndex = carouselIndex
            selectedID = items[safe: carouselIndex]?.1.id
        }
        .scrollPosition(id: $selectedID, anchor: .center)
        .onChange(of: focusedIndex) { _, newValue in
            // Convert HomeView index to carousel index
            let carouselIndex = max(0, newValue - indexOffset)
            currentSelectedIndex = carouselIndex
            
            // Animate the scroll transition
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedID = items[safe: carouselIndex]?.1.id
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
        let d = abs(distances[id] ?? .greatestFiniteMagnitude)
        return Double(10_000 - min(9_999, d)) + 0.0001
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
