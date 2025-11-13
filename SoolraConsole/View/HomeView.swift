//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation
import WebKit
import Network

// Data to pass to GameView
struct GameViewData: Equatable {
    let name: String
    let romPath: URL
    let consoleManager: ConsoleCoreManager
    let pauseViewModel: PauseGameViewModel
    
    static func == (lhs: GameViewData, rhs: GameViewData) -> Bool {
        return lhs.name == rhs.name && lhs.romPath == rhs.romPath
    }
}

enum CurrentView: Equatable {
    case grid
    case gameDetail(Rom)
    case game(GameViewData)
    case web(WebGame)

    static func == (lhs: CurrentView, rhs: CurrentView) -> Bool {
        switch (lhs, rhs) {
        case (.grid, .grid):
            return true
        case (.gameDetail(let rom1), .gameDetail(let rom2)):
            return rom1 == rom2
        case (.game(let data1), .game(let data2)):
            return data1 == data2
        case (.web(let g1), .web(let g2)):
            return g1.id == g2.id
        default:
            return false
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var metalManager: MetalManager
    @EnvironmentObject var dataController: CoreDataController
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @EnvironmentObject var saveStateManager: SaveStateManager
    @ObservedObject private var controllerService = BluetoothControllerService.shared
    
    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var engagementTracker = EngagementTracker()
    @StateObject private var defaultRomsLoadingState = DefaultRomsLoadingState.shared
    
    @StateObject private var network = NetworkMonitor()
    @State private var isOfflineDialogVisible = false
    @State private var pendingWebGame: WebGame? = nil

    
    @State private var isEditMode: EditMode = .inactive
    @State private var isSettingsPresented: Bool = false
    @State private var currentView: CurrentView = .grid
    @State private var roms: [Rom] = []
    @State private var isLoading: Bool = false
    @StateObject private var controllerViewModel = ControllerViewModel()
    @State private var isLoadingGame: Bool = false
    @State private var items: [(LibraryKind, LibraryItem)] = []
    @State private var webGames: [WebGame] = WebGameCatalog.all()
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var isShopDialogVisible: Bool = false
    @State private var isShopWebviewVisible: Bool = false

    private let dialogSpring = Animation.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15)
    let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)
    
//    var backgroundImage: UIImage? {
//        guard let (kind, item) = focusedLibraryTuple() else { return nil }
//        switch kind {
//        case .rom(let rom):
//            return rom.imageData.flatMap(UIImage.init(data:))
//        case .web:
//            return item.iconImage
//        }
//    }


    
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 41 / 255, green: 3 / 255, blue: 135 / 255)
                .edgesIgnoringSafeArea(.all)
            Group {
                switch currentView {
                case .grid, .gameDetail:  // Handle both grid and gameDetail the same way
                    GeometryReader { geometry in
                        let safeAreaBottom = geometry.safeAreaInsets.bottom
                        let safeAreaTop = geometry.safeAreaInsets.top
                        let totalHeight = geometry.size.height + safeAreaTop + safeAreaBottom
                        
//                            
//                        }
                        ZStack(alignment: .top) {
                            Image("horizontal-bg")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width)
                                .clipped()
                                .ignoresSafeArea(edges: .all)
                                .offset(y: -56) // move just the image
                        }


                        VStack(spacing: 0) {
                            // Top area: carousel pinned to screen y=0, nav overlaid (does not push it down)
                            ZStack(alignment: .top) {
                                // Carousel at the very top
                                HorizontalGameCarousel(
                                    focusedIndex: $viewModel.focusedButtonIndex,
                                    items: visibleItems().map { $0.element }
                                ) { kind, item in
                                    switch kind {
                                    case .rom(let rom):
                                        navigateToRom(rom)
                                    case .web(let game):
                                        navigateToWeb(game)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .ignoresSafeArea(edges: .top)

                                // Nav overlaid on top; keep your existing sheets/covers attached here
                                HomeNavigationView(
                                    isSettingsPresented: $isSettingsPresented,
                                    onSettingsButtonTap: {
                                        isSettingsPresented = true
                                    },
                                    focusedButtonIndex: $viewModel.focusedButtonIndex,
                                    dataController: dataController, viewModel: viewModel,
                                    searchQuery: $viewModel.searchQuery
                                )
                                .padding(.top, geometry.safeAreaInsets.top)  // keep under status bar
                                .padding(.horizontal, 8)
                                .fullScreenCover(isPresented: $viewModel.isPresented) {
                                    ZStack(alignment: .top) {
                                        Color.black.opacity(0.6)
                                        
                                        VStack(spacing: 0) {
                                            if BluetoothControllerService.shared.isControllerConnected {
                                                // Half-height version
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
                                                // Full-height version
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
                                                .ignoresSafeArea() // Let it take over the screen
                                            }
                                        }
                                    }
                                }
                                .sheet(isPresented: $isShopWebviewVisible) {
                                    NavigationView {
                                        ShopWebView(url: URL(string: "https://shop.soolra.com/")!)
                                            .navigationTitle("Shop")
                                            .navigationBarTitleDisplayMode(.inline)
                                            .navigationBarItems(leading:
                                                Button(action: {
                                                    isShopWebviewVisible = false
                                                }) {
                                                    HStack {
                                                        Image(systemName: "chevron.left")
                                                        Text("Back")
                                                    }
                                                }
                                            )
                                    }
                                    .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                                }
                            }
                            // Bottom area: controller bar
                            SoolraControllerView(controllerViewModel: controllerViewModel, currentView: $currentView, onButton: { action, pressed in
                                viewModel.controllerDidPress(action: action, pressed: pressed)
                            })
                            .frame(width: geometry.size.width, height: totalHeight * 0.45)
                            .edgesIgnoringSafeArea(.bottom)
                        }
                        .preferredColorScheme(.dark)
                        // (intentionally no .edgesIgnoringSafeArea(.all) and no .padding(.top, 5))

                    }
                case .game(let gameData):
                    GameView(data: gameData, currentView: $currentView, pauseViewModel: gameData.pauseViewModel)
                        .environmentObject(gameData.consoleManager)
                case .web(let webGame):
                    GeometryReader { geometry in
                        let safeAreaBottom = geometry.safeAreaInsets.bottom
                        let safeAreaTop    = geometry.safeAreaInsets.top
                        let totalHeight    = geometry.size.height + safeAreaTop + safeAreaBottom
                        
                        ZStack(alignment: .bottom) {
                            // Web game fills the screen (no Spacer/VStack pushing the controller up)
                            WebGameContainerView(game: webGame) {
                                currentView = .grid
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .edgesIgnoringSafeArea(.all)
                            
                            // Controller pinned to bottom with the SAME sizing math as grid
                            let safeAreaBottom = geometry.safeAreaInsets.bottom
                            let safeAreaTop    = geometry.safeAreaInsets.top
                            let totalHeight    = geometry.size.height + safeAreaTop + safeAreaBottom
                            
                            SoolraControllerView(controllerViewModel: controllerViewModel, currentView: $currentView, onButton: { action, pressed in
                                BluetoothControllerService.shared.delegate?.controllerDidPress(action: action, pressed: pressed)
                            })
                            .frame(width: geometry.size.width, height: totalHeight * 0.46)
                            .edgesIgnoringSafeArea(.bottom)
                            .offset(y: safeAreaBottom * 0.20 + 8)
                            
                        }
                    }
                    
                    
                    
                }
            }
            .allowsHitTesting(!isShopDialogVisible && !isOfflineDialogVisible)
            if isShopDialogVisible {
              ZStack {
                  // Dimmer (back layer) — tappable to close
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

                  // Keep your aspect + topPad
                  let aspect: CGFloat = 1688.0 / 780.0   // H/W
                  let topPad: CGFloat = -25

                  // Fit image to BOTH axes so it never overflows on short screens; lightly cap on iPad
                  let maxH = h - safeTop - safeBottom
                  let isiPad = UIDevice.current.userInterfaceIdiom == .pad
                  let capW: CGFloat = isiPad ? min(w, 600) : w
                  let imgW = min(capW, maxH / aspect)   // CHANGED
                  let imgH = imgW * aspect

                  let xCenter = w / 2
                  let yTop = safeTop + topPad           // keeps your topPad behavior, but honors safe area

                    Image("shopDlg")
                      .resizable()
                      .scaledToFit()
                      .frame(width: imgW)
                      .position(x: xCenter, y: yTop + imgH/2)
                      .contentShape(Rectangle())          // define tappable area
                      .onTapGesture { /* absorb taps on image */ }



                  // 2) Close (X) hotspot
                  Button {
                    withAnimation(dialogSpring) {
                      isShopDialogVisible = false
                    }
                  } label: {
                    Rectangle().fill(Color.white.opacity(0.0015))  // reliably hit-testable
                  }
                  .frame(width: imgW * 0.30, height: imgH * 0.15)
                  .position(
                    x: (xCenter - imgW/2) + imgW * 0.84,
                    y: yTop + imgH * 0.26
                  )

                  // 3) Order Now hotspot
                  Button {
                    withAnimation(dialogSpring) {
                      isShopDialogVisible = false
                    }
                    isShopWebviewVisible = true
                  } label: {
                    Rectangle().fill(Color.white.opacity(0.0015))
                  }
                  .frame(width: imgW * 0.64, height: imgH * 0.12)
                  .position(
                    x: (xCenter - imgW/2) + imgW * 0.50,
                    y: yTop + imgH * 0.86
                  )
                }
              }
              .zIndex(1500)
              .transition(
                .asymmetric(
                  insertion: .opacity
                    .combined(with: .scale(scale: 0.96, anchor: .top)),
                  removal: .opacity
                    .combined(with: .scale(scale: 0.2, anchor: .top))
                )
              )
              .animation(dialogSpring, value: isShopDialogVisible)
            }
            if isOfflineDialogVisible {
                ZStack {
                    // Dim the background and allow tap to dismiss
                    Color.black.opacity(0.40)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(dialogSpring) { isOfflineDialogVisible = false } }
                        .transition(.opacity)

                    // The dialog card
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.top, 4)

                        Text("No Internet Connection")
                            .font(.custom("DINCondensed-Regular", size: 26))
                            .foregroundColor(.white)

                        Text("This web game needs internet. Connect to Wi-Fi or cellular, then try again.")
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))

                        HStack(spacing: 10) {
                            Button {
                                withAnimation(dialogSpring) { isOfflineDialogVisible = false }
                            } label: {
                                Text("Close")
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 10).frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.18))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.22), lineWidth: 1))
                            }

                            Button {
                                // Try again immediately; if online now, open the game.
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
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.30), lineWidth: 1))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: 360)
                    .background(Color.black.opacity(0.8))   // ← 60% transparent dark
                    .cornerRadius(18)                        // ← rounded corners
                    .shadow(radius: 20, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                    .animation(dialogSpring, value: isOfflineDialogVisible)
                }
                .zIndex(1600) // above shop dialog (which uses 1500)
            }



            // Loading overlay
            if isLoading {
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all) // Optional: If you want to dim the screen
                    
                    // Spinner overlay
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white)) // Adjust spinner color
                            .scaleEffect(1.5) // Adjust size
                        
                        Text("Loading...")
                            .foregroundColor(.white) // Match text color to spinner
                            .font(.headline) // Adjust font style
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8)) // Darker background for contrast
                    .cornerRadius(20) // Rounded corners
                    .shadow(radius: 10) // Optional shadow
                }
                .zIndex(1000) // Ensure it stays on top
            }
            
            
        }
        .onAppear {
            viewModel.isCarouselMode = true 
            engagementTracker.startTracking()
            if defaultRomsLoadingState.isLoading {
                isLoading = true
            } else {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                withAnimation(dialogSpring) {
                    isShopDialogVisible = !BluetoothControllerService.shared.isControllerConnected
//                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if isShopDialogVisible {
                    isShopDialogVisible = false
                }
            }
        }

        .onOpenURL { url in
            guard ["nes", "gba", "zip" ].contains(url.pathExtension.lowercased()) else { return }
            Task {
                print("📥 Importing ROM from external URL: \(url)")
                isLoading = true
                await dataController.romManager.addRom(url: url)
                isLoading = false
                let updatedRoms = dataController.romManager.fetchRoms()
                let newRom = updatedRoms.first(where: { $0.url?.lastPathComponent == url.lastPathComponent }) ?? updatedRoms.first
                // Navigate to game screen on main actor
                if let rom = newRom {
                    NotificationCenter.default.post(name: .launchRomFromExternalSource, object: rom)
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
                let vis = visibleItems()
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
            viewModel.selectedGameIndex = nil
        }


        .onChange(of: controllerViewModel.lastAction) { evt in
            guard let evt = evt else { return }

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

            switch currentView {
            case .grid:
                // forward BOTH press and release to your viewModel
                viewModel.controllerDidPress(action: evt.action, pressed: evt.pressed)

            case .web:
                // forward BOTH press and release to the BT delegate
                BluetoothControllerService.shared.delegate?.controllerDidPress(
                    action: evt.action,
                    pressed: evt.pressed
                )

            default:
                break
            }
        }



        .onChange(of: isSettingsPresented) { newValue in
            if !isSettingsPresented {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
                viewModel.onAppear()
            }
        }
        .onChange(of: viewModel.isPresented) { newValue in
            if !viewModel.isPresented {
                viewModel.onAppear()
            }
        }
        .environmentObject(controllerViewModel)
    }
    
    func rebuildItems() {
        let priorityNames = [
            "Arcade Mania",
            "Astrohawk",
            "Attack on Voxelburg",
            "Battleship",
            "Blast Arena",
            "Blind Jump",
            "Blowhole",
            "Cats Curse",
            "Chase"
        ]

        // Create a lookup so sorting is O(1)
        let priorityIndex: [String: Int] = Dictionary(
            uniqueKeysWithValues: priorityNames.enumerated().map { ($1, $0) }
        )

        // Sort ROMs by priority first, then alphabetically for the rest
        let sortedRoms = roms.sorted { a, b in
            let aKey = priorityIndex[a.displayName] ?? Int.max
            let bKey = priorityIndex[b.displayName] ?? Int.max

            if aKey != bKey {
                return aKey < bKey
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }

        let romItems: [(LibraryKind, LibraryItem)] = sortedRoms.map { (.rom($0), $0 as LibraryItem) }
        let webItems: [(LibraryKind, LibraryItem)] = webGames.map { (.web($0), $0 as LibraryItem) }

        // Your current rule: web games first, then ROMs
        items = webItems + romItems
    }

    
//    func rebuildItems() {
//        let romItems: [(LibraryKind, LibraryItem)] = roms.map { (.rom($0), $0 as LibraryItem) }
//        let webItems: [(LibraryKind, LibraryItem)] = webGames.map { (.web($0), $0 as LibraryItem) }
//        // Decide ordering rules; here we interleave after the upload tile or simply append:
//        items =  webItems + romItems
//    }

    private func focusedLibraryTuple() -> (LibraryKind, LibraryItem)? {
        let idx = viewModel.focusedButtonIndex - 4
        let vis = visibleItems()
        guard idx >= 0, idx < vis.count else { return nil }
        return vis[idx].element
    }

    private func loadDefaultRoms() {
        Task {
            isLoading = true
            dataController.romManager.resetDeletedDefaultRoms()
            await dataController.romManager.initDefaultRoms()
            await MainActor.run {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
                isLoading = false
            }
        }
    }
    
    
    private func controllerActionButtonPressed() {
        let i = viewModel.focusedButtonIndex
        switch i {
        case 1:
            isSettingsPresented = true
        case 2:
            viewModel.isPresented = true
        case 3:
            viewModel.isPresented.toggle()
        default:
            let idx = i - 4
            let vis = visibleItems()
            guard idx >= 0, idx < vis.count else { return }
            let (kind, _) = vis[idx].element
            switch kind {
            case .rom(let rom):
                navigateToRom(rom)
            case .web(let game):
                navigateToWeb(game)
            }
        }
    }

    
    // MARK: - Subviews
    
    
    private var emptyView: some View {
        VStack {
            Spacer()
            Text("There are no games")
                .font(.custom("Orbitron-Black", size: 24))
            Button("Load default games") {
                loadDefaultRoms()
            }
            .font(.custom("Orbitron-SemiBold", size: 24))
            .buttonStyle(.borderedProminent)
            .foregroundColor(.white)
            .background(Color.purple)
            Spacer()
            Spacer()
            Spacer()
            
            Button("Upload games") {
                viewModel.isPresented.toggle()
            }
            .font(.custom("Orbitron-SemiBold", size: 24))
            .buttonStyle(.borderedProminent)
            .foregroundColor(.white)
            .background(Color.purple)
            Spacer()
        }
        .padding()
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
    
    private var romGridView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    
                    // Upload button
                    Button(action: {
                        viewModel.isPresented.toggle()
                    }) {
                        addRomIcon()
                    }
                    .id(3)
                    
                    
                    ForEach(visibleItems(), id: \.element.1.id) { pair in
                        let index = pair.offset
                        let kind = pair.element.0
                        let item = pair.element.1

                        VStack(spacing: 4) {
                            Button {
                                if case .rom(let rom) = kind { navigateToRom(rom) }
                                else if case .web(let webGame) = kind { navigateToWeb(webGame) }
                            } label: {
                                libraryIcon(for: kind, item: item, index: index + 4)
                            }
                            .id(index + 4)

                            if isEditMode == .active, case .rom(let rom) = kind {
                                Button {
                                    withAnimation {
                                        dataController.romManager.deleteRom(rom: rom)
                                        roms = dataController.romManager.fetchRoms()
                                        rebuildItems()
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            }
            .onChange(of: viewModel.focusedButtonIndex) { newIndex in
                if newIndex >= 3 {
                    scrollProxy.scrollTo(newIndex, anchor: .center)
                }
            }
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
            engagementTracker.setCurrentRom(game.name)
        }
    }


    private func navigateToRom(_ rom: Rom) {
        Task {
            do {
                // Create console manager and load ROM and init cheat manager
                let consoleManager = try ConsoleCoreManager(metalManager: metalManager, gameName: rom.name ?? "none")
                
                // Load everything before transitioning view
                let gameData = try await loadRom(rom: rom, consoleManager: consoleManager)
                consoleManager.cheatCodesManager = CheatCodesManager(consoleManager: consoleManager)
                await MainActor.run {
                    self.currentView = .game(gameData)
                    if #unavailable(iOS 17) {
                        viewModel.focusedButtonIndex = 4
                    }
                }
                engagementTracker.setCurrentRom(rom.name ?? "none")
            } catch {
                print("Failed to load console: \(error)")
            }
        }
    }
    
    private func romIcon(for rom: Rom, index: Int) -> some View {
        VStack {
            if let imageData = rom.imageData, let uiImage = UIImage(data: imageData) {
                VStack(spacing: 3) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 88, height: 70)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.focusedButtonIndex == index ? Color.white : Color.clear, lineWidth: 4)
                                .padding(1)
                        )
                    
                    Text(rom.name ?? "Unknown")
                        .font(.custom("Ebrima", size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .frame(width: 88)
                
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "gamecontroller.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 70)
                        .foregroundColor(.purple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    
                    Text(rom.name ?? "Unknown")
                        .font(.custom("Ebrima", size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .frame(width: 88)
                
            }
        }
        .cornerRadius(8)
        .shadow(radius: 4)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func libraryIcon(for kind: LibraryKind, item: LibraryItem, index: Int) -> some View {
        switch kind {
        case .rom(let rom):
            romIcon(for: rom, index: index)  // existing UI

        case .web:
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = item.iconImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 70)
                            .cornerRadius(8)
                            // keep focus ring
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.focusedButtonIndex == index ? .white : .clear, lineWidth: 4)
                                    .padding(1)
                            )
                    } else {
                        Image(systemName: "globe")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 70)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white, lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }

                    // ⬅︎ Internet-required badge for all web games
                    onlineBadge()
                }

                Text(item.displayName)
                    .font(.custom("Ebrima", size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 88)
            .cornerRadius(8)
            .shadow(radius: 4)
            .contentShape(Rectangle())

        }
    }
    
    private func visibleItems() -> [(offset: Int, element: (LibraryKind, LibraryItem))] {
        Array(items.enumerated())
            .filter { pair in
                let (_, item) = pair.element
                return viewModel.searchQuery.isEmpty ||
                       item.searchKey.localizedCaseInsensitiveContains(viewModel.searchQuery)
            }
    }

    @ViewBuilder
    private func onlineBadge() -> some View {
        Image(systemName: "wifi")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(2)
            .background(Color.black.opacity(0.70), in: Circle())
            .padding([.trailing, .bottom], 2)
    }

    
    private func addRomIcon() -> some View {
        VStack(spacing: 3) {
            Image("home-new-item-big")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 70)
                .cornerRadius(8)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.focusedButtonIndex == 3 ? Color.white : Color.clear, lineWidth: 4)
                        .padding(1)
                )
            
            Text("Upload games")
                .font(.custom("Ebrima", size: 13))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(width: 88)
    }
    
    
    private func loadRom(rom: Rom, consoleManager: ConsoleCoreManager) async throws -> GameViewData {
        guard let url = rom.url else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }
        
        // Determine console type based on file extension
        let consoleType: ConsoleCoreManager.ConsoleType
        switch url.pathExtension.lowercased() {
        case "nes":
            consoleType = .nes
        case "gba":
            consoleType = .gba
        default:
            throw ConsoleCoreManagerError.invalidCoreType
        }
        
        // Load console asynchronously
        try await consoleManager.loadConsole(type: consoleType, romPath: url)
        
        // Create pause view model with console manager
        let pauseViewModel = PauseGameViewModel(consoleManager: consoleManager, currentRom: rom)
        
        // Set up exit action after view is fully initialized
        pauseViewModel.setExitAction {
            // Return the task so we can await it
            return Task { @MainActor in
                do {
                    // First stop accepting new frames
                    await consoleManager.shutdown()
                    
                    // Wait a bit for any in-flight frames to complete
                    // try await Task.sleep(nanoseconds: 1_000_000_000) // 1second
                    
                    // Then navigate away
                    roms = dataController.romManager.fetchRoms()
                    rebuildItems()
                    viewModel.updateItemsCount(items.count)
                    currentView = .grid
                } catch {
                    print("Error during shutdown: \(error)")
                    // Still navigate away even if there was an error
                    currentView = .grid
                }
            }
        }
        
        return GameViewData(
            name: rom.name!,
            romPath: url,
            consoleManager: consoleManager,
            pauseViewModel: pauseViewModel
        )
    }
    
    struct BlinkingFocusedButton<Content: View>: View {
        @Binding var selectedIndex: Int
        let index: Int
        let action: () -> Void
        let content: () -> Content
        
        var body: some View {
            Button(action: {
                action()
            }) {
                content()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedIndex == index ? Color.white : Color.clear, lineWidth: 2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    struct HomeNavigationView: View {
        @Binding var isSettingsPresented: Bool
        var onSettingsButtonTap: () -> Void
        @Binding var focusedButtonIndex: Int
        let dataController: CoreDataController
        let viewModel: HomeViewModel
        @Binding var searchQuery: String // 👈 Add this
        
        var body: some View {
            ZStack(alignment: .topLeading) {
                // Logo button - top left, slightly higher
                BlinkingFocusedButton(selectedIndex: .constant(-1), index: 0, action: { }, content: {
                    Image("home-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .padding()
                })
                .offset(x: 8, y: -50)
                
                BlinkingFocusedButton(
                    selectedIndex: .constant(-1),
                    index: 2,
                    action: {
                        viewModel.isPresented = true
                    },
                    content: {
                        Image("add-rom-new")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .padding()
                    }
                )
                .offset(x: UIScreen.main.bounds.width * 0.68    , y: -50)

                
                // Settings button - lower, roughly halfway down the screen
                BlinkingFocusedButton(selectedIndex: .constant(-1), index: 1, action: {
                    onSettingsButtonTap()
                }, content: {
                    Image("home-settings-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .padding()
                })
                .sheet(isPresented: $isSettingsPresented, onDismiss: {
                    viewModel.setAsDelegate()
                }) {
                    SettingsView().environmentObject(dataController)
                }
                .offset(x: UIScreen.main.bounds.width * 0.8, y: -50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)

        }
    }
    
    struct CurrentItemView: View {
        var currentRom: Rom?
        @Binding var currentView: CurrentView
        @Binding var focusedButtonIndex: Int
        var addRomAction: (() -> Void)? = nil

        // NEW:
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
                            // show web‑game icon (or any custom image)
                            CustomImageView(image: Image(uiImage: img), width: 118, height: 105)
                                .frame(width: 134, height: 120)
                        } else if let data = currentRom?.imageData, let uiImage = UIImage(data: data) {
                            CustomImageView(image: Image(uiImage: uiImage), width: 118, height: 105)
                                .frame(width: 134, height: 120)
                        } else if let image = UIImage(named: "home-new-item") {
                            CustomImageView(image: Image(uiImage: image), width: 118, height: 105)
                                .frame(width: 134, height: 120)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focusedButtonIndex == 2 ? Color.white : Color.clear, lineWidth: 3)
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
    static let launchRomFromExternalSource = Notification.Name("launchRomFromExternalSource")
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
