//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct ShoulderButtonView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    var onButtonPress: ((SoolraControllerAction) -> Void)?
    var onButton: ((SoolraControllerAction, Bool) -> Void)?
    @State private var isPressed = false

    var body: some View {
        HStack {
            // Left Shoulder
            Button(action: {}) {
                Image("controller-l")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            .padding(.leading, 30)
            .padding(.top, 5)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
                            onButton?(.l, true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.l, false)
                    }
            )

            Spacer()

            // Right Shoulder
            Button(action: {}) {
                Image("controller-r")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            .padding(.trailing, 30)
            .padding(.top, 5)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
                            onButton?(.r, true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.r, false)
                    }
            )
        }
    }
}
