//
//  SOOLRA - Dual Carousel Home View
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import CoreData
import Foundation
import Network
import SwiftUI
import WebKit

// MARK: - Enhanced HomeView with Dual Carousels

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var metalManager: MetalManager
    @EnvironmentObject var dataController: CoreDataController
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @EnvironmentObject var saveStateManager: SaveStateManager
    @ObservedObject private var controllerService = BluetoothControllerService.shared

    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var engagementTracker = globalEngagementTracker
    @StateObject private var defaultRomsLoadingState = DefaultRomsLoadingState.shared

    @StateObject private var network = NetworkMonitor()
    @State private var isOfflineDialogVisible = false
    @State private var pendingWebGame: WebGame? = nil

    @State private var isEditMode: EditMode = .inactive
    @State private var isSettingsPresented: Bool = false
    @State private var currentView: CurrentView = .grid
    @State private var roms: [Rom] = []
    @State private var isLoading: Bool = false
    @StateObject private var controllerViewModel = ControllerViewModel.shared

    @State private var isLoadingGame: Bool = false
    @State private var items: [(LibraryKind, LibraryItem)] = []
    @State private var webGames: [WebGame] = WebGameCatalog.all()
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var isShopDialogVisible: Bool = false
    @State private var isShopWebviewVisible: Bool = false
    @StateObject private var overlaystate = overlayState
    @StateObject private var favoritesManager = FavoritesManager.shared

    // Toast notification for favorites
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastMessage: String = ""

    // MARK: - Dual Carousel State
    @State private var activeCarouselIndex: Int = 0 // 0 = main, 1 = secondary
    @State private var carouselVerticalOffset: CGFloat = 0
    @State private var isDraggingCarousel: Bool = false
    @State private var mainCarouselFocusIndex: Int = 4 // Independent focus for main carousel
    @State private var secondaryCarouselFocusIndex: Int = 4 // Independent focus for secondary carousel
    
    // Long press tracking for favorite toggle
    @State private var buttonPressStartTime: [String: Date] = [:]
    @State private var longPressTimers: [String: DispatchWorkItem] = [:]
    @State private var hasTriggeredLongPress: [String: Bool] = [:]
    private let longPressDuration: TimeInterval = 0.7 // 2 seconds
    
    private let dialogSpring = Animation.spring(
        response: 0.32,
        dampingFraction: 0.86,
        blendDuration: 0.15
    )
    
    private let carouselSpring = Animation.spring(
        response: 0.42,
        dampingFraction: 0.88,
        blendDuration: 0.18
    )
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)

    private static var brandBackgroundColor: Color { Color(red: 41.0/255.0, green: 3.0/255.0, blue: 135.0/255.0) }
    private let brandBackground: Color = HomeView.brandBackgroundColor

    @ViewBuilder
    private var mainContent: some View {
        switch currentView {
        case .grid, .gameDetail:
            AnyView(gridAndDetailView)
        case .game(let gameData):
            AnyView(
                GameView(
                    data: gameData,
                    currentView: $currentView,
                    pauseViewModel: gameData.pauseViewModel
                )
                .environmentObject(gameData.consoleManager)
            )
        case .web(let webGame):
            AnyView(webViewContainer(webGame))
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            brandBackground.ignoresSafeArea()

            mainContent
                .allowsHitTesting(!isShopDialogVisible && !isOfflineDialogVisible)

            if isShopDialogVisible { shopDialog }
            if isOfflineDialogVisible { offlineDialog }
            if isLoading { loadingOverlay }
            if showFavoriteToast { favoriteToast }
        }
        .onAppear {
            viewModel.isCarouselMode = true
            engagementTracker.startTracking()
            BluetoothControllerService.shared.delegate = controllerViewModel
            if defaultRomsLoadingState.isLoading {
                isLoading = true
            } else {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isShopDialogVisible = !BluetoothControllerService.shared.isControllerConnected
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if isShopDialogVisible {
                    isShopDialogVisible = false
                }
            }
            BluetoothControllerService.shared.buttonTracker = { action, pressed in
                guard pressed else { return }
                switch currentView {
                case .web:
                    engagementTracker.trackButtonPress(action: action)
                default:
                    break
                }
            }
        }
        .onOpenURL { url in
            guard ["nes", "gba", "zip"].contains(url.pathExtension.lowercased()) else { return }
            Task {
                print("📥 Importing ROM from external URL: \(url)")
                isLoading = true
                await dataController.romManager.addRom(url: url)
                isLoading = false
                let updatedRoms = dataController.romManager.fetchRoms()
                let newRom = updatedRoms.first(where: {
                    $0.url?.lastPathComponent == url.lastPathComponent
                }) ?? updatedRoms.first

                if let rom = newRom {
                    NotificationCenter.default.post(
                        name: .launchRomFromExternalSource,
                        object: rom
                    )
                    if let exitTask = PauseGameViewModel.exitAction?() {
                        await exitTask.value
                    }
                    navigateToRom(rom)
                } else {
                    print("XXX Failed to navigate to new rom")
                }
            }
        }
        .onChange(of: defaultRomsLoadingState.isLoading) { loading in
            if !loading {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
                isLoading = false
            }
        }
        .onChange(of: roms.count) { newCount in
            rebuildItems()
            viewModel.updateItemsCount(newCount + webGames.count)
        }
        .onChange(of: viewModel.selectedGameIndex) { index in
            if let index = index {
                let idx = index - 4
                let vis = activeCarouselIndex == 0 ? visibleItems() : featuredItems()
                if idx >= 0 && idx < vis.count {
                    let (kind, _) = vis[idx].element
                    switch kind {
                    case .rom(let rom):
                        navigateToRom(rom)
                    case .web(let game):
                        navigateToWeb(game)
                    }
                } else if index == 1 {
                    isSettingsPresented = true
                } else if index == 2 || index == 3 {
                    viewModel.isPresented.toggle()
                }
            }
            viewModel.selectedGameIndex = nil
        }
        .onChange(of: controllerViewModel.lastAction) { evt in
            guard let evt = evt else { return }
            if overlaystate.isProfileOverlayVisible.wrappedValue
                || overlaystate.isWalletOverlayVisible.wrappedValue
                || overlaystate.isMarketOverlayVisible.wrappedValue
            {
                return
            }
            handleControllerEvent(evt)
        }
        .onChange(of: currentView) { newView in
            if case .grid = newView {
                BluetoothControllerService.shared.delegate = controllerViewModel
            }
        }
        .onChange(of: isSettingsPresented) { newValue in
            if !newValue {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
                viewModel.onAppear()
            }
        }
        .onChange(of: viewModel.isPresented) { newValue in
            if !newValue {
                viewModel.onAppear()
            }
        }
        .onChange(of: walletManager.privyUser?.id) { newID in
            engagementTracker.setPrivyId(newID)
        }
        .onChange(of: viewModel.focusedButtonIndex) { newIndex in
            // Continuously sync view model changes back to active carousel
            if case .grid = currentView {
                // Clamp to valid game range (4+) to prevent nav button focus
                let clampedIndex = max(4, newIndex)
                
                if activeCarouselIndex == 0 {
                    mainCarouselFocusIndex = clampedIndex
                } else {
                    secondaryCarouselFocusIndex = clampedIndex
                }
                
                // If we had to clamp, fix the view model too
                if clampedIndex != newIndex {
                    DispatchQueue.main.async {
                        viewModel.focusedButtonIndex = clampedIndex
                    }
                }
            }
        }
        .environmentObject(controllerViewModel)
        .profileOverlay(isPresented: overlaystate.isProfileOverlayVisible)
        .walletOverlay(isPresented: overlaystate.isWalletOverlayVisible)
        .marketOverlay(isPresented: overlaystate.isMarketOverlayVisible)
    }

    // MARK: - Controller Event Handling with Carousel Navigation
    private func handleControllerEvent(_ evt: ControllerAction) {
        if isShopDialogVisible {
            if evt.pressed {
                switch evt.action {
                case .x:
                    isShopDialogVisible = false
                case .a:
                    isShopDialogVisible = false
                    isShopWebviewVisible = true
                default: break
                }
            }
            return
        }

        // Track button presses for engagement
        if evt.pressed {
            switch currentView {
            case .game, .web:
                engagementTracker.trackButtonPress(action: evt.action)
            default:
                break
            }
        }

        switch currentView {
        case .grid:
            // Handle carousel switching with D-pad up/down
            if evt.pressed {
                switch evt.action {
                case .up, .down:
                    // Both up and down switch to the inactive carousel
                    switchToCarousel(activeCarouselIndex == 0 ? 1 : 0)
                    return // Don't pass to view model
                default:
                    break
                }
            }
            
            // Handle long press for X, Y, B, A buttons to toggle favorites
            let actionKey = "\(evt.action)"
            
            if evt.pressed {
                // Check if this is a face button (X, Y, B, A)
                switch evt.action {
                case .x, .y, .b, .a:
                    // Button pressed - start a timer to trigger favorite toggle after 2 seconds
                    hasTriggeredLongPress[actionKey] = false
                    
                    let workItem = DispatchWorkItem {
                        // Timer fired - this is a long press
                        self.hasTriggeredLongPress[actionKey] = true
                        self.toggleFavoriteAtCurrentIndex()
                    }
                    
                    longPressTimers[actionKey] = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: workItem)
                    
                    return // DON'T pass press event - wait to see if it's long or short
                default:
                    break
                }
            } else {
                // Button released
                switch evt.action {
                case .x, .y, .b, .a:
                    // Check if we even have a timer for this button
                    // If not, this release happened without a press in grid view (e.g., from pause dialog)
                    let hasTimer = longPressTimers[actionKey] != nil
                    let wasTriggered = hasTriggeredLongPress[actionKey] == true
                    
                    // Cancel the timer if it exists
                    if let timer = longPressTimers[actionKey] {
                        timer.cancel()
                        longPressTimers.removeValue(forKey: actionKey)
                    }
                    
                    // If long press was triggered, don't do anything (already toggled favorite)
                    if wasTriggered {
                        hasTriggeredLongPress.removeValue(forKey: actionKey)
                        return // Don't pass anything to view model
                    }
                    
                    // If we didn't have a timer, this is a stray release (from another view like pause dialog)
                    if !hasTimer {
                        return // Ignore stray releases
                    }
                    
                    // Short press - simulate both press and release events
                    hasTriggeredLongPress.removeValue(forKey: actionKey)
                    
                    // Sync focus before simulating press
                    if activeCarouselIndex == 0 {
                        viewModel.focusedButtonIndex = mainCarouselFocusIndex
                    } else {
                        viewModel.focusedButtonIndex = secondaryCarouselFocusIndex
                    }
                    
                    // Send press event
                    viewModel.controllerDidPress(action: evt.action, pressed: true)
                    // Send release event
                    viewModel.controllerDidPress(action: evt.action, pressed: false)
                    return // Don't fall through to normal processing
                default:
                    break
                }
            }
            
            // Sync view model's focus index from active carousel BEFORE processing
            if activeCarouselIndex == 0 {
                viewModel.focusedButtonIndex = mainCarouselFocusIndex
            } else {
                viewModel.focusedButtonIndex = secondaryCarouselFocusIndex
            }
            
            // Now pass all controller input to view model
            viewModel.controllerDidPress(
                action: evt.action,
                pressed: evt.pressed
            )
            
        case .web:
            BluetoothControllerService.shared.delegate?.controllerDidPress(
                action: evt.action,
                pressed: evt.pressed
            )
        default:
            break
        }
    }
    
    private func switchToCarousel(_ index: Int) {
        guard index != activeCarouselIndex else { return }
        
        withAnimation(carouselSpring) {
            activeCarouselIndex = index
        }
        
        // Ensure focus is in valid game range when switching
        DispatchQueue.main.async {
            if viewModel.focusedButtonIndex < 4 {
                viewModel.focusedButtonIndex = 4
            }
        }
    }
    

    // MARK: - Grid and Detail View with Dual Carousels
    @ViewBuilder
    private var gridAndDetailView: some View {
        GeometryReader { geometry in
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let safeAreaTop = geometry.safeAreaInsets.top
            let totalHeight = geometry.size.height + safeAreaTop + safeAreaBottom

            ZStack(alignment: .top) {
                Image("horizontal-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)
                    .clipped()
                    .ignoresSafeArea(edges: .all)
                    .offset(y: -56)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Carousel switching container - ONLY affects top half
                    ZStack {
                        // Main Carousel (All Games)
                        if activeCarouselIndex == 0 {
                            HorizontalGameCarousel(
                                focusedIndex: $mainCarouselFocusIndex,
                                items: visibleItems().map { $0.element }
                            ) { kind, item in
                                switch kind {
                                case .rom(let rom):
                                    navigateToRom(rom)
                                case .web(let game):
                                    navigateToWeb(game)
                                }
                            }
                            .id("main")
                            .transition(.identity)
                        }
                        
                        // Secondary Carousel (Featured/Favorites/Recent/etc)
                        if activeCarouselIndex == 1 {
                            HorizontalGameCarousel(
                                focusedIndex: $secondaryCarouselFocusIndex,
                                items: featuredItems().map { $0.element }
                            ) { kind, item in
                                switch kind {
                                case .rom(let rom):
                                    navigateToRom(rom)
                                case .web(let game):
                                    navigateToWeb(game)
                                }
                            }
                            .id("secondary-\(favoritesManager.favoriteIds.count)")
                            .transition(.identity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                let verticalMovement = abs(value.translation.height)
                                let horizontalMovement = abs(value.translation.width)
                                
                                // Only respond if gesture is primarily vertical
                                guard verticalMovement > horizontalMovement * 1.5 else {
                                    return
                                }
                                
                                let translation = value.translation.height
                                let velocity = value.predictedEndTranslation.height
                                let threshold: CGFloat = 40 // More sensitive
                                
                                // Swipe up (negative translation) -> go to secondary
                                if (translation < -threshold || velocity < -300) && activeCarouselIndex == 0 {
                                    switchToCarousel(1)
                                }
                                // Swipe down (positive translation) -> go to main
                                else if (translation > threshold || velocity > 300) && activeCarouselIndex == 1 {
                                    switchToCarousel(0)
                                }
                            }
                    )
                    .animation(carouselSpring, value: activeCarouselIndex)
                    
                    // Carousel toggle - positioned at bottom, OUTSIDE carousel ZStack
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Button(action: {
                                if activeCarouselIndex != 0 {
                                    switchToCarousel(0)
                                }
                            }) {
                                Text("All Games")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(activeCarouselIndex == 0 ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        activeCarouselIndex == 0
                                            ? Color.white
                                            : Color.clear
                                    )
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                if activeCarouselIndex != 1 {
                                    switchToCarousel(1)
                                }
                            }) {
                                Text("Favorites")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(activeCarouselIndex == 1 ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        activeCarouselIndex == 1
                                            ? Color.white
                                            : Color.clear
                                    )
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(3)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .padding(.bottom, 16)
                    }
                    .allowsHitTesting(true)
                    .zIndex(100) // Ensure toggle is above everything

                    // Navigation overlay on top of carousels
                    HomeNavigationView(
                        isSettingsPresented: $isSettingsPresented,
                        onSettingsButtonTap: { isSettingsPresented = true },
                        focusedButtonIndex: $viewModel.focusedButtonIndex,
                        dataController: dataController,
                        viewModel: viewModel,
                        searchQuery: $viewModel.searchQuery,
                        isProfilePresented: overlaystate.isProfileOverlayVisible,
                        isWalletPresented: overlaystate.isWalletOverlayVisible,
                        isMarketplacePresented: overlaystate.isMarketOverlayVisible,
                        activeCarouselIndex: $activeCarouselIndex
                    )
                    .padding(.top, geometry.safeAreaInsets.top)
                    .padding(.horizontal, 8)
                    .fullScreenCover(isPresented: $viewModel.isPresented) {
                        addRomSheet
                    }
                    .sheet(isPresented: $isShopWebviewVisible) {
                        shopWebSheet
                    }
                    .allowsHitTesting(true)
                }

                // BOTTOM HALF - CONTROLLER (EXACTLY AS ORIGINAL)
                SoolraControllerView(
                    controllerViewModel: controllerViewModel,
                    currentView: $currentView,
                    onButton: { action, pressed in
                        viewModel.controllerDidPress(
                            action: action,
                            pressed: pressed
                        )
                    }
                )
                .frame(
                    width: geometry.size.width,
                    height: totalHeight * 0.45
                )
                .edgesIgnoringSafeArea(.bottom)
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func webViewContainer(_ webGame: WebGame) -> some View {
        GeometryReader { geometry in
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let safeAreaTop = geometry.safeAreaInsets.top
            let totalHeight = geometry.size.height + safeAreaTop + safeAreaBottom

            ZStack(alignment: .bottom) {
                WebGameContainerView(game: webGame) {
                    engagementTracker.setCurrentRom("none", romScoreModifier: 0.0)
                    currentView = .grid
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .edgesIgnoringSafeArea(.all)

                SoolraControllerView(
                    controllerViewModel: controllerViewModel,
                    currentView: $currentView,
                    onButton: { action, pressed in
                        BluetoothControllerService.shared.delegate?
                            .controllerDidPress(
                                action: action,
                                pressed: pressed
                            )
                    }
                )
                .frame(width: geometry.size.width, height: totalHeight * 0.46)
                .edgesIgnoringSafeArea(.bottom)
                .offset(y: safeAreaBottom * 0.20 + 8)
            }
        }
    }

    // MARK: - Sheets and Overlays

    @ViewBuilder
    private var addRomSheet: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.6)
            VStack(spacing: 0) {
                if BluetoothControllerService.shared.isControllerConnected {
                    HalfScreenDocumentPicker { url in
                        Task {
                            isLoading = true
                            await dataController.romManager.addRom(url: url)
                            withAnimation {
                                roms = dataController.romManager.fetchRoms()
                                isLoading = false
                            }
                            viewModel.isPresented = false
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    Spacer()
                } else {
                    DocumentPicker { url in
                        Task {
                            isLoading = true
                            await dataController.romManager.addRom(url: url)
                            withAnimation {
                                roms = dataController.romManager.fetchRoms()
                                isLoading = false
                            }
                            viewModel.isPresented = false
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private var shopWebSheet: some View {
        NavigationView {
            ShopWebView(url: URL(string: "https://shop.soolra.com/")!)
                .navigationTitle("Shop")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button(action: { isShopWebviewVisible = false }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                )
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }

    @ViewBuilder
    private var shopDialog: some View {
        ZStack {
            Color.black.opacity(0.60)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(dialogSpring) { isShopDialogVisible = false }
                }
                .transition(.opacity)

            GeometryReader { g in
                let w = g.size.width
                let h = g.size.height
                let safeTop = g.safeAreaInsets.top
                let safeBottom = g.safeAreaInsets.bottom
                let aspect: CGFloat = 1688.0 / 780.0
                let topPad: CGFloat = -25
                let maxH = h - safeTop - safeBottom
                let isiPad = UIDevice.current.userInterfaceIdiom == .pad
                let capW: CGFloat = isiPad ? min(w, 600) : w
                let imgW = min(capW, maxH / aspect)
                let imgH = imgW * aspect
                let xCenter = w / 2
                let yTop = safeTop + topPad

                Image("shopDlg")
                    .resizable()
                    .scaledToFit()
                    .frame(width: imgW)
                    .position(x: xCenter, y: yTop + imgH / 2)
                    .contentShape(Rectangle())
                    .onTapGesture {}

                Button {
                    withAnimation(dialogSpring) { isShopDialogVisible = false }
                } label: {
                    Rectangle().fill(Color.white.opacity(0.0015))
                }
                .frame(width: imgW * 0.30, height: imgH * 0.15)
                .position(
                    x: (xCenter - imgW / 2) + imgW * 0.84,
                    y: yTop + imgH * 0.26
                )

                Button {
                    withAnimation(dialogSpring) { isShopDialogVisible = false }
                    isShopWebviewVisible = true
                } label: {
                    Rectangle().fill(Color.white.opacity(0.0015))
                }
                .frame(width: imgW * 0.64, height: imgH * 0.12)
                .position(
                    x: (xCenter - imgW / 2) + imgW * 0.50,
                    y: yTop + imgH * 0.86
                )
            }
        }
        .zIndex(1500)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(
                    with: .scale(scale: 0.96, anchor: .top)
                ),
                removal: .opacity.combined(
                    with: .scale(scale: 0.2, anchor: .top)
                )
            )
        )
        .animation(dialogSpring, value: isShopDialogVisible)
    }

    @ViewBuilder
    private var offlineDialog: some View {
        ZStack {
            Color.black.opacity(0.40)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(dialogSpring) {
                        isOfflineDialogVisible = false
                    }
                }
                .transition(.opacity)

            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.top, 4)
                Text("No Internet Connection")
                    .font(.custom("DINCondensed-Regular", size: 26))
                    .foregroundColor(.white)
                Text(
                    "This web game needs internet. Connect to Wi-Fi or cellular, then try again."
                )
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                HStack(spacing: 10) {
                    Button {
                        withAnimation(dialogSpring) {
                            isOfflineDialogVisible = false
                        }
                    } label: {
                        Text("Close")
                            .fontWeight(.semibold)
                            .padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    Color.white.opacity(0.22),
                                    lineWidth: 1
                                )
                            )
                    }
                    Button {
                        if network.isConnected, let game = pendingWebGame {
                            isOfflineDialogVisible = false
                            pendingWebGame = nil
                            navigateToWeb(game)
                        }
                    } label: {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.28))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    Color.white.opacity(0.30),
                                    lineWidth: 1
                                )
                            )
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(Color.black.opacity(0.8))
            .cornerRadius(18)
            .shadow(radius: 20, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 18).stroke(
                    Color.white.opacity(0.10),
                    lineWidth: 1
                )
            )
            .transition(
                .opacity.combined(with: .scale(scale: 0.96, anchor: .center))
            )
            .animation(dialogSpring, value: isOfflineDialogVisible)
        }
        .zIndex(1600)
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
            VStack(spacing: 15) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
        .zIndex(1000)
    }
    
    @ViewBuilder
    private var favoriteToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: favoriteToastMessage.contains("Added") ? "star.fill" : "star.slash.fill")
                    .foregroundColor(.white)
                Text(favoriteToastMessage)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.85))
            .cornerRadius(25)
            .shadow(radius: 10)
            .padding(.top, 80)
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(2000)
    }

    // MARK: - Favorites Helper
    
    private func toggleFavoriteAtCurrentIndex() {
        let items = activeCarouselIndex == 0 ? visibleItems() : featuredItems()
        let idx = viewModel.focusedButtonIndex - 4
        
        guard idx >= 0 && idx < items.count else { return }
        
        let (_, item) = items[idx].element
        toggleFavorite(item)
    }
    
    private func toggleFavorite(_ item: LibraryItem) {
        let wasFavorite = favoritesManager.isFavorite(item)
        favoritesManager.toggleFavorite(item)
        
        // Show toast
//        favoriteToastMessage = wasFavorite ? "Removed from Favorites" : "Added to Favorites"
//        withAnimation {
//            showFavoriteToast = true
//        }
//        
//        // Auto-hide toast after 2 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            withAnimation {
//                showFavoriteToast = false
//            }
//        }
    }

    // MARK: - Logic and Helper Functions

    func rebuildItems() {
        let priorityNames = [
            "Arcade Mania", "Astrohawk", "Attack on Voxelburg", "Battleship",
            "Blast Arena", "Blind Jump", "Blowhole", "Cats Curse", "Chase",
        ]

        let priorityIndex: [String: Int] = Dictionary(
            uniqueKeysWithValues: priorityNames.enumerated().map { ($1, $0) }
        )

        let sortedRoms = roms.sorted { a, b in
            let aKey = priorityIndex[a.displayName] ?? Int.max
            let bKey = priorityIndex[b.displayName] ?? Int.max

            if aKey != bKey {
                return aKey < bKey
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName)
                == .orderedAscending
        }

        let romItems: [(LibraryKind, LibraryItem)] = sortedRoms.map {
            (.rom($0), $0 as LibraryItem)
        }
        let webItems: [(LibraryKind, LibraryItem)] = webGames.map {
            (.web($0), $0 as LibraryItem)
        }
        items = webItems + romItems
    }

    private func visibleItems() -> [(offset: Int, element: (LibraryKind, LibraryItem))] {
        Array(items.enumerated())
            .filter { pair in
                let (_, item) = pair.element
                return viewModel.searchQuery.isEmpty
                    || item.searchKey.localizedCaseInsensitiveContains(
                        viewModel.searchQuery
                    )
            }
    }
    
    // MARK: - Featured Items for Secondary Carousel
    // Shows only favorited games
    private func featuredItems() -> [(offset: Int, element: (LibraryKind, LibraryItem))] {
        Array(items.enumerated())
            .filter { pair in
                let (_, item) = pair.element
                let matchesSearch = viewModel.searchQuery.isEmpty
                    || item.searchKey.localizedCaseInsensitiveContains(
                        viewModel.searchQuery
                    )
                let isFavorited = favoritesManager.isFavorite(item)
                return matchesSearch && isFavorited
            }
    }

    private func navigateToWeb(_ game: WebGame) {
        if !network.isConnected {
            pendingWebGame = game
            withAnimation(dialogSpring) { isOfflineDialogVisible = true }
            return
        }
        Task { @MainActor in
            self.currentView = .web(game)
            if #unavailable(iOS 17) {
                viewModel.focusedButtonIndex = 4
            }
            engagementTracker.setCurrentRom(
                game.name,
                romScoreModifier: game.passiveScoreModifier
            )
        }
    }

    private func navigateToRom(_ rom: Rom) {
        Task {
            do {
                let consoleManager = try ConsoleCoreManager(
                    metalManager: metalManager,
                    gameName: rom.name ?? "none"
                )

                let gameData = try await loadRom(
                    rom: rom,
                    consoleManager: consoleManager
                )
                consoleManager.cheatCodesManager = CheatCodesManager(
                    consoleManager: consoleManager
                )
                await MainActor.run {
                    self.currentView = .game(gameData)
                    if #unavailable(iOS 17) {
                        viewModel.focusedButtonIndex = 4
                    }
                }
                engagementTracker.setCurrentRom(
                    rom.name ?? "none",
                    romScoreModifier: rom.passiveScoreModifier ?? 1.0
                )
            } catch {
                print("Failed to load console: \(error)")
            }
        }
    }

    private func loadRom(rom: Rom, consoleManager: ConsoleCoreManager)
        async throws -> GameViewData
    {
        guard let url = rom.url else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        let consoleType: ConsoleCoreManager.ConsoleType
        switch url.pathExtension.lowercased() {
        case "nes":
            consoleType = .nes
        case "gba":
            consoleType = .gba
        default:
            throw ConsoleCoreManagerError.invalidCoreType
        }

        try await consoleManager.loadConsole(type: consoleType, romPath: url)

        let pauseViewModel = PauseGameViewModel(
            consoleManager: consoleManager,
            currentRom: rom
        )

        pauseViewModel.setExitAction {
            return Task { @MainActor in
                await consoleManager.shutdown()
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
                currentView = .grid

                // Reset controller delegate immediately
                BluetoothControllerService.shared.delegate = controllerViewModel

                engagementTracker.setCurrentRom("none", romScoreModifier: 0)
            }
        }

        return GameViewData(
            name: rom.name!,
            romPath: url,
            consoleManager: consoleManager,
            pauseViewModel: pauseViewModel
        )
    }
}

