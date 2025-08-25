//
//  SOOLRA
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct MenuButtonView: View {
    @EnvironmentObject var themeManager: ThemeManager

    // Kept for compatibility with existing call sites (not used here).
    let pauseViewModel: PauseGameViewModel?

    // NEW: same contract as arrows: (action, pressed)
    var onButton: ((SoolraControllerAction, Bool) -> Void)?

    @State private var isPressed = false

    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 72, height: 29)
                .foregroundColor(themeManager.keyBackgroundColor)
                .overlay(
                    Capsule()
                        .stroke(themeManager.keyBorderColor.opacity(0.8), lineWidth: 2)
                        .shadow(color: themeManager.keyShadowColor, radius: 4, x: 0, y: 2)
                )

            Text("Menu")
                .foregroundColor(themeManager.whitetextColor)
                .font(.custom("Orbitron-Black", size: 11))
                .fontWeight(.bold)
                .opacity(0.7)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.shared.buttonPress()
                        onButton?(.menu, true)   // press
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.menu, false)  // release
                    }
                }
        )
    }
}
