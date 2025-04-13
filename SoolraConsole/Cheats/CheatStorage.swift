//
//  CheatStorage.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 13/04/2025.
//

import Foundation


class CheatStorage {
    private let keyPrefix = "cheats_"

    func loadCheats(for gameName: String) -> [Cheat] {
        guard gameName != "unknown" else { return [] }
        let key = keyPrefix + gameName
        if let data = UserDefaults.standard.data(forKey: key),
           let cheats = try? JSONDecoder().decode([Cheat].self, from: data) {
            return cheats
        }
        return []
    }

    func saveCheats(_ cheats: [Cheat], for gameName: String) {
        guard gameName != "unknown" else { return }
        let key = keyPrefix + gameName
        if let data = try? JSONEncoder().encode(cheats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
