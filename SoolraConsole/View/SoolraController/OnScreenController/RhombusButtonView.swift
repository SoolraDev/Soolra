//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct RhombusButtonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    var onButtonPress: ((SoolraControllerAction) -> Void)?

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
                    .onChanged({ _ in
                        onButtonPress?(.x)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.x, pressed: true)
                    })
                    .onEnded({ _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.x, pressed: false)
                    })
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
                    .onChanged({ _ in
                        onButtonPress?(.b)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.b, pressed: true)
                    })
                    .onEnded({ _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.b, pressed: false)
                    })
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
                    .onChanged({ _ in
                        onButtonPress?(.y)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.y, pressed: true)
                    })
                    .onEnded({ _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.y, pressed: false)
                    })
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
                    .onChanged({ _ in
                        onButtonPress?(.a)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.a, pressed: true)
                    })
                    .onEnded({ _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.a, pressed: false)
                    })
            )
        }
        .frame(width: 135, height: 135)
    }
}

