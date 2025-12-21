//
//  GameViewData.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 21/12/2025.
//


//
//  SOOLRA - Shared Types
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

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