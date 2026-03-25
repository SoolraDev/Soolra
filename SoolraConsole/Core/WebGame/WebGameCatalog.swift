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
//        let uVp = URL(string: "http://128.140.121.129/tank-arcade/")!
//        let uVp = URL(string: "https://webgames.soolra.com/vp/")!
        let uAnimalPuzzle = URL(string: "http://webgames.soolra.com/animals_puzzle/")!
        let utvpoker = URL(string: "http://128.140.121.129/tv-poker/")!
        let uTanks = URL(string: "http://128.140.121.129/tank-arcade/")!
        let uBlackjack = URL(string: "http://128.140.121.129/blackJack3/")!
        let uPlatformer = URL(string: "http://128.140.121.129/mario/")!


        return [

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
                name: "Video Poker",
                url: utvpoker,
                icon: UIImage(named: "Video Poker"),
                makeViewModel: { UnityGameViewModel(startURL: utvpoker) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Tank Arcade",
                url: uTanks,
                icon: UIImage(named: "Tank Arcade"),
                makeViewModel: { UnityGameViewModel(startURL: uTanks) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(UnityGameWrapper(viewModel: vm as! UnityGameViewModel, onClose: onClose))
                }
            ),
            WebGame(
                name: "Platformer",
                url: uPlatformer,
                icon: UIImage(named: "Platformer"),
                makeViewModel: { PlatformerViewModel(startURL: uPlatformer) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(PlatformerWrapper(viewModel: vm as! PlatformerViewModel, onClose: onClose))
                }
            ),
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
