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
/// - Supply your ROMs in display order via the `roms` parameter.
public struct VerticalGameCarousel: View {
    @Binding var focusedIndex: Int // absolute index aligned with your HomeView (0..N). Typically 4+ maps to first ROM.
    let roms: [Rom]
    let onOpen: (Rom) -> Void

    // Layout knobs
    private let cardSizeFocused = CGSize(width: 220, height: 220)
    private let cardSizeUnfocused = CGSize(width: 170, height: 170)
    private let spacing: CGFloat = 22

    public init(focusedIndex: Binding<Int>, roms: [Rom], onOpen: @escaping (Rom) -> Void) {
        self._focusedIndex = focusedIndex
        self.roms = roms
        self.onOpen = onOpen
    }

    public var body: some View {
        if #available(iOS 17, *) {
            VerticalCarousel_iOS17(
                focusedIndex: $focusedIndex,
                roms: roms,
                onOpen: onOpen,
                cardSizeFocused: cardSizeFocused,
                cardSizeUnfocused: cardSizeUnfocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // ⬅️ pin to top
            .ignoresSafeArea(edges: .top)                                       // ⬅️ start at screen y=0
        } else {
            // ...
            EmptyView()
        }


    }
}

// MARK: - iOS 17+ implementation

@available(iOS 17, *)
fileprivate struct VerticalCarousel_iOS17: View {
    @Binding var focusedIndex: Int
    let roms: [Rom]
    let onOpen: (Rom) -> Void

    // Layout
    private let reveal: CGFloat = 48
    private let extraGap: CGFloat = 70
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize

    // Paging & selection sync
    @State private var selectedID: Rom.ID?
    @State private var currentSelectedIndex: Int = 0

    // Live depth ordering: distance of each card's midY from viewport center
    @State private var distances: [Rom.ID: CGFloat] = [:]

    private struct CardDistanceKey: PreferenceKey {
        static var defaultValue: [Rom.ID: CGFloat] = [:]
        static func reduce(value: inout [Rom.ID: CGFloat], nextValue: () -> [Rom.ID: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    var body: some View {
        // Precompute scalars to keep closures simple (helps the type-checker)
        let overlapSpacing = -(cardSizeUnfocused.height - reveal) + extraGap
        let viewportHeight = cardSizeFocused.height + 2 * reveal
        let verticalMargin = viewportHeight / 2 - cardSizeFocused.height / 2
        let focusedScale: CGFloat = 0.75
        let unfocusedScale: CGFloat = (cardSizeUnfocused.height / cardSizeFocused.height) * 0.75

        GeometryReader { outer in
            ScrollView(.vertical) {
                LazyVStack(spacing: overlapSpacing) {
                    ForEach(roms.indices, id: \.self) { index in
                        let rom = roms[index]
                        let isFocused = (index == currentSelectedIndex)

                        CarouselCard(
                            rom: rom,
                            isFocused: isFocused,
                            cardSizeFocused: cardSizeFocused,
                            cardSizeUnfocused: cardSizeUnfocused
                        )
                        .onTapGesture { onOpen(rom) }
                        .id(rom.id)
                        .modifier(ScaleOnScroll(focusedScale: focusedScale, unfocusedScale: unfocusedScale))
                        // Measure each card's center vs. the ScrollView viewport center
                        .background(
                            GeometryReader { cardGeo in
                                let cardMidY = cardGeo.frame(in: .global).midY
                                let viewportMid = outer.frame(in: .global).midY
                                Color.clear
                                    .preference(key: CardDistanceKey.self,
                                                value: [rom.id: cardMidY - viewportMid])
                            }
                        )
                        // Proximity-based z-index so the visually centered card stays on top
                        .zIndex(zFor(rom))
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
            // Avoid implicit animations while the scroll view is moving
            .transaction { $0.animation = nil }
        }
        .onPreferenceChange(CardDistanceKey.self) { distances = $0 }
        .onAppear {
            currentSelectedIndex = focusedIndex
            selectedID = roms[safe: focusedIndex]?.id
        }
        .scrollPosition(id: $selectedID, anchor: .center)
        .onChange(of: focusedIndex) { _, newValue in
            currentSelectedIndex = newValue
            selectedID = roms[safe: newValue]?.id
        }
        .onChange(of: selectedID) { _, newID in
            if let i = roms.firstIndex(where: { $0.id == newID }) {
                currentSelectedIndex = i
                focusedIndex = i
            }
        }
    }

    private func zFor(_ rom: Rom) -> Double {
        // Smaller distance => higher z. Clamp to keep numbers sane.
        let d = abs(distances[rom.id] ?? .greatestFiniteMagnitude)
        // Invert and scale; add a tiny tie-breaker so equal distances don’t flicker.
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
    let rom: Rom
    let isFocused: Bool
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize

    var body: some View {
        // Keep the outer frame constant; transforms are applied by container (iOS 17) or caller (iOS 16)
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

            Text(rom.name ?? "Unknown")
                .font(.system(size: isFocused ? 16 : 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
        }
        .frame(width: cardSizeFocused.width, height: cardSizeFocused.height)
        // No scale/animation here — avoids jitter on fast scroll
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = rom.imageData, let ui = UIImage(data: data) {
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

// MARK: - Legacy (iOS 16) implementation
// TODO: add if needed (e.g., manual offset/scale and the same proximity-based zIndex via GeometryReader).

// MARK: - Utilities

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
