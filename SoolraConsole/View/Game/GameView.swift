//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Combine
import SwiftUI
import SpriteKit
import CoreData

// MARK: - Game Screen Container
private struct GameScreenContainer: View {
    let geometry: GeometryProxy
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    
    var body: some View {
        GameScreenView()
            .frame(
                width: geometry.size.width,
                height: geometry.size.height * 0.58
            )
            .padding(.bottom, 3)
            .environmentObject(consoleManager)
    }
}

// MARK: - Controller Container
private struct ControllerContainer: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @Binding var currentView: CurrentView
    let geometry: GeometryProxy
    let pauseViewModel: PauseGameViewModel
    let totalHeight: CGFloat
    
    var body: some View {
        // load the SoolraControllerView with pauseViewModel
        SoolraControllerView(currentView: $currentView, pauseViewModel: pauseViewModel)
            .frame(width: geometry.size.width, height: totalHeight * 0.48)
            .edgesIgnoringSafeArea(.bottom)
            .environmentObject(consoleManager)
    }
}

// MARK: - Main Game View
struct GameView: View {
    static let frameRate = 60

    var name: String
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @Binding var currentView: CurrentView
    @ObservedObject var pauseViewModel: PauseGameViewModel
    @EnvironmentObject var controllerViewModel: ControllerViewModel
    @Environment(\.managedObjectContext) private var context
    @State private var appLaunchedFromExternalRom = false
    
    init(data: GameViewData, currentView: Binding<CurrentView>, pauseViewModel: PauseGameViewModel) {
        self.name = data.name
        self._currentView = currentView
        self.pauseViewModel = pauseViewModel
    }

    var body: some View {
        mainContent
            .navigationTitle(name)
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                handleOnAppear()
            }
            .onDisappear(perform: handleOnDisappear)
            .onChange(of: controllerViewModel.lastAction, perform: handleControllerActionChange)
            .onChange(of: consoleManager.shouldShowPauseMenu) { shouldShow in
                print("🎮 Detected shouldShowPauseMenu change to: \(shouldShow)")
                if shouldShow {
                    print("🎮 Attempting to show pause menu")
                    pauseViewModel.togglePause()
                    // Reset the flag after handling it
                    Task { @MainActor in
                        consoleManager.shouldShowPauseMenu = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchRomFromExternalSource)) { _ in
                appLaunchedFromExternalRom = true
            }

            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                print("🎮 App will resign active - ensuring game is paused")
                pauseViewModel.ensurePaused()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                guard !appLaunchedFromExternalRom else { return }
                print("🎮 App did become active - showing pause menu")
                // Force show the pause menu regardless of current state
                pauseViewModel.showPauseMenuOnForeground()
            }
            .environmentObject(controllerViewModel)
            .background(Color("AppGray"))
            .overlay(
                // Show exit overlay when needed
                Group {
                    if pauseViewModel.isExiting {
//                        GameLoadingOverlayView(message: "Shutting down...")
//                            .transition(.opacity)
//                            .animation(.easeInOut, value: pauseViewModel.isExiting)
                    }
                }
            )
    }
    
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                let totalHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                
                VStack(spacing: 0) {
                    GameScreenContainer(geometry: geometry)
                        .environmentObject(consoleManager)
                        // Blur game screen during exit
                        .blur(radius: pauseViewModel.isExiting ? 10 : 0)
                        .animation(.easeInOut, value: pauseViewModel.isExiting)
                    
                    ControllerContainer(
                        currentView: $currentView,
                        geometry: geometry,
                        pauseViewModel: pauseViewModel,
                        totalHeight: totalHeight
                    )
                    .environmentObject(consoleManager)
                }
                .edgesIgnoringSafeArea(.all)
                
                if pauseViewModel.showPauseMenu {
                    PauseGameView(pauseViewModel: pauseViewModel)
                        .environmentObject(themeManager)
                        .transition(.opacity)
                        .animation(.easeInOut, value: pauseViewModel.showPauseMenu)
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleOnAppear() {
        BluetoothControllerService.shared.delegate = controllerViewModel
        print("GameView: Setting controller delegate")
    }
    
    private func handleOnDisappear() {
        if BluetoothControllerService.shared.delegate === controllerViewModel {
            print("GameView: Setting controller delegate back to HomeView")
            HomeViewModel.shared.setAsDelegate()
        }
    }
    
    private func handleControllerActionChange(_ action: ControllerAction?) {
        if let action = action, currentView != .grid {
            handleAction(controllerAction: action)
        }
    }

    private func handleAction(controllerAction: ControllerAction) {
        if pauseViewModel.showPauseMenu {
            // Only pass pressed events to the pause menu
            if controllerAction.pressed {
                print("🎮 Passing controller action to pause menu: \(controllerAction.action)")
                pauseViewModel.handleControllerAction(controllerAction.action, pressed: controllerAction.pressed)
            }
            return
        }
        
        // Handle menu button to show/hide pause menu
        if controllerAction.action == .menu && controllerAction.pressed {
            pauseViewModel.togglePause()
            return
        }
        
        // Handle other controller actions
        consoleManager.handleControllerAction(controllerAction.action, pressed: controllerAction.pressed)
    }
}
