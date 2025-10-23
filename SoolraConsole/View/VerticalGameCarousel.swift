//
//  VerticalGameCarousel.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 23/10/2025.
//


import SwiftUI

fileprivate struct CarouselItem: Identifiable {
    let id: UUID
    let rom: Rom
}



/// Drop-in vertical game picker with iOS 17+ paging and an iOS 16 fallback.
/// - Use `VerticalGameCarousel(focusedIndex:onOpen:)` anywhere in your UI.
/// - Bind `focusedIndex` to your existing `viewModel.focusedButtonIndex`.
/// - Supply your ROMs in display order via the `roms` parameter.
public struct VerticalGameCarousel: View {
    @Binding var focusedIndex: Int // absolute index aligned with your HomeView (0..N). Typically 4+ maps to first ROM.
    let roms: [Rom]
    let onOpen: (Rom) -> Void

    // Layout knobs (match your screenshot vibe)
    private let cardSizeFocused = CGSize(width: 220, height: 220)
    private let cardSizeUnfocused = CGSize(width: 180, height: 180)
    private let spacing: CGFloat = 22

    public init(focusedIndex: Binding<Int>, roms: [Rom], onOpen: @escaping (Rom) -> Void) {
        self._focusedIndex = focusedIndex
        self.roms = roms
        self.onOpen = onOpen
    }

    public var body: some View {
        if #available(iOS 17, *) {
            VerticalCarousel_iOS17(focusedIndex: $focusedIndex, roms: roms, onOpen: onOpen)
        } else {
            VerticalCarousel_Legacy(focusedIndex: $focusedIndex, roms: roms, onOpen: onOpen,
                                    cardSizeFocused: cardSizeFocused,
                                    cardSizeUnfocused: cardSizeUnfocused,
                                    spacing: spacing)
        }
    }
}

// MARK: - iOS 17+ implementation
@available(iOS 17, *)
fileprivate struct VerticalCarousel_iOS17: View {
    @Binding var focusedIndex: Int
    let roms: [Rom]
    let onOpen: (Rom) -> Void
    
    // NEW: expose both knobs
    private let reveal: CGFloat = 48   // was 36; increase to show more of prev/next
    private let extraGap: CGFloat = 150  // NEW: constant extra spacing between cards
    
    // e.g. when you create the carousel
    let cardSizeFocused = CGSize(width: 220, height: 220)
    let cardSizeUnfocused = CGSize(width: 170, height: 170) // smaller than before
    
    @State private var selectedID: Rom.ID?
    @State private var currentSelectedIndex: Int = 0  // ← Track selected index directly
    
    var body: some View {
        let overlapSpacing = -(cardSizeUnfocused.height - reveal) + extraGap
        let viewportHeight = cardSizeFocused.height + 2 * reveal
        
        ScrollView(.vertical) {
            LazyVStack(spacing: overlapSpacing) {
                ForEach(Array(roms.enumerated()), id: \.element.id) { index, rom in
                    let isFocused = (index == currentSelectedIndex)  // ← Use currentSelectedIndex
                    
                    // Selected card gets highest z-index (1000)
                    // Cards get lower z-index based on distance from selected
                    let zIndex = isFocused ? 1000.0 : (1000.0 - Double(abs(index - currentSelectedIndex)))  // ← Use currentSelectedIndex
                    
                    CarouselCard(
                        rom: rom,
                        isFocused: isFocused,
                        cardSizeFocused: cardSizeFocused,
                        cardSizeUnfocused: cardSizeUnfocused
                    )
                    .zIndex(zIndex)
                    .onTapGesture { onOpen(rom) }
                    .id(rom.id)
                }
            }
//            .animation(.bouncy(duration: 0.34, extraBounce: 0.12), value: currentSelectedIndex)
            .scrollTargetLayout()
        }
        .frame(height: viewportHeight)
        .scrollPosition(id: $selectedID, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.vertical, viewportHeight / 2 - cardSizeFocused.height / 2)
        .scrollIndicators(.hidden)
        .clipped()
        .onAppear {
            currentSelectedIndex = focusedIndex  // ← Initialize
            selectedID = roms[safe: focusedIndex]?.id
        }
        .onChange(of: focusedIndex) { _, newValue in
            // no withAnimation here
            currentSelectedIndex = newValue
            selectedID = roms[safe: newValue]?.id
        }

        .onChange(of: selectedID) { _, newID in
            if let index = roms.firstIndex(where: { $0.id == newID }) {
                // no withAnimation here either
                currentSelectedIndex = index
                focusedIndex = index
            }
        }


    }
}



fileprivate struct CarouselCard: View {
    let rom: Rom
    let isFocused: Bool
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize

    var body: some View {
        // Scale relative to unfocused size
        let targetScale = isFocused
            ? 1.0
            : (cardSizeUnfocused.height / cardSizeFocused.height)

        let strokeOpacity = isFocused ? 0.85 : 0.20
        let strokeWidth: CGFloat = isFocused ? 3 : 1
        let blur: CGFloat = isFocused ? 0 : 1.5
        let shadowRadius: CGFloat = isFocused ? 16 : 6
        let shadowY: CGFloat = isFocused ? 10 : 4

        ZStack(alignment: .bottomLeading) {
            artwork
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: strokeWidth)
                )

            // Game title
            Text(rom.name ?? "Unknown")
                .font(.system(size: isFocused ? 16 : 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
        }
        // Outer frame fixed — inner scales smoothly
        .frame(width: cardSizeFocused.width, height: cardSizeFocused.height)
        .scaleEffect(targetScale)
        .blur(radius: blur)
        .shadow(radius: shadowRadius, y: shadowY)
        // Animate on focus change
        .animation(.smooth(duration: 0.28), value: isFocused)
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

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                ForEach(Array(roms.enumerated()), id: \.0) { (i, rom) in
                    let scale = focusScale(for: i)
                    CarouselCard(
                        rom: rom,
                        isFocused: isIndexFocused(i),
                        cardSizeFocused: cardSizeFocused,
                        cardSizeUnfocused: cardSizeUnfocused
                    )
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: offset + drag)
                    .onTapGesture { onOpen(rom) }
                    .frame(height: cardSizeUnfocused.height)
                }

            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .offset(y: offset + drag)
            .gesture(
                DragGesture()
                    .updating($drag) { value, state, _ in state = value.translation.height }
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
                // align with incoming focusedIndex
                let idx = max(0, focusedIndex - 4)
                offset = -CGFloat(idx) * step
            }
            .onChange(of: focusedIndex) { newValue in
                // external changes (e.g., controller)
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
        return 0.86 + 0.14 * max(0, 1 - abs(CGFloat(i) - idxFloat))
    }

    private func isIndexFocused(_ i: Int) -> Bool {
        let idx = max(0, min(Int(round(-(offset + drag) / step)), roms.count - 1))
        return i == idx
    }
}
