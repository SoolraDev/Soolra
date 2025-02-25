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
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 63, y: 31)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        isPressed = true
                        HapticManager.shared.buttonPress()
                        onButtonPress?(.up)
                        consoleManager.handleControllerAction(.up, pressed: true)
                    })
                    .onEnded({ _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.up, pressed: false)
                    })
            )
            
            // Down Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 63, y: 95)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        isPressed = true
                        HapticManager.shared.buttonPress()
                        onButtonPress?(.down)
                        consoleManager.handleControllerAction(.down, pressed: true)
                    })
                    .onEnded({ _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.down, pressed: false)
                    })
            )
            
            // Left Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 31, y: 63)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        isPressed = true
                        HapticManager.shared.buttonPress()
                        onButtonPress?(.left)
                        consoleManager.handleControllerAction(.left, pressed: true)
                    })
                    .onEnded({ _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.left, pressed: false)
                    })
            )
            
            // Right Button
            Button(action: {}) {
                Color.clear
            }
            .frame(width: 42, height: 42)
            .position(x: 95, y: 63)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        isPressed = true
                        HapticManager.shared.buttonPress()
                        onButtonPress?(.right)
                        consoleManager.handleControllerAction(.right, pressed: true)
                    })
                    .onEnded({ _ in
                        isPressed = false
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.right, pressed: false)
                    })
            )
        }
        .frame(width: 126, height: 126)
    }
}


