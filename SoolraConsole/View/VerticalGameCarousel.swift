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
        } else {
            VerticalCarousel_Legacy(
                focusedIndex: $focusedIndex,
                roms: roms,
                onOpen: onOpen,
                cardSizeFocused: cardSizeFocused,
                cardSizeUnfocused: cardSizeUnfocused,
                spacing: spacing
            )
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
    private let extraGap: CGFloat = 10
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize

    @State private var selectedID: Rom.ID?
    @State private var currentSelectedIndex: Int = 0

    var body: some View {
        // Precompute scalars to keep closures simple (helps the type-checker)
        let overlapSpacing = -(cardSizeUnfocused.height - reveal) + extraGap
        let viewportHeight = cardSizeFocused.height + 2 * reveal
        let verticalMargin = viewportHeight / 2 - cardSizeFocused.height / 2
        let focusedScale: CGFloat = 0.75
        let unfocusedScale: CGFloat = (cardSizeUnfocused.height / cardSizeFocused.height) * 0.75

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
                .padding(.horizontal, 10).padding(.vertical, 6)
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

fileprivate struct VerticalCarousel_Legacy: View {
    @Binding var focusedIndex: Int
    let roms: [Rom]
    let onOpen: (Rom) -> Void

    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    let spacing: CGFloat

    @State private var offset: CGFloat = 0
    @GestureState private var drag: CGFloat = 0

    var step: CGFloat { cardSizeUnfocused.height + spacing }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: spacing) {
                ForEach(roms.indices, id: \.self) { i in
                    let rom = roms[i]
                    let scale = focusScale(for: i)
                    let isFocused = isIndexFocused(i)

                    CarouselCard(
                        rom: rom,
                        isFocused: isFocused,
                        cardSizeFocused: cardSizeFocused,
                        cardSizeUnfocused: cardSizeUnfocused
                    )
                    .scaleEffect(scale) // transform applied outside the card
                    // IMPORTANT: no per-item animation during drag; snap anim happens below
                    .onTapGesture { onOpen(rom) }
                    .frame(height: cardSizeUnfocused.height)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .offset(y: offset + drag)
            .gesture(
                DragGesture()
                    .updating($drag) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let proposed = offset + value.translation.height
                        let next = snapOffset(from: proposed, count: roms.count)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            offset = next
                        }
                        let idx = Int(round(-next / step))
                        focusedIndex = 4 + max(0, min(idx, roms.count - 1))
                    }
            )
            .onAppear {
                let idx = max(0, focusedIndex - 4)
                offset = -CGFloat(idx) * step
            }
            .onChange(of: focusedIndex) { newValue in
                let idx = max(0, newValue - 4)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    offset = -CGFloat(idx) * step
                }
            }
        }
    }

    private func snapOffset(from proposed: CGFloat, count: Int) -> CGFloat {
        let idxFloat = -proposed / step
        let idx = max(0, min(Int(idxFloat.rounded()), count - 1))
        return -CGFloat(idx) * step
    }

    private func focusScale(for i: Int) -> CGFloat {
        let idxFloat = -(offset + drag) / step
        // 0.86..1.0 smooth bell around the centered row
        return 0.86 + 0.14 * max(0, 1 - abs(CGFloat(i) - idxFloat))
    }

    private func isIndexFocused(_ i: Int) -> Bool {
        let idx = max(0, min(Int(round(-(offset + drag) / step)), roms.count - 1))
        return i == idx
    }
}

// MARK: - Utilities

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
