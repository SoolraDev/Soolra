//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct ShoulderButtonView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @ObservedObject var controllerViewModel: ControllerViewModel
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
//                            onButton?(.l, true)
                            controllerViewModel.controllerDidPress(action: .l, pressed: true)
                            
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
//                        onButton?(.l, false)
                        controllerViewModel.controllerDidPress(action: .l, pressed: false)
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
//                            onButton?(.r, true)
                            controllerViewModel.controllerDidPress(action: .r, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
//                        onButton?(.r, false)
                        controllerViewModel.controllerDidPress(action: .r, pressed: false)
                    }
            )
        }
    }
}
