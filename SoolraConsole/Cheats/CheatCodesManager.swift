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

    init(gameName: String, consoleManager: ConsoleCoreManager) {
        self.gameName = gameName
        self.consoleManager = consoleManager
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
}
