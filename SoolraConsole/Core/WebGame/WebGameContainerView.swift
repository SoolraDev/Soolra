//
//  WebGameContainerView.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 10/08/2025.
//

import SwiftUI

struct WebGameContainerView: View {
    let game: WebGame
    let onClose: () -> Void
    @StateObject private var vm: ObservableVM

    init(game: WebGame, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ObservableVM(base: game.makeViewModel()))
        self.game = game
        self.onClose = onClose
    }

    var body: some View {
        game.makeWrapper(vm.base, onClose)
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }

    private final class ObservableVM: ObservableObject {
        let base: any WebGameViewModel
        init(base: any WebGameViewModel) { self.base = base }
    }
}
