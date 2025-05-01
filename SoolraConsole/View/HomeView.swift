//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation

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
    
    static func == (lhs: CurrentView, rhs: CurrentView) -> Bool {
        switch (lhs, rhs) {
        case (.grid, .grid):
            return true
        case (.gameDetail(let rom1), .gameDetail(let rom2)):
            return rom1 == rom2
        case (.game(let data1), .game(let data2)):
            return data1 == data2
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
    
    @StateObject private var viewModel = HomeViewModel.shared
    @State private var isEditMode: EditMode = .inactive
    @State private var isSettingsPresented: Bool = false
    @State private var currentView: CurrentView = .grid
    @State private var roms: [Rom] = []
    @State private var isLoading: Bool = false
    @StateObject private var controllerViewModel = ControllerViewModel()
    @State private var isLoadingGame: Bool = false

    let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 4)

    var backgroundImage: UIImage? {
        if viewModel.focusedButtonIndex >= 4,
           let rom = roms[safe: viewModel.focusedButtonIndex - 4],
           let imageData = rom.imageData,
           let image = UIImage(data: imageData) {
            return image
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 41 / 255, green: 3 / 255, blue: 135 / 255)
                .edgesIgnoringSafeArea(.all)
                        
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
                            dataController: dataController,
                            viewModel: viewModel
                        )
                        .sheet(isPresented: $viewModel.isPresented) {
                            DocumentPicker { url in
                  
                                // Use RomManager to handle adding the ROM
                                 Task {
                                     isLoading = true
                                     await dataController.romManager.addRom( url: url)
                                     withAnimation {
                                         roms = dataController.romManager.fetchRoms()
                                         isLoading = false
                                     }
                                 }

                            }
                            .font(.custom("Orbitron-Black", size: 24))
                        }
                        if viewModel.focusedButtonIndex >= 4 {
                            CurrentItemView(currentRom: roms[viewModel.focusedButtonIndex - 4], currentView: $currentView, focusedButtonIndex: $viewModel.focusedButtonIndex)
                        } else {
                            CurrentItemView(currentRom: nil, currentView: $currentView, focusedButtonIndex: $viewModel.focusedButtonIndex, addRomAction: {
                                viewModel.isPresented = true
                            })
                        }
                        TitleSortingView(titleText: "All Games", sortingText: "A-Z")
                            .padding(.top, 10)

                        if roms.isEmpty {
                            emptyView
                        } else {
                            // scroll down
                            romGridView
                        }
                        // load the SoolraControllerView without pauseViewModel
                        SoolraControllerView(currentView: $currentView, onButtonPress: { action in
                            viewModel.controllerDidPress(action: action, pressed: true)
                        })
                        // padding to make the controller expand more
                        // TODO: change this per iPhone model.
                        // hard to keep consistent with gameview
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
//            Task {
//                isLoading = true
//                await dataController.romManager.initBundledRoms()
//                await MainActor.run {
                    roms = dataController.romManager.fetchRoms()
                    viewModel.updateRomCount(roms.count)
//                    isLoading = false
//                }
//            }
        }
        .onChange(of: roms.count) { newCount in
            viewModel.updateRomCount(newCount)
        }
        .onChange(of: viewModel.selectedGameIndex) { index in
            if let index = index {
                let indexToSelect = index - 4
                if indexToSelect >= 0 && indexToSelect < roms.count {
                    let rom = roms[indexToSelect]
                    navigateToRom(rom)
                } else if index == 1 {
                    isSettingsPresented = true
                } else if index == 2 || index == 3 {
                    viewModel.isPresented.toggle()
                }
            }
            viewModel.selectedGameIndex = nil
        }
        .onChange(of: controllerViewModel.lastAction) { object in
            if let object = object, object.pressed, currentView == .grid {
                viewModel.controllerDidPress(action: object.action, pressed: object.pressed)
            }
        }
        .onChange(of: isSettingsPresented) { newValue in
            if !isSettingsPresented {
                roms = dataController.romManager.fetchRoms()
                viewModel.updateRomCount(roms.count)
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

    private func loadDefaultRoms() {
        Task {
            isLoading = true
            dataController.romManager.resetDeletedDefaultRoms()
            await dataController.romManager.initDefaultRoms()
            await MainActor.run {
                roms = dataController.romManager.fetchRoms()
                viewModel.updateRomCount(roms.count)
                isLoading = false
            }
        }
    }
    
    
    private func controllerActionButtonPressed() {
        let focusedButtonIndex = viewModel.focusedButtonIndex
        if focusedButtonIndex == 1 {
            isSettingsPresented = true

        } else if focusedButtonIndex == 2 {
            viewModel.isPresented = true

        } else if focusedButtonIndex == 3 {
            viewModel.isPresented.toggle()
        } else {
            let indexToSelect = focusedButtonIndex - 4
            if indexToSelect >= 0 {
                let rom = roms[indexToSelect]
                navigateToRom(rom)
            }
        }
    }

    // MARK: - Subviews

        
    private var emptyView: some View {
        VStack {
            Spacer()
            Text("There are no ROMs")
                .font(.custom("Orbitron-Black", size: 24))
            Button("Load default ROMs") {
                loadDefaultRoms()
            }
            .font(.custom("Orbitron-SemiBold", size: 24))
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
                .background(Color.purple)
                Spacer()
                Spacer()
                Spacer()
            
            Button("Upload ROMs") {
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
                    Button(action: {
                        viewModel.isPresented.toggle()
                    }) {
                        addRomIcon()
                    }
                    .id(3)  // Add id for the upload game button
                    ForEach(Array(roms.enumerated()), id: \.1) { index, rom in
                        Button(action: {
                            navigateToRom(rom)
                        }) {
                            romIcon(for: rom, index: index + 4)
                        }
                        .id(index + 4)  // Add id for scrolling

                        if isEditMode == .active {
                            Button(action: {
                                withAnimation {
                                    dataController.romManager.deleteRom(rom: rom)
                                    roms = dataController.romManager.fetchRoms()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .padding(4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            }
            .onChange(of: viewModel.focusedButtonIndex) { newIndex in
                if newIndex >= 3 {  // Changed from 4 to 3 to include the upload game cube
                    withAnimation {
                        scrollProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func navigateToRom(_ rom: Rom) {
        Task {
            do {
                // Create console manager and load ROM and init cheat manager
                let consoleManager = try ConsoleCoreManager(metalManager: metalManager)

                // Load everything before transitioning view
                let gameData = try await loadRom(rom: rom, consoleManager: consoleManager)
                
                consoleManager.cheatCodesManager = CheatCodesManager(gameName: rom.name ?? "unknown", consoleManager: consoleManager)
                
                // Once everything is ready, update the view
                await MainActor.run {
                    //withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentView = .game(gameData)
                    //}
                }
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

                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .opacity(0.5)
                            .frame(height: 27)

                        Image("home-search-bold")
                            .resizable()
                            .foregroundColor(.white)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(.trailing, 10)
                    }
                    .frame(maxWidth: .infinity)

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
                        if let data = currentRom?.imageData, let uiImage = UIImage(data: data) {
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

                Text(currentRom?.name ?? "Add Game")
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

