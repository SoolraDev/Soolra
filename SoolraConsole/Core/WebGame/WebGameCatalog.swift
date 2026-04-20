//
//  WebGameCatalog.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 10/08/2025.
//

import Foundation
import UIKit
import SwiftUI


enum WebGameCatalog {
    static func all() -> [WebGame] {
//        let u2048 = URL(string: "https://axilleasiv.github.io/vue2048/")!
        let u2048 = URL(string: "https://webgame-server-058de90773d7.herokuapp.com/vue2048/")!
        let uStacker = URL(string: "https://webgame-server-058de90773d7.herokuapp.com/stacker/")!
//        let yabalali_trivia = URL(string: "https://stg-yabaleli.b-cdn.net/trivia_game.html")!
//        let uHextris = URL(string: "https://hextris.io/")!
        let uHextris = URL(string: "https://webgame-server-058de90773d7.herokuapp.com/hextris/")!
        let uTower = URL(string: "https://webgame-server-058de90773d7.herokuapp.com/tower/")!
        let uHexGl = URL(string: "https://webgames.soolra.com/hexgl/")!
        //        let uTanks = URL(string: "http://128.140.121.129/tank-arcade/")!
//        let uAnimalPuzzle = URL(string: "https://soolra-animal-puzzle.netlify.app")!
//        let utvpoker = URL(string: "https://soolra-videopoker.netlify.app")!
//        let uBlackjack = URL(string: "https://soolra-blackjack.netlify.app")!
//        let uPlatformer = URL(string: "https://soolra-meow-meow.netlify.app")!
//        let uAirHockey = URL(string: "https://soolra-air-hockey.netlify.app")!
//        let uBrickOut = URL(string: "https://soolra-brick-out.netlify.app")!
//        let uDarts = URL(string: "https://soolra-darts.netlify.app")!
        let uAnimalPuzzle = URL(string: "https://webgames.soolrafreegames.com/animal_puzzle/index.html")!
        let utvpoker = URL(string: "https://webgames.soolrafreegames.com/tv-poker/index.html")!
        let uBlackjack = URL(string: "https://webgames.soolrafreegames.com/blackJack3/index.html")!
        let uPlatformer = URL(string: "https://webgames.soolrafreegames.com/meow_meow_adventure/index.html")!
        let uAirHockey = URL(string: "https://webgames.soolrafreegames.com/air-hockey/index.html")!
        let uBrickOut = URL(string: "https://webgames.soolrafreegames.com/brickOut/index.html")!
        let uDarts = URL(string: "https://webgames.soolrafreegames.com/darts/index.html")!

        return [
            WebGame(
                name: "Kitty Adventure",
                url: uPlatformer,
                icon: UIImage(named: "Kitty Adventure"),
                makeViewModel: { PlatformerViewModel(startURL: uPlatformer) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(PlatformerWrapper(viewModel: vm as! PlatformerViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "HexGl",
                url: uHexGl,
                icon: UIImage(named: "HexGl"),
                makeViewModel: { HexGlViewModel(startURL: uHexGl) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(HexGlWrapper(viewModel: vm as! HexGlViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Tower",
                url: uTower,
                icon: UIImage(named: "Tower"),
                makeViewModel: { TowerViewModel(startURL: uTower) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(TowerWrapper(viewModel: vm as! TowerViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "2048",
                url: u2048,
                icon: UIImage(named: "2048"),
                makeViewModel: { Game2048ViewModel(startURL: u2048) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(Game2048Wrapper(viewModel: vm as! Game2048ViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Hextris",
                url: uHextris,
                icon: UIImage(named: "Hextris"),
                makeViewModel: { HextrisViewModel(startURL: uHextris) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(HextrisWrapper(viewModel: vm as! HextrisViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Crane",
                url: uStacker,
                icon: UIImage(named: "Crane"),
                makeViewModel: { StackerViewModel(startURL: uStacker) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(StackerWrapper(viewModel: vm as! StackerViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Animal Puzzle",
                url: uAnimalPuzzle,
                icon: UIImage(named: "Animal Puzzle"),
                makeViewModel: { UnityGameViewModel(startURL: uAnimalPuzzle) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Air Hockey",
                url: uAirHockey,
                icon: UIImage(named: "Air Hockey"),
                makeViewModel: { UnityGameViewModel(startURL: uAirHockey) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Blackjack",
                url: uBlackjack,
                icon: UIImage(named: "Blackjack"),
                makeViewModel: { UnityGameViewModel(startURL: uBlackjack) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Brick Out",
                url: uBrickOut,
                icon: UIImage(named: "Brick Out"),
                makeViewModel: { UnityGameViewModel(startURL: uBrickOut) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Darts",
                url: uDarts,
                icon: UIImage(named: "Darts"),
                makeViewModel: { UnityGameViewModel(startURL: uDarts) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Video Poker",
                url: utvpoker,
                icon: UIImage(named: "Video Poker"),
                makeViewModel: { UnityGameViewModel(startURL: utvpoker) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
//            WebGame(
//                name: "Video Poker",
//                url: utvpoker,
//                icon: UIImage(named: "Video Poker"),
//                makeViewModel: { UnityGameViewModel(startURL: utvpoker) as any WebGameViewModel },
//                makeWrapper: { vm, onClose in
//                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
//                }
//            ),
//            WebGame(
//                name: "Tank Arcade",
//                url: uTanks,
//                icon: UIImage(named: "Tank Arcade"),
//                makeViewModel: { UnityGameViewModel(startURL: uTanks) as any WebGameViewModel },
//                makeWrapper: { vm, onClose in
//                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
//                }
//            )
//
//            WebGame(
//                name: "Video Blackjack",
//                url: uBlackjack,
//                icon: UIImage(named: "Video Blackjack"),
//                makeViewModel: { UnityGameViewModel(startURL: uBlackjack) as any WebGameViewModel },
//                makeWrapper: { vm, onClose in
//                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
//                }
//            ),
//            WebGame(
//                name: "Yabalali Trivia",
//                url: yabalali_trivia,
//                icon: UIImage(systemName: "cursorarrow.rays"), // replace with asset if you have one
//                makeViewModel: { YabalaliViewModel(startURL: yabalali_trivia) as any WebGameViewModel },
//                makeWrapper: { vm, onClose in
//                    AnyView(YabalaliWrapper(viewModel: vm as! YabalaliViewModel, onClose: onClose))
//                }
//            )
        ]
    }
}
