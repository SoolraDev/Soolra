//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Combine
import SwiftUI
import SpriteKit
import CoreData

// MARK: - Pause Menu
class PauseGameViewModel: ObservableObject {
    @Published var isPaused: Bool = false
    @Published var selectedMenuIndex: Int = 0
    @Published var showPauseMenu: Bool = false
    @Published private(set) var isExiting: Bool = false
    @Published var showCheatCodesView: Bool = false

    
    let menuItems = ["Resume", "Exit Game", "Cheat Codes"]
    private var exitAction: (() -> Task<Void, Never>)?
    private weak var consoleManager: ConsoleCoreManager?
    
    init(consoleManager: ConsoleCoreManager) {
        self.consoleManager = consoleManager
    }
    
    func setExitAction(_ action: @escaping () -> Task<Void, Never>) {
        self.exitAction = action
    }
    
    func showPauseMenuOnForeground() {
        print("⏸️ Showing pause menu on app foreground")
        guard let consoleManager = consoleManager, consoleManager.isGameRunning else {
            print("⏸️ No game running, skipping pause menu")
            return
        }
        
        // Ensure the game is paused and menu is shown
        isPaused = true
        showPauseMenu = true
        consoleManager.pauseEmulation()
        selectedMenuIndex = 0
    }
    
    func ensurePaused() {
        print("⏸️ Ensuring game is paused")
        guard let consoleManager = consoleManager, consoleManager.isGameRunning else {
            print("⏸️ No game running, skipping pause")
            return
        }
        
        if !isPaused {
            // When going to background, we want to pause without showing the menu
            // This way when we come back to foreground, we can show the menu properly
            isPaused = true
            consoleManager.pauseEmulation()
            showPauseMenu = false
            print("⏸️ Game paused without showing menu")
        } else {
            print("⏸️ Game is already paused")
        }
    }
    
    func togglePause() {
        // Don't allow unpausing during exit or initialization
        if isExiting { 
            print("⏸️ Cannot toggle pause - game is exiting")
            return 
        }
        
        guard let consoleManager = consoleManager, consoleManager.isGameRunning else {
            print("⏸️ No game running, cannot toggle pause")
            return
        }
        
        // Add a small delay to ensure Metal view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                print("⏸️ Cannot toggle pause - self was deallocated")
                return
            }
            
            print("⏸️ Toggling pause state from \(self.isPaused) to \(!self.isPaused)")
            
            if !self.isPaused {
                // Pausing
                self.isPaused = true
                print("⏸️ Pausing emulation and showing menu")
                self.consoleManager?.pauseEmulation()
                self.showPauseMenu = true
            } else {
                // Resuming
                print("⏸️ Hiding menu and resuming emulation")
                self.isPaused = false
                self.showPauseMenu = false
                self.consoleManager?.resumeEmulation()
            }
            
            Task { @MainActor in
                self.selectedMenuIndex = 0
            }
            print("⏸️ Pause state change complete - isPaused: \(self.isPaused), showPauseMenu: \(self.showPauseMenu)")
        }
    }
    
    func handleControllerAction(_ action: SoolraControllerAction, pressed: Bool) {
        // Don't handle inputs during exit
        guard !isExiting else {
            print("⏸️ Cannot handle controller action - game is exiting")
            return
        }
        
        print("⏸️ Handling controller action: \(action), pressed: \(pressed)")
        
        Task { @MainActor in
            switch action {
            case .up:
                selectedMenuIndex = max(0, selectedMenuIndex - 1)
                print("⏸️ Menu selection moved up to index: \(selectedMenuIndex)")
            case .down:
                selectedMenuIndex = min(menuItems.count - 1, selectedMenuIndex + 1)
                print("⏸️ Menu selection moved down to index: \(selectedMenuIndex)")
            case .menu, .a:
                switch selectedMenuIndex {
                case 0:
                    print("⏸️ Resume selected")
                    togglePause()
                case 1:
                    print("⏸️ Exit selected")
                    initiateExit()
                case 2:
                    print("⏸️ Cheat Codes selected")
                    showCheatCodesView = true
                default:
                    break
                }
            default:
                break
            }
        }
    }
    
    func initiateExit() {
        guard !isExiting else { return }
        isExiting = true
        
        // Keep pause menu visible during exit
        isPaused = true
        showPauseMenu = true
        
        // Start exit process and await its completion
        if let action = exitAction {
            Task {
                await action().value
            }
        }
    }
}
