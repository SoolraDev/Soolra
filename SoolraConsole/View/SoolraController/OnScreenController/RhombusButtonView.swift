//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct RhombusButtonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @ObservedObject var controllerViewModel: ControllerViewModel

    var onButtonPress: ((SoolraControllerAction) -> Void)?
    var onButton: ((SoolraControllerAction, Bool) -> Void)?
    @State private var isPressed = false
    var body: some View {
        ZStack {
            // X Button (Top)
            Button(action: {}) {
                Image("controller-x")
                    .resizable()
                    .frame(width: 45, height: 45)
            }
            .position(x: 60, y: 18)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
                            onButton?(.x, true)
                            controllerViewModel.controllerDidPress(action: .x, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.x, false)
                        controllerViewModel.controllerDidPress(action: .x, pressed: false)
                    }
            )
            
            // B Button (Bottom)
            Button(action: {}) {
                Image("controller-b")
                    .resizable()
                    .frame(width: 45, height: 45)
            }
            .position(x: 60, y: 102)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
                            onButton?(.b, true)
                            controllerViewModel.controllerDidPress(action: .b, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.b, false)
                        controllerViewModel.controllerDidPress(action: .b, pressed: false)
                    }
            )

            // Y Button (Left)
            Button(action: {}) {
                Image("controller-y")
                    .resizable()
                    .frame(width: 45, height: 45)
            }
            .position(x: 18, y: 60)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
                            onButton?(.y, true)
                            controllerViewModel.controllerDidPress(action: .y, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.y, false)
                        controllerViewModel.controllerDidPress(action: .y, pressed: false)
                    }
            )

            // A Button (Right)
            Button(action: {}) {
                Image("controller-a")
                    .resizable()
                    .frame(width: 45, height: 45)
            }
            .position(x: 102, y: 60)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
//                            onButton?(.a, true)
                            controllerViewModel.controllerDidPress(action: .a, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
//                        onButton?(.a, false)
                        controllerViewModel.controllerDidPress(action: .a, pressed: false)
                    }
            )
            
        }
        .frame(width: 135, height: 135)
    }
}

