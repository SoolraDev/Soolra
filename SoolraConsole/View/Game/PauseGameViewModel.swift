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
    @Published var showSaveStateView: Bool = false
    @Published var showLoadStateView: Bool = false

    @Published var menuItems: [PauseMenuItem] = [
        .resume,
        .saveState,
        .loadState,
        .cheatCodes,
        .fastForward(false),
        .exit
    ]

    @Published var isFastForwardEnabled: Bool = false

    static var exitAction: (() -> Task<Void, Never>)?
    weak var consoleManager: ConsoleCoreManager?
    let currentRom: Rom

    init(consoleManager: ConsoleCoreManager, currentRom: Rom) {
        self.consoleManager = consoleManager
        self.currentRom = currentRom
    }
    
    func setExitAction(_ action: @escaping () -> Task<Void, Never>) {
        Self.exitAction = action
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
        guard !isExiting, pressed else { return }

        print("⏸️ Handling controller action: \(action), pressed: \(pressed)")

        Task { @MainActor in
            let maxIndex = menuItems.count - 1
            let columns = 2

            switch action {
            case .up:
                if selectedMenuIndex - columns >= 0 {
                    selectedMenuIndex -= columns
                    print("⏸️ Menu moved up to \(selectedMenuIndex)")
                }

            case .down:
                if selectedMenuIndex + columns <= maxIndex {
                    selectedMenuIndex += columns
                    print("⏸️ Menu moved down to \(selectedMenuIndex)")
                }

            case .left:
                if selectedMenuIndex % columns > 0 {
                    selectedMenuIndex -= 1
                    print("⏸️ Menu moved left to \(selectedMenuIndex)")
                }

            case .right:
                if selectedMenuIndex % columns < columns - 1 && selectedMenuIndex + 1 <= maxIndex {
                    selectedMenuIndex += 1
                    print("⏸️ Menu moved right to \(selectedMenuIndex)")
                }

            case .menu, .a:
                handleSelection()

            default:
                break
            }
        }
    }
    
    private func handleSelection() {
        switch menuItems[selectedMenuIndex] {
        case .resume:
            togglePause()
        case .exit:
            initiateExit()
        case .cheatCodes:
            showCheatCodesView = true
        case .fastForward(_):
            isFastForwardEnabled.toggle()
            consoleManager?.toggleFastForward()
            menuItems[selectedMenuIndex] = .fastForward(isFastForwardEnabled)
        case .saveState:
            showSaveStateView = true
        case .loadState:
            showLoadStateView = true
        }
    }

    
    func initiateExit() {
        guard !isExiting else { return }
        isExiting = true
        
        // Keep pause menu visible during exit
        isPaused = true
        showPauseMenu = true
        
        // Start exit process and await its completion
        if let action = PauseGameViewModel.exitAction {
            Task {
                await action().value
            }
        }
    }
}
enum PauseMenuItem: Identifiable {
    case resume
    case exit
    case cheatCodes
    case fastForward(Bool)
    case saveState
    case loadState

    var id: String {
        switch self {
        case .resume: return "resume"
        case .exit: return "exit"
        case .cheatCodes: return "cheatCodes"
        case .fastForward: return "fastForward"
        case .saveState: return "saveState"
        case .loadState: return "loadState"
        }
    }

    var title: String {
        switch self {
        case .resume: return "Resume"
        case .exit: return "Exit Game"
        case .cheatCodes: return "Cheat Codes"
        case .fastForward(let isOn): return "Fast Forward: \(isOn ? "On" : "Off")"
        case .saveState: return "Save Game"
        case .loadState: return "Load Game"
        }
    }
    var isExit: Bool {
            if case .exit = self { return true }
            else               { return false }
        }
}
