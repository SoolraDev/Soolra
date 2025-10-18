//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct ArrowsView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
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
                                        onButton?(.up, true)
                                    }
                                }
                                .onEnded { _ in
                                    isPressed = false
                                    HapticManager.shared.buttonRelease()
                                    onButton?(.up, false)
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
                            onButton?(.down, true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.down, false)
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
                            onButton?(.left, true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.left, false)
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
                            onButton?(.right, true)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        onButton?(.right, false)
                    })
        
        }
        .frame(width: 126, height: 126)
    }
}


