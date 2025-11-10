//  HorizontalGameCarousel.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 23/10/2025.
//
import SwiftUI

// MARK: - Public wrapper
/// Drop-in horizontal game picker with iOS 17+ paging and an iOS 16 fallback.
/// - Use HorizontalGameCarousel(focusedIndex:onOpen:) anywhere in your UI.
/// - Bind focusedIndex to your existing viewModel.focusedButtonIndex.
/// - Supply your items in display order via the items parameter.
struct HorizontalGameCarousel: View {
    @Binding var focusedIndex: Int
    let items: [(LibraryKind, LibraryItem)]
    let onOpen: (LibraryKind, LibraryItem) -> Void
    let indexOffset: Int // Offset to convert HomeView index to carousel index
    
    // Layout knobs
    private let cardSizeFocused = CGSize(width: 230, height: 230)
    private let cardSizeUnfocused = CGSize(width: 120, height: 120)
    
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
            HorizontalCarousel_iOS17(
                focusedIndex: $focusedIndex,
                items: items,
                indexOffset: indexOffset,
                onOpen: onOpen,
                cardSizeFocused: cardSizeFocused,
                cardSizeUnfocused: cardSizeUnfocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .leading)
        } else {
            HorizontalCarousel_iOS16(
                focusedIndex: $focusedIndex,
                items: items,
                indexOffset: indexOffset,
                onOpen: onOpen,
                cardSizeFocused: cardSizeFocused,
                cardSizeUnfocused: cardSizeUnfocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .leading)
        }
    }
}


private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

