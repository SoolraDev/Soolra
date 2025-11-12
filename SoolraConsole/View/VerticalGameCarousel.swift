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
//        if #available(iOS 17, *) {
//            HorizontalCarousel_iOS17(
//                focusedIndex: $focusedIndex,
//                items: items,
//                indexOffset: indexOffset,
//                onOpen: onOpen,
//                cardSizeFocused: cardSizeFocused,
//                cardSizeUnfocused: cardSizeUnfocused
//            )
//            .offset(y:20)
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//            .ignoresSafeArea(edges: .leading)
//
//        } else {
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
//        }
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
    @State private var selectedID: String?
    @State private var currentSelectedIndex: Int
    @State private var pendingScrollTask: Task<Void, Never>?
    @State private var isInitialScrollComplete: Bool = false
    @State private var isChangingBucket: Bool = false
    @State private var distances: [UUID: CGFloat] = [:]
    
    // Velocity tracking for manual snap
    @State private var previousClosestDistance: CGFloat = 0
    @State private var velocityCheckTimer: Timer?
    @State private var isSnapping: Bool = false
    @State private var isScrolling: Bool = false
    
    private let snapVelocityThreshold: CGFloat = 8
    private let checkInterval: TimeInterval = 0.05
    
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
        
        // Calculate correct carousel index
        let carouselIndex = max(0, focusedIndex.wrappedValue - indexOffset)
        self._currentSelectedIndex = State(initialValue: carouselIndex)
        
        // Set selectedID to the correct position
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
    
    // Break down layout constants
    private var overlapSpacing: CGFloat {
        -(cardSizeUnfocused.width - reveal) + extraGap
    }
    
    private var viewportWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var horizontalMargin: CGFloat {
        viewportWidth / 2 - cardSizeFocused.width / 2
    }
    
    private var focusedScale: CGFloat { 0.75 }
    private var unfocusedScale: CGFloat {
        (cardSizeUnfocused.width / cardSizeFocused.width) * 0.70
    }
    
    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                scrollContent(outer: outer)
                    .onPreferenceChange(CardDistanceKey.self) { newDistances in
                        let oldDistances = distances
                        distances = newDistances
                        
                        // Update currentSelectedIndex based on closest card
                        if let closestID = newDistances.min(by: { abs($0.value) < abs($1.value) })?.key,
                           let closestIndex = items.firstIndex(where: { $0.1.id == closestID }) {
                            if closestIndex != currentSelectedIndex {
                                currentSelectedIndex = closestIndex
                            }
                        }
                        
                        // Start velocity monitoring if user is scrolling
                        if !isSnapping && !isScrolling {
                            let hasSignificantChange = newDistances.contains { id, newDist in
                                if let oldDist = oldDistances[id] {
                                    return abs(newDist - oldDist) > 1.0
                                }
                                return false
                            }
                            
                            if hasSignificantChange {
                                isScrolling = true
                                startVelocityMonitoring(using: proxy)
                            }
                        }
                    }
                    .scrollPosition(id: $selectedID, anchor: .center)
            }
        }
        .onAppear(perform: handleAppear)
        .onChange(of: items.count) { oldCount, newCount in
            handleItemsCountChange(oldCount: oldCount, newCount: newCount)
        }
        .onChange(of: focusedIndex) { oldValue, newValue in
            handleFocusedIndexChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: distances) { oldValue, newValue in
            handleDistancesChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: selectedID) { oldValue, newValue in
            handleSelectedIDChange(oldValue: oldValue, newValue: newValue)
        }
        .onDisappear {
            velocityCheckTimer?.invalidate()
        }
    }
    
    @ViewBuilder
    private func scrollContent(outer: GeometryProxy) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: overlapSpacing) {
                ForEach(items.indices, id: \.self) { index in
                    cardView(at: index, outer: outer)
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
    }
    
    @ViewBuilder
    private func cardView(at index: Int, outer: GeometryProxy) -> some View {
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
        .background(distanceTracker(for: item, outer: outer))
        .zIndex(zIndex)
        .compositingGroup()
    }
    
    @ViewBuilder
    private func distanceTracker(for item: LibraryItem, outer: GeometryProxy) -> some View {
        GeometryReader { cardGeo in
            let cardMidX = cardGeo.frame(in: .global).midX
            let viewportMid = outer.frame(in: .global).midX
            Color.clear
                .preference(key: CardDistanceKey.self,
                            value: [item.id: cardMidX - viewportMid])
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
    
    // MARK: - Velocity Monitoring
    
    private func startVelocityMonitoring(using proxy: ScrollViewProxy) {
        velocityCheckTimer?.invalidate()
        
        if let closestDist = distances.min(by: { abs($0.value) < abs($1.value) })?.value {
            previousClosestDistance = abs(closestDist)
        }
        
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
        
        guard let closestDist = distances.min(by: { abs($0.value) < abs($1.value) })?.value else { return }
        let currentDistance = abs(closestDist)
        let movement = abs(currentDistance - previousClosestDistance)
        
        if movement < snapVelocityThreshold {
            velocityCheckTimer?.invalidate()
            isScrolling = false
            snapToNearest(using: proxy)
        }
        
        previousClosestDistance = currentDistance
    }
    
    private func snapToNearest(using proxy: ScrollViewProxy) {
        guard !isSnapping else { return }
        guard let closestID = distances.min(by: { abs($0.value) < abs($1.value) })?.key else { return }
        guard let closestIndex = items.firstIndex(where: { $0.1.id == closestID }) else { return }
        
        isSnapping = true
        
        let item = items[closestIndex].1
        let zIndex = zFor(item.id)
        let targetID = compoundID(for: item, zIndex: zIndex)
        
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(targetID, anchor: .center)
        }
        
        selectedID = targetID
        currentSelectedIndex = closestIndex
        focusedIndex = closestIndex + indexOffset
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            isSnapping = false
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleAppear() {
        let carouselIndex = max(0, focusedIndex - indexOffset)
        currentSelectedIndex = carouselIndex
        
        if selectedID == nil && !items.isEmpty {
            let safeIndex = min(carouselIndex, items.count - 1)
            let item = items[safeIndex].1
            let zIndex = zFor(item.id)
            selectedID = compoundID(for: item, zIndex: zIndex)
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000)
            if !items.isEmpty {
                let safeIndex = min(carouselIndex, items.count - 1)
                let item = items[safeIndex].1
                let zIndex = zFor(item.id)
                let targetID = compoundID(for: item, zIndex: zIndex)
                selectedID = targetID
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
            isInitialScrollComplete = true
        }
    }
    
    private func handleItemsCountChange(oldCount: Int, newCount: Int) {
        if selectedID == nil && !items.isEmpty {
            let item = items[0].1
            let zIndex = zFor(item.id)
            selectedID = compoundID(for: item, zIndex: zIndex)
        }
    }
    
    private func handleFocusedIndexChange(oldValue: Int, newValue: Int) {
        // Prevent focusedIndex from going below indexOffset
        guard newValue >= indexOffset else {
            // Reset to minimum valid value
            DispatchQueue.main.async {
                focusedIndex = indexOffset
            }
            return
        }
        
        let carouselIndex = newValue - indexOffset
        
        // Also check upper bound
        guard carouselIndex < items.count else {
            DispatchQueue.main.async {
                focusedIndex = items.count - 1 + indexOffset
            }
            return
        }
        
        currentSelectedIndex = carouselIndex
        
        pendingScrollTask?.cancel()
        
        pendingScrollTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            guard let (_, item) = items[safe: carouselIndex] else { return }
            let zIndex = zFor(item.id)
            let targetID = compoundID(for: item, zIndex: zIndex)
            withAnimation(.easeOut(duration: 0.06)) {
                selectedID = targetID
            }
        }
    }
    
    private func handleDistancesChange(oldValue: [UUID: CGFloat], newValue: [UUID: CGFloat]) {
        guard let index = items.indices.first(where: {
            items[$0].1.id.uuidString == selectedID?.split(separator: "-").first.map(String.init)
        }) else { return }
        
        let item = items[index].1
        let newZIndex = zFor(item.id)
        let newID = compoundID(for: item, zIndex: newZIndex)
        
        if newID != selectedID {
            isChangingBucket = true
            selectedID = newID
        }
    }
    
    private func handleSelectedIDChange(oldValue: String?, newValue: String?) {
        guard !isChangingBucket else {
            isChangingBucket = false
            return
        }
        
        guard let newID = newValue,
              let lastDashIndex = newID.lastIndex(of: "-") else { return }
        let uuidString = String(newID[..<lastDashIndex])
        
        if let uuid = UUID(uuidString: uuidString),
           let i = items.firstIndex(where: { $0.1.id == uuid }) {
            currentSelectedIndex = i
            focusedIndex = i + indexOffset
        }
    }
}
// MARK: - Card (shared)
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
        .frame(width: cardSizeFocused.height, height: cardSizeFocused.height)
        .overlay(alignment: .bottom) {
            if isFocused {
                Text(item.displayName)
//                    .font(.system(size: 24, weight: .semibold))
                    .font(.custom("Shapiro", size: 24))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)
                    .padding(.bottom, 10)
                    .offset(y: 80)
            }
        }
        .frame(width: cardSizeFocused.height, height: cardSizeFocused.height)
    }
    
    @ViewBuilder
    private var artwork: some View {
        if let ui = item.iconImage {
            Image(uiImage: ui).resizable()
                .scaledToFill()
                .frame(width: 280, height: 280)
                .clipped()
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
