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
        let u = URL(string: "https://axilleasiv.github.io/vue2048/")!
        return [
            WebGame(
                name: "2048",
                url: u,
                icon: UIImage(named: "icon-2048"),
                makeViewModel: { Game2048ViewModel(startURL: u) as any WebGameViewModel },
                makeWrapper: { vm, onClose in
                    AnyView(Game2048Wrapper(viewModel: vm as! Game2048ViewModel, onClose: onClose))
                }
            )
        ]
    }
}
