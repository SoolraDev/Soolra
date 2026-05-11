//
//  SOOLRA - Hidden Web Games Manager
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import Combine

class HiddenWebGamesManager: ObservableObject {
    static let shared = HiddenWebGamesManager()

    @Published private(set) var hiddenIds: Set<String> = []

    private let userDefaultsKey = "soolra.hiddenWebGames"

    private init() {
        loadHidden()
    }

    private func stableID(for webGame: WebGame) -> String {
        return "web-\(webGame.name)"
    }

    func isHidden(_ webGame: WebGame) -> Bool {
        return hiddenIds.contains(stableID(for: webGame))
    }

    func hide(_ webGame: WebGame) {
        hiddenIds.insert(stableID(for: webGame))
        saveHidden()
    }

    func unhide(_ webGame: WebGame) {
        hiddenIds.remove(stableID(for: webGame))
        saveHidden()
    }

    private func loadHidden() {
        if let data = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            hiddenIds = Set(data)
        }
    }

    private func saveHidden() {
        UserDefaults.standard.set(Array(hiddenIds), forKey: userDefaultsKey)
    }
}
