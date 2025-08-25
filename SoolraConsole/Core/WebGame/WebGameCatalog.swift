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
        let uKrunker = URL(string: "https://krunker.io/")!

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
                name: "Krunker",
                url: uKrunker,
                icon: UIImage(systemName: "cursorarrow.rays"), // replace with asset if you have one
                makeViewModel: { KrunkerViewModel(startURL: uKrunker) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(KrunkerWrapper(viewModel: vm as! KrunkerViewModel, onClose: onClose))
                }
            )
        ]
    }
}
