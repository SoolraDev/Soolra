//
//  CheatCodesManager.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 15/04/2025.
//


import Foundation

class CheatCodesManager: ObservableObject {
    @Published private(set) var cheats: [Cheat] = []
    
    private let storage = CheatStorage()
    private let gameName: String

    init(gameName: String) {
        self.gameName = gameName
        self.cheats = storage.loadCheats(for: gameName)
    }

    func toggleCheat(at index: Int, consoleManager: ConsoleCoreManager) {
        cheats[index].isActive.toggle()
        save()

        if cheats[index].isActive {
            consoleManager.activateCheat(cheats[index])
        } else {
            resetAndReapplyActiveCheats(consoleManager: consoleManager)
        }
    }

    func addCheat(_ cheat: Cheat, consoleManager: ConsoleCoreManager) {
        cheats.append(cheat)
        save()
        if cheat.isActive {
            consoleManager.activateCheat(cheat)
        }
    }

    private func save() {
        storage.saveCheats(cheats, for: gameName)
    }

    private func resetAndReapplyActiveCheats(consoleManager: ConsoleCoreManager) {
        consoleManager.resetCheats()
        for cheat in cheats where cheat.isActive {
            consoleManager.activateCheat(cheat)
        }
    }
}