@available(iOS 17, *)
fileprivate struct HorizontalCarousel_iOS17: View {
    @Binding var focusedIndex: Int
    let items: [(LibraryKind, LibraryItem)]
    let indexOffset: Int
    let onOpen: (LibraryKind, LibraryItem) -> Void
    
    // Layout
    private let reveal: CGFloat = 120
    private let extraGap: CGFloat = -120
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    
    // Paging & selection sync
    @State private var currentSelectedIndex: Int
    @State private var pendingScrollTask: Task<Void, Never>?
    @State private var isInitialScrollComplete: Bool = false
    @State private var isChangingBucket: Bool = false
    @State private var distances: [UUID: CGFloat] = [:]
    @State private var showFocus: Bool = false
    @State private var hasUserScrolled: Bool = false

    // Velocity tracking
    @State private var previousClosestDistance: CGFloat = 0
    @State private var velocityCheckTimer: Timer?
    @State private var isSnapping: Bool = false
    @State private var isScrolling: Bool = false
    
    // Velocity threshold (points per check interval)
    private let snapVelocityThreshold: CGFloat = 8 // Adjust this
    private let checkInterval: TimeInterval = 0.05 // Check every 50ms
    
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
    
    init(focusedIndex: Binding<Int>, items: [(LibraryKind, LibraryItem)], indexOffset: Int, onOpen: @escaping (LibraryKind, LibraryItem) -> Void, cardSizeFocused: CGSize, cardSizeUnfocused: CGSize) {
        self._focusedIndex = focusedIndex
        self.items = items
        self.indexOffset = indexOffset
        self.onOpen = onOpen
        self.cardSizeFocused = cardSizeFocused
        self.cardSizeUnfocused = cardSizeUnfocused
        
        let carouselIndex = max(0, focusedIndex.wrappedValue - indexOffset)
        self._currentSelectedIndex = State(initialValue: carouselIndex)
    }
    
    var body: some View {
        let overlapSpacing = -(cardSizeUnfocused.width - reveal) + extraGap
        let viewportWidth = UIScreen.main.bounds.width
        let horizontalMargin = viewportWidth / 2 - cardSizeFocused.width / 2
        let focusedScale: CGFloat = 0.75
        let unfocusedScale: CGFloat = (cardSizeUnfocused.width / cardSizeFocused.width) * 0.75
        
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: overlapSpacing) {
                        ForEach(items.indices, id: \.self) { index in
                            let (kind, item) = items[index]
                            let isFocused = (index == currentSelectedIndex)
                            let zIndex = zFor(item.id)
                            let itemID = compoundID(for: item, zIndex: zIndex)
                            
                            CarouselCard(
                                kind: kind,
                                item: item,
                                isFocused: isFocused,
                                showFocus: isFocused && showFocus,
                                cardSizeFocused: cardSizeFocused,
                                cardSizeUnfocused: cardSizeUnfocused
                            )
                            .onTapGesture { onOpen(kind, item) }
                            .id(itemID)
                            .modifier(ScaleOnScroll(focusedScale: focusedScale, unfocusedScale: unfocusedScale))
                            .background(
                                GeometryReader { cardGeo in
                                    let cardMidX = cardGeo.frame(in: .global).midX
                                    let viewportMid = outer.frame(in: .global).midX
                                    Color.clear
                                        .preference(key: CardDistanceKey.self,
                                                    value: [item.id: cardMidX - viewportMid])
                                }
                            )
                            .zIndex(zIndex)
                            .compositingGroup()
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(width: viewportWidth)
                .contentMargins(.horizontal, horizontalMargin)
                .scrollIndicators(.hidden)
                .clipped()
                .transaction { $0.animation = nil }
                .opacity(isInitialScrollComplete ? 1 : 0)
                .onPreferenceChange(CardDistanceKey.self) { newDistances in
                    let oldDistances = distances
                    distances = newDistances
                    
                    // Only start monitoring if distances actually changed AND we're not snapping
                    if !isSnapping && !isScrolling {
                        // Check if any distance changed significantly (user is scrolling)
                        let hasSignificantChange = newDistances.contains { id, newDist in
                            if let oldDist = oldDistances[id] {
                                return abs(newDist - oldDist) > 1.0 // More than 1 point changed
                            }
                            return false
                        }
                        
                        if hasSignificantChange {
                            print("🎬 Starting velocity monitoring")
                            isScrolling = true
                            startVelocityMonitoring(using: proxy)
                        }
                    }
                }
                .onAppear {
                    let carouselIndex = max(0, focusedIndex - indexOffset)
                    currentSelectedIndex = carouselIndex
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_000_000)
                        if !items.isEmpty {
                            let safeIndex = min(carouselIndex, items.count - 1)
                            let item = items[safeIndex].1
                            let zIndex = zFor(item.id)
                            let targetID = compoundID(for: item, zIndex: zIndex)
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                        try? await Task.sleep(nanoseconds: 10_000_000)
                        isInitialScrollComplete = true
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        showFocus = true
                    }
                }
                .onChange(of: items.count) { oldCount, newCount in
                    if !items.isEmpty {
                        let item = items[0].1
                        let zIndex = zFor(item.id)
                        let targetID = compoundID(for: item, zIndex: zIndex)
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
                .onChange(of: focusedIndex) { oldValue, newValue in
                    let carouselIndex = max(0, newValue - indexOffset)
                    currentSelectedIndex = carouselIndex
                    showFocus = false
                    
                    pendingScrollTask?.cancel()
                    
                    pendingScrollTask = Task { @MainActor in
                        guard !Task.isCancelled else { return }
                        guard let (_, item) = items[safe: carouselIndex] else { return }
                        let zIndex = zFor(item.id)
                        let targetID = compoundID(for: item, zIndex: zIndex)
                        withAnimation(.easeOut(duration: 0.08)) {
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        showFocus = true
                    }
                }
            }
        }
        .onDisappear {
            velocityCheckTimer?.invalidate()
        }
    }
    
    private func startVelocityMonitoring(using proxy: ScrollViewProxy) {
        // Cancel any existing timer
        velocityCheckTimer?.invalidate()
        
        // Get initial closest distance
        if let closestDist = distances.min(by: { abs($0.value) < abs($1.value) })?.value {
            previousClosestDistance = abs(closestDist)
        }
        
        // Start periodic velocity checking
        velocityCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            checkVelocityAndSnap(using: proxy)
        }
    }
    
    private func checkVelocityAndSnap(using proxy: ScrollViewProxy) {
        guard !isSnapping else {
            velocityCheckTimer?.invalidate()
            isScrolling = false
            return
        }
        
        // Get current closest distance
        guard let closestDist = distances.min(by: { abs($0.value) < abs($1.value) })?.value else { return }
        let currentDistance = abs(closestDist)
        
        // Calculate movement since last check
        let movement = abs(currentDistance - previousClosestDistance)
        
        print("📊 Movement: \(String(format: "%.1f", movement)) pts | Threshold: \(snapVelocityThreshold)")
        
        // If movement is below threshold, snap
        if movement < snapVelocityThreshold {
            print("✅ Below threshold - SNAPPING")
            velocityCheckTimer?.invalidate()
            isScrolling = false
            snapToNearest(using: proxy)
        } else {
            print("❌ Above threshold - keep scrolling")
        }
        
        previousClosestDistance = currentDistance
    }
    // Snap to the card closest to center
    private func snapToNearest(using proxy: ScrollViewProxy) {
        guard !isSnapping else { return }
        
        // Find the card with minimum distance (closest to center)
        guard let closestID = distances.min(by: { abs($0.value) < abs($1.value) })?.key else { return }
        
        // Find the index of this card
        guard let closestIndex = items.firstIndex(where: { $0.1.id == closestID }) else { return }
        
        // Only snap if we're not already focused on this card
        guard closestIndex != currentSelectedIndex else {
            showFocus = true
            return
        }
        
        print("🎯 Snapping to index \(closestIndex)")
        
        isSnapping = true
        showFocus = false
        
        let item = items[closestIndex].1
        let zIndex = zFor(item.id)
        let targetID = compoundID(for: item, zIndex: zIndex)
        
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(targetID, anchor: .center)
        }
        
        currentSelectedIndex = closestIndex
        focusedIndex = closestIndex + indexOffset
        
        // Re-enable snapping and focus after animation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            isSnapping = false
            showFocus = true
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
    let showFocus: Bool
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    
    var body: some View {
        let strokeOpacity = (isFocused && showFocus) ? 0.85 : 0.20
        let strokeWidth: CGFloat = (isFocused && showFocus) ? 3 : 1
        
        let _ = print("🎴 Card render - item: \(item.displayName), isFocused: \(isFocused), showFocus: \(showFocus), strokeOpacity: \(strokeOpacity)")
        
        ZStack(alignment: .bottom) {
            artwork
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            if isFocused && showFocus {
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
        content.scrollTransition(.interactive, axis: .horizontal) { c, phase in
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




























































// MARK: - iOS 16 Fallback
fileprivate struct HorizontalCarousel_iOS16: View {
    @Binding var focusedIndex: Int
    let items: [(LibraryKind, LibraryItem)]
    let indexOffset: Int
    let onOpen: (LibraryKind, LibraryItem) -> Void
    let cardSizeFocused: CGSize
    let cardSizeUnfocused: CGSize
    
    @State private var currentCenterIndex: Int = 0
    @State private var isScrollingProgrammatically = false
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(items.indices, id: \.self) { index in
                            let (kind, item) = items[index]
                            let isFocused = (index == currentCenterIndex)
                            
                            Button {
                                onOpen(kind, item)
                            } label: {
                                ZStack(alignment: .bottom) {
                                    // Artwork
                                    if let img = item.iconImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(
                                                width: isFocused ? cardSizeFocused.width : cardSizeUnfocused.width,
                                                height: isFocused ? cardSizeFocused.height : cardSizeUnfocused.height
                                            )
                                            .clipped()
                                            .cornerRadius(18)
                                    } else {
                                        ZStack {
                                            Color.gray.opacity(0.25)
                                            Image(systemName: "gamecontroller.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .padding(36)
                                                .foregroundStyle(.white)
                                        }
                                        .frame(
                                            width: isFocused ? cardSizeFocused.width : cardSizeUnfocused.width,
                                            height: isFocused ? cardSizeFocused.height : cardSizeUnfocused.height
                                        )
                                        .cornerRadius(18)
                                    }
                                    
                                    // WiFi badge for web games
                                    if case .web = kind {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Image(systemName: "wifi")
                                                    .font(.system(size: isFocused ? 11 : 8, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(isFocused ? 4 : 3)
                                                    .background(Color.black.opacity(0.70), in: Circle())
                                                    .padding(isFocused ? 8 : 6)
                                            }
                                        }
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(
                                            Color(red: 252/255, green: 112/255, blue: 242/255).opacity(isFocused ? 0.85 : 0.20),
                                            lineWidth: isFocused ? 3 : 1
                                        )
                                )
                                .overlay(alignment: .bottom) {
                                    if isFocused {
                                        Text(item.displayName)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.black.opacity(0.75))
                                            .cornerRadius(8)
                                            .offset(y: -16)
                                    }
                                }
                            }
                            .frame(
                                width: isFocused ? cardSizeFocused.width : cardSizeUnfocused.width,
                                height: isFocused ? cardSizeFocused.height : cardSizeUnfocused.height
                            )
                            .opacity(isFocused ? 1.0 : 0.7)
                            .animation(.easeOut(duration: 0.2), value: isFocused)
                            .id(index + indexOffset)
                            .background(
                                GeometryReader { itemGeo in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: [index: itemGeo.frame(in: .named("scroll")).midX]
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, geo.size.width / 2 - cardSizeFocused.width / 2)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { positions in
                    guard !isScrollingProgrammatically else { return }
                    let center = geo.size.width / 2
                    let closest = positions.min(by: { abs($0.value - center) < abs($1.value - center) })
                    if let closestIndex = closest?.key, closestIndex != currentCenterIndex {
                        currentCenterIndex = closestIndex
                        focusedIndex = closestIndex + indexOffset
                    }
                }
                .onChange(of: focusedIndex) { newIndex in
                    let targetIndex = newIndex - indexOffset
                    if targetIndex >= 0 && targetIndex < items.count && targetIndex != currentCenterIndex {
                        currentCenterIndex = targetIndex
                        isScrollingProgrammatically = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isScrollingProgrammatically = false
                        }
                    }
                }
                .onAppear {
                    let initialIndex = max(0, focusedIndex - indexOffset)
                    currentCenterIndex = initialIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollProxy.scrollTo(focusedIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
