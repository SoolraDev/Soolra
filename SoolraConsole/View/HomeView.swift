//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation
import WebKit

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
    
    @State private var isEditMode: EditMode = .inactive
    @State private var isSettingsPresented: Bool = false
    @State private var currentView: CurrentView = .grid
    @State private var roms: [Rom] = []
    @State private var isLoading: Bool = false
    @StateObject private var controllerViewModel = ControllerViewModel()
    @State private var isLoadingGame: Bool = false
    @State private var items: [(LibraryKind, LibraryItem)] = []
    @State private var webGames: [WebGame] = WebGameCatalog.all()
    
    @State private var isShopDialogVisible: Bool = false
    @State private var isShopWebviewVisible: Bool = false
    private let dialogSpring = Animation.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15)
    let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)
    
    var backgroundImage: UIImage? {
        guard let (kind, item) = focusedLibraryTuple() else { return nil }
        switch kind {
        case .rom(let rom):
            return rom.imageData.flatMap(UIImage.init(data:))
        case .web:
            return item.iconImage
        }
    }


    
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
                        
                        ZStack {
                            if let bgImage = backgroundImage {
                                Image(uiImage: bgImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: totalHeight)
                                    .clipped()
                                    .edgesIgnoringSafeArea(.all)
                                    .overlay(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.black.opacity(0.7), location: 0),
                                                .init(color: Color.black.opacity(0.7), location: 0.3),
                                                .init(color: Color.black.opacity(0.8), location: 0.7),
                                                .init(color: Color.black.opacity(0.95), location: 1.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            } else {
                                Image("home-background")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: totalHeight)
                                    .clipped()
                                    .edgesIgnoringSafeArea(.all)
                            }
                            
                            
                            
                            
                        }
                        VStack {
                            HomeNavigationView(
                                isSettingsPresented: $isSettingsPresented,
                                onSettingsButtonTap: {
                                    isSettingsPresented = true
                                },
                                focusedButtonIndex: $viewModel.focusedButtonIndex,
                                dataController: dataController, viewModel: viewModel,
                                searchQuery: $viewModel.searchQuery
                            )
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
                            
                            
                            
                            if let (kind, item) = focusedLibraryTuple() {
                                switch kind {
                                case .rom(let rom):
                                    CurrentItemView(
                                        currentRom: rom,
                                        currentView: $currentView,
                                        focusedButtonIndex: $viewModel.focusedButtonIndex
                                    )
                                case .web:
                                    CurrentItemView(
                                        currentRom: nil,
                                        currentView: $currentView,
                                        focusedButtonIndex: $viewModel.focusedButtonIndex,
                                        addRomAction: nil,
                                        overrideImage: item.iconImage,        // <— web-game icon
                                        overrideTitle: item.displayName       // <— web-game name
                                    )
                                }
                            } else {
                                CurrentItemView(
                                    currentRom: nil,
                                    currentView: $currentView,
                                    focusedButtonIndex: $viewModel.focusedButtonIndex,
                                    addRomAction: { viewModel.isPresented = true }
                                )
                            }
                            
                            
                            TitleSortingView(titleText: "All Games", sortingText: "A-Z")
                                .padding(.top, 10)
                            
                            if items.isEmpty && !isLoading {
                                emptyView
                            } else {
                                romGridView
                            }
                            
                            SoolraControllerView(controllerViewModel: controllerViewModel, currentView: $currentView, onButton: { action, pressed in
                                viewModel.controllerDidPress(action: action, pressed: pressed)
                            })
                            
                            .frame(width: geometry.size.width, height: totalHeight * 0.48)
                            .edgesIgnoringSafeArea(.bottom)
                        }
                        .edgesIgnoringSafeArea(.all)
                        .preferredColorScheme(.dark)
                        .padding(.top, 5)
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
                .allowsHitTesting(!isShopDialogVisible)
            if isShopDialogVisible {
              ZStack {
                Color.black.opacity(0.60).ignoresSafeArea()
                      .allowsHitTesting(false)
                      .onTapGesture { /* swallow taps outside hotspots */ } // do nothing
                      .transition(.opacity)
                GeometryReader { g in
                  let w = g.size.width
                  // Replace with your real asset aspect (height/width). Example uses 2392x1340.
                    let aspect: CGFloat = 1688.0 / 780.0
                  let topPad: CGFloat = -25
                  let imgW = w
                  let imgH = imgW * aspect

                  // 1) The dialog image
                  Image("shopDlg")
                    .resizable()
                    .scaledToFit()
                    .frame(width: imgW)
                    .position(x: w/2, y: topPad + imgH/2)  // top aligned by +topPad
                    .allowsHitTesting(false)               // don't steal taps from hotspots

                  // 2) Close (X) hotspot
                  Button {
                      withAnimation(dialogSpring) {
                          isShopDialogVisible = false
                      }
                  } label: {
                      Rectangle().fill(Color.white.opacity(0.0015))  // reliably hit-testable
                  }
                  .frame(width: imgW * 0.30, height: imgH * 0.15)
                  .position(x: w * 0.84, y: topPad + imgH * 0.26)

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
                  .position(x: w * 0.50, y: topPad + imgH * 0.86)
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
            engagementTracker.startTracking()
            if defaultRomsLoadingState.isLoading {
                isLoading = true
            } else {
                roms = dataController.romManager.fetchRoms()
                rebuildItems()
                viewModel.updateItemsCount(items.count)
            }

            isShopDialogVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
            guard let evt = evt, evt.pressed else { return }
            
            if isShopDialogVisible {
                switch evt.action {
                case .x: // close dialog
                    isShopDialogVisible = false
                case .a: // open webview in window
                    isShopDialogVisible = false
                    isShopWebviewVisible = true
                default:
                    break
                }
                return
            }
            
            switch currentView {
            case .grid:
                viewModel.controllerDidPress(action: evt.action, pressed: evt.pressed)
            case .web:
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
        let romItems: [(LibraryKind, LibraryItem)] = roms.map { (.rom($0), $0 as LibraryItem) }
        let webItems: [(LibraryKind, LibraryItem)] = webGames.map { (.web($0), $0 as LibraryItem) }
        // Decide ordering rules; here we interleave after the upload tile or simply append:
        items =  webItems + romItems
    }

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


    
    
    // MARK: - Helper Functions
    
    private func navigateToWeb(_ game: WebGame) {
        Task { @MainActor in
            self.currentView = .web(game)
            viewModel.focusedButtonIndex = 4
            engagementTracker.setCurrentRom(game.name) // optional reuse
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
                // Once everything is ready, update the view
                await MainActor.run {
                    //withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentView = .game(gameData)
                    viewModel.focusedButtonIndex = 4
                    //}
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
            
            VStack {
                
                HStack {
                    BlinkingFocusedButton(selectedIndex: $focusedButtonIndex, index: 0, action: { }, content: {
                        Image("home-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .padding()
                    })
                    Spacer(minLength: 10)
                    //                    TextField("Search games...", text: $searchQuery)                        .padding(8)
                    //                        .background(Color.white.opacity(0.15))
                    //                        .cornerRadius(14)
                    //                        .foregroundColor(.white)
                    //                        .frame(height: 27)
                    //                        .frame(maxWidth: .infinity)
                    //                        .overlay(
                    //                            HStack {
                    //                                Spacer()
                    //                                Image(systemName: "magnifyingglass")
                    //                                    .foregroundColor(.white)
                    //                                    .padding(.trailing, 10)
                    //                            }
                    //                        )
                    
                    
                    BlinkingFocusedButton(selectedIndex: $focusedButtonIndex, index: 1, action: {
                        onSettingsButtonTap()
                        
                    }, content: {
                        Image("home-settings-icon")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .scaledToFit()
                            .padding()
                    })
                    .sheet(isPresented: $isSettingsPresented, onDismiss: {
                        // When settings is dismissed, ensure we get the delegate back
                        viewModel.setAsDelegate()
                    }) {
                        SettingsView().environmentObject(dataController)
                    }




                }
                .frame(height: 27)
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .background(Color.clear)
                
            }
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