// MARK: - Updated HomeNavigationView with Carousel Indicator

struct HomeNavigationView: View {
    @Binding var isSettingsPresented: Bool
    var onSettingsButtonTap: () -> Void
    @Binding var focusedButtonIndex: Int
    let dataController: CoreDataController
    let viewModel: HomeViewModel
    @Binding var searchQuery: String
    @Binding var isProfilePresented: Bool
    @Binding var isWalletPresented: Bool
    @Binding var isMarketplacePresented: Bool
    @Binding var activeCarouselIndex: Int // NEW: Track active carousel
    @StateObject private var manager = walletManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            logoButton
                .offset(x: 8, y: -50)

            actionButtons
                .offset(x: UIScreen.main.bounds.width * 0.32, y: -50)

            settingsButton
                .offset(x: UIScreen.main.bounds.width * 0.8, y: -50)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var logoButton: some View {
        BlinkingFocusedButton(
            selectedIndex: .constant(-1),
            index: 0,
            action: {},
            content: {
                Group {
                    switch manager.authState {
                    case .authenticated:
                        Button(action: {
                            withAnimation { isProfilePresented = true }
                        }) {
                            Image("home-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                                .padding(4)
                        }
                    default:
                        AuthButton()
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Group {
                let base = BlinkingFocusedButton(
                    selectedIndex: $focusedButtonIndex,
                    index: 1,
                    action: {
                        viewModel.isPresented.toggle()
                    },
                    content: {
                        Button(action: {
                            viewModel.isPresented.toggle()
                        }) {
                            Image(systemName: "plus")
                                .resizable().scaledToFit()
                                .frame(width: 25, height: 25)
                                .padding().foregroundStyle(.white)
                        }
                    }
                )
                if #available(iOS 26.0, *) {
                    base.glassEffect()
                } else {
                    base
                }
            }

            Group {
                let base = BlinkingFocusedButton(
                    selectedIndex: $focusedButtonIndex,
                    index: 1,
                    action: {
                        withAnimation { isMarketplacePresented = true }
                    },
                    content: {
                        Group {
                            switch manager.authState {
                            case .authenticated:
                                Button(action: {
                                    withAnimation {
                                        isMarketplacePresented = true
                                    }
                                }) {
                                    Image(systemName: "storefront.fill")
                                        .resizable().scaledToFit()
                                        .frame(width: 25, height: 25)
                                        .padding().foregroundStyle(.white)
                                }
                            default:
                                EmptyView()
                            }
                        }
                    }
                )
                if #available(iOS 26.0, *) {
                    base.glassEffect()
                } else {
                    base
                }
            }

            Group {
                let base = BlinkingFocusedButton(
                    selectedIndex: $focusedButtonIndex,
                    index: 1,
                    action: { withAnimation { isWalletPresented = true } },
                    content: {
                        Group {
                            switch manager.authState {
                            case .authenticated:
                                Button(action: {
                                    withAnimation { isWalletPresented = true }
                                }) {
                                    Image(systemName: "wallet.bifold")
                                        .resizable().scaledToFit()
                                        .frame(width: 25, height: 25)
                                        .padding().foregroundStyle(.white)
                                }
                            default:
                                EmptyView()
                            }
                        }
                    }
                )
                if #available(iOS 26.0, *) {
                    base.glassEffect()
                } else {
                    base
                }
            }
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        let base = BlinkingFocusedButton(
            selectedIndex: .constant(-1),
            index: 1,
            action: onSettingsButtonTap,
            content: {
                Image(systemName: "gear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .padding()
                    .foregroundStyle(.white)
            }
        )
        .sheet(
            isPresented: $isSettingsPresented,
            onDismiss: { viewModel.setAsDelegate() }
        ) {
            SettingsView().environmentObject(dataController)
        }
        if #available(iOS 26.0, *) {
            base.glassEffect()
        } else {
            base
        }
    }
}

// MARK: - Supporting Views (unchanged from original)

struct BlinkingFocusedButton<Content: View>: View {
    @Binding var selectedIndex: Int
    let index: Int
    let action: () -> Void
    let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            selectedIndex == index ? Color.white : Color.clear,
                            lineWidth: 2
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CurrentItemView: View {
    var currentRom: Rom?
    @Binding var currentView: CurrentView
    @Binding var focusedButtonIndex: Int
    var addRomAction: (() -> Void)? = nil
    var overrideImage: UIImage? = nil
    var overrideTitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: {
                if let currentRom {
                    self.currentView = .gameDetail(currentRom)
                } else {
                    addRomAction?()
                }
            }) {
                Group {
                    if let img = overrideImage {
                        CustomImageView(
                            image: Image(uiImage: img),
                            width: 118,
                            height: 105
                        )
                        .frame(width: 134, height: 120)
                    } else if let data = currentRom?.imageData,
                        let uiImage = UIImage(data: data)
                    {
                        CustomImageView(
                            image: Image(uiImage: uiImage),
                            width: 118,
                            height: 105
                        )
                        .frame(width: 134, height: 120)
                    } else if let image = UIImage(named: "home-new-item") {
                        CustomImageView(
                            image: Image(uiImage: image),
                            width: 118,
                            height: 105
                        )
                        .frame(width: 134, height: 120)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            focusedButtonIndex == 2 ? Color.white : Color.clear,
                            lineWidth: 3
                        )
                        .padding(1)
                )
            }

            Text(overrideTitle ?? currentRom?.name ?? "Add Game")
                .multilineTextAlignment(.leading)
                .foregroundColor(.white)
                .font(.custom("DINCondensed-Regular", size: 28))
                .lineLimit(nil)
                .padding(.top, 10)
            Spacer()
        }
        .frame(alignment: .leading)
        .padding(.top, 10)
        .padding(.leading)
        .padding(.trailing, 16)
    }
}

struct TitleSortingView: View {
    let titleText: String
    let sortingText: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titleText)
                    .font(.custom("DINCondensed-Regular", size: 20))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(sortingText)
                    .font(.custom("DINCondensed-Regular", size: 20))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            Rectangle()
                .fill(Color.white)
                .frame(height: 1)
                .padding(.horizontal)
        }
    }
}

struct CustomImageView: View {
    let image: Image
    let width: Double
    let height: Double

    var body: some View {
        ZStack {
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .cornerRadius(10)
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Notification.Name {
    static let launchRomFromExternalSource = Notification.Name(
        "launchRomFromExternalSource"
    )
}

struct ShopWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected: Bool = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

