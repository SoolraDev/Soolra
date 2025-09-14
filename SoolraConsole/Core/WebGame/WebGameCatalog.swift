//
//  WebGameCatalog.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 10/08/2025.
//

import Foundation
import UIKit
import SwiftUICore


enum WebGameCatalog {
    static func all() -> [WebGame] {
        let u2048 = URL(string: "https://axilleasiv.github.io/vue2048/")!
        let yabalali_trivia = URL(string: "https://stg-yabaleli.b-cdn.net/trivia_game.html")!
        let uHextris = URL(string: "https://hextris.io/")!

        return [
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
