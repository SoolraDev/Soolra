//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct ShoulderButtonView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    var onButtonPress: ((SoolraControllerAction) -> Void)?

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
                        onButtonPress?(.l)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.l, pressed: true)
                    }
                    .onEnded { _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.l, pressed: false)
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
                        onButtonPress?(.r)
                        HapticManager.shared.buttonPress()
                        consoleManager.handleControllerAction(.r, pressed: true)
                    }
                    .onEnded { _ in
                        HapticManager.shared.buttonRelease()
                        consoleManager.handleControllerAction(.r, pressed: false)
                    }
            )
        }
    }
}
