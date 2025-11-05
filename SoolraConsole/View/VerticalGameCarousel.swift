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
    private let cardSizeFocused = CGSize(width: 230, height: 230)
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
    @State private var selectedID: String?
    @State private var currentSelectedIndex: Int
    @State private var pendingScrollTask: Task<Void, Never>?
    @State private var isInitialScrollComplete: Bool = false
    
    // Live depth ordering: distance of each card's midY from viewport center
    @State private var distances: [UUID: CGFloat] = [:]
    
    private struct CardDistanceKey: PreferenceKey {
        static var defaultValue: [UUID: CGFloat] = [:]
        static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }
    
    // Helper to create compound ID
    private func compoundID(for item: LibraryItem, zIndex: Double) -> String {
        let zBucket = Int(zIndex / 50)
        return "\(item.id.uuidString)-\(zBucket)"
    }
    
    // CHANGE 1: Add custom init to set selectedID to correct position
    init(focusedIndex: Binding<Int>, items: [(LibraryKind, LibraryItem)], indexOffset: Int, onOpen: @escaping (LibraryKind, LibraryItem) -> Void, cardSizeFocused: CGSize, cardSizeUnfocused: CGSize) {
        self._focusedIndex = focusedIndex
        self.items = items
        self.indexOffset = indexOffset
        self.onOpen = onOpen
        self.cardSizeFocused = cardSizeFocused
        self.cardSizeUnfocused = cardSizeUnfocused
        
        // Calculate correct carousel index
        let carouselIndex = max(0, focusedIndex.wrappedValue - indexOffset)
        self._currentSelectedIndex = State(initialValue: carouselIndex)
        
        // Set selectedID to the correct position (not item 0)
        if !items.isEmpty, carouselIndex < items.count {
            let item = items[carouselIndex].1
            let defaultZIndex = 10000.0
            let zBucket = Int(defaultZIndex / 50)
            let initialID = "\(item.id.uuidString)-\(zBucket)"
            self._selectedID = State(initialValue: initialID)
        } else {
            self._selectedID = State(initialValue: nil)
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
                        let zIndex = zFor(item.id)
                        let itemID = compoundID(for: item, zIndex: zIndex)
                        
                        CarouselCard(
                            kind: kind,
                            item: item,
                            isFocused: isFocused,
                            cardSizeFocused: cardSizeFocused,
                            cardSizeUnfocused: cardSizeUnfocused
                        )
                        .onTapGesture { onOpen(kind, item) }
                        .id(itemID)
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
                        .zIndex(zIndex)
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
            .opacity(isInitialScrollComplete ? 1 : 0)
        }
        .onPreferenceChange(CardDistanceKey.self) { distances = $0 }
        .onAppear {
            let carouselIndex = max(0, focusedIndex - indexOffset)
            currentSelectedIndex = carouselIndex
            // CHANGE 2: Only set if nil, and use carouselIndex not 0
            if selectedID == nil && !items.isEmpty {
                let safeIndex = min(carouselIndex, items.count - 1)
                let item = items[safeIndex].1
                let zIndex = zFor(item.id)
                selectedID = compoundID(for: item, zIndex: zIndex)
            }
            print("🎬 Carousel onAppear - focusedIndex: \(focusedIndex), carouselIndex: \(carouselIndex), items.count: \(items.count), selectedID: \(String(describing: selectedID))")
            
            // Force scroll to position after layout
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms - just enough for layout
                if !items.isEmpty {
                    let safeIndex = min(carouselIndex, items.count - 1)
                    let item = items[safeIndex].1
                    let zIndex = zFor(item.id)
                    let targetID = compoundID(for: item, zIndex: zIndex)
                    selectedID = targetID
                    print("📍 Scrolled to: \(targetID)")
                }
                // Show carousel after scroll completes
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms to ensure scroll is done
                isInitialScrollComplete = true
            }
        }
        .onChange(of: items.count) { oldCount, newCount in
            print("📦 Items count changed: \(oldCount) → \(newCount)")
            if selectedID == nil && !items.isEmpty {
                let item = items[0].1
                let zIndex = zFor(item.id)
                selectedID = compoundID(for: item, zIndex: zIndex)
                print("✨ Initialized selectedID to first item: \(String(describing: selectedID))")
            }
        }
        .scrollPosition(id: $selectedID, anchor: .center)
        .onChange(of: focusedIndex) { oldValue, newValue in
            let carouselIndex = max(0, newValue - indexOffset)
            currentSelectedIndex = carouselIndex
            
            pendingScrollTask?.cancel()
            
            pendingScrollTask = Task { @MainActor in
                guard !Task.isCancelled else { return }
                guard let (_, item) = items[safe: carouselIndex] else { return }
                let zIndex = zFor(item.id)
                let targetID = compoundID(for: item, zIndex: zIndex)
                withAnimation(.easeOut(duration: 0.08)) {
                    selectedID = targetID
                }
            }
        }
        .onChange(of: selectedID) { _, newID in
            guard let newID = newID,
                  let lastDashIndex = newID.lastIndex(of: "-") else { return }
            let uuidString = String(newID[..<lastDashIndex])
            
            if let uuid = UUID(uuidString: uuidString),
               let i = items.firstIndex(where: { $0.1.id == uuid }) {
                currentSelectedIndex = i
                focusedIndex = i + indexOffset
            }
        }
        .onChange(of: distances) { _, _ in
            guard let index = items.indices.first(where: { items[$0].1.id.uuidString == selectedID?.split(separator: "-").first.map(String.init) }) else { return }
            let item = items[index].1
            let newZIndex = zFor(item.id)
            let newID = compoundID(for: item, zIndex: newZIndex)
            if newID != selectedID {
                selectedID = newID
            }
        }
    }
    
    private func zFor(_ id: UUID) -> Double {
        guard let d = distances[id], d.isFinite else {
            return 0
        }
        let distance = abs(d)
        let clampedDistance = min(distance, 9_999)
        return Double(10_000) - clampedDistance
    }
}
// MARK: - Card (shared)
@available(iOS 17, *)
fileprivate struct CarouselCard: View {
    let kind: LibraryKind
    let item: LibraryItem
    let isFocused: Bool
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    
    var body: some View {
        let strokeOpacity = isFocused ? 0.85 : 0.20
        let strokeWidth: CGFloat = isFocused ? 3 : 1
        
        ZStack(alignment: .bottom) {
            artwork
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
//                        .stroke(.white.opacity(strokeOpacity), lineWidth: strokeWidth)
                        .stroke(Color(red: 252/255, green: 112/255, blue: 242/255).opacity(strokeOpacity), lineWidth: strokeWidth)
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
        }
        .frame(width: cardSizeFocused.width, height: cardSizeFocused.height)
        .overlay(alignment: .bottom) {
            if isFocused {
                Text(item.displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)
                    .padding(.bottom, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 131/255, green: 37/255, blue: 126/255).opacity(1),
                                Color(red: 131/255, green: 37/255, blue: 126/255).opacity(1),
                                Color(red: 131/255, green: 37/255, blue: 126/255).opacity(0.8),
//                                Color(red: 138/255, green: 39/255, blue: 133/255).opacity(0.8),
//                                Color(red: 138/255, green: 39/255, blue: 133/255).opacity(0.8),
                                Color(red: 191/255, green: 165/255, blue: 189/255).opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 15,
                            bottomTrailingRadius: 15,
                            topTrailingRadius: 0
                        )
                    )
                    .offset(y: 56)
                    
            }
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
// MARK: - Utilities
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
