//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct ArrowsView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @ObservedObject var controllerViewModel: ControllerViewModel
    @State private var isPressed = false
    var onButtonPress: ((SoolraControllerAction) -> Void)?
    var onButton: ((SoolraControllerAction, Bool) -> Void)?
    var body: some View {
        ZStack {
            Image("controller-arrows")
                .resizable()
                .scaledToFill()
                .frame(width: 126, height: 126)
                .clipped()
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut, value: isPressed)
            
            // Up Button
            Button(action: {}) { Color.clear }
                        .frame(width: 42, height: 42)
                        .position(x: 63, y: 31)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isPressed {
                                        isPressed = true
                                        HapticManager.shared.buttonPress()
//                                        onButton?(.up, true)
                                        controllerViewModel.controllerDidPress(action: .up, pressed: true)
                                    }
                                }
                                .onEnded { _ in
                                    isPressed = false
                                    HapticManager.shared.buttonRelease()
//                                    onButton?(.up, false)
                                    controllerViewModel.controllerDidPress(action: .up, pressed: false)
                                }
                        )
            
            // Down Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 63, y: 95)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
//                            onButton?(.down, true)
                            controllerViewModel.controllerDidPress(action: .down, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
//                        onButton?(.down, false)
                        controllerViewModel.controllerDidPress(action: .down, pressed: false)
                    }
            )
            
            // Left Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 31, y: 63)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
//                            onButton?(.left, true)
                            controllerViewModel.controllerDidPress(action: .left, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
//                        onButton?(.left, false)
                        controllerViewModel.controllerDidPress(action: .left, pressed: false)
                    })
        
            
            // Right Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 95, y: 63)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.buttonPress()
//                            onButton?(.right, true)
                            controllerViewModel.controllerDidPress(action: .right, pressed: true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.right, false)
                        controllerViewModel.controllerDidPress(action: .right, pressed: false)
                    })
        
        }
        .frame(width: 126, height: 126)
    }
}


