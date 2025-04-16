//
//  CheatCodesManager.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 15/04/2025.
//


import Foundation

class CheatCodesManager: ObservableObject {
    @Published private(set) var cheats: [Cheat] = []
    weak var consoleManager: ConsoleCoreManager?
    private let storage = CheatStorage()
    private let gameName: String
    private let consoleType: ConsoleCoreManager.ConsoleType
    init(gameName: String, consoleManager: ConsoleCoreManager) {
        self.gameName = gameName
        self.consoleManager = consoleManager
        self.consoleType = consoleManager.managerState.currentCoreType ?? .nes
        self.cheats = storage.loadCheats(for: gameName)
        resetAndReapplyActiveCheats()
    }

    func toggleCheat(at index: Int) {
        cheats[index].isActive.toggle()
        save()

        if cheats[index].isActive {
            consoleManager?.activateCheat(cheats[index])
        } else {
            resetAndReapplyActiveCheats()
        }
    }

    func addCheat(_ cheat: Cheat) {
        cheats.append(cheat)
        save()
        if cheat.isActive {
            consoleManager?.activateCheat(cheat)
        }
    }

    private func save() {
        storage.saveCheats(cheats, for: gameName)
    }

    private func resetAndReapplyActiveCheats() {
        consoleManager?.resetCheats()
        for cheat in cheats where cheat.isActive {
            consoleManager?.activateCheat(cheat)
        }
    }
    func updateCheat(original: Cheat, updated: Cheat) {
        guard let index = cheats.firstIndex(of: original) else { return }

        // Replace the cheat
        cheats[index] = updated
        save()

        // Reset & reapply active cheats if needed
        resetAndReapplyActiveCheats()
    }

    
    func deleteCheat(at index: Int) {
        guard cheats.indices.contains(index) else { return }

        let wasActive = cheats[index].isActive
        cheats.remove(at: index)
        save()

        // If the deleted cheat was active, reset & reapply remaining active ones
        if wasActive {
            resetAndReapplyActiveCheats()
        }
    }

}
