//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct MergedFunctionalKeyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    var onButtonPress: ((SoolraControllerAction) -> Void)?

    var body: some View {
        HStack() {
            Spacer()
            HStack(spacing: -10) {
                // Select Button
                Button(action: {}) {
                    Image("controller-buttons-menu")
                        .resizable()
                        .frame(width: 36, height: 40)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged({ _ in
                            onButtonPress?(.select)
                            HapticManager.shared.buttonPress()
                            consoleManager.handleControllerAction(.select, pressed: true)
                        })
                        .onEnded({ _ in
                            HapticManager.shared.buttonRelease()
                            consoleManager.handleControllerAction(.select, pressed: false)
                        })
                )

                Image("controller-select")
                    .resizable()
                    .frame(width: 32, height: 35)
                    .padding(.top, 10)
                    .padding(.leading, -5)

                // Start Button
                Button(action: {}) {
                    Image("controller-buttons-menu")
                        .resizable()
                        .frame(width: 36, height: 40)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged({ _ in
                            onButtonPress?(.start)
                            HapticManager.shared.buttonPress()
                            consoleManager.handleControllerAction(.start, pressed: true)
                        })
                        .onEnded({ _ in
                            HapticManager.shared.buttonRelease()
                            consoleManager.handleControllerAction(.start, pressed: false)
                        })
                )

                Image("controller-start")
                    .resizable()
                    .frame(width: 29, height: 33)
                    .padding(.top, 10)
                    .padding(.leading, -5)
                    .background(Color.clear)
            }
            Spacer()
        }
    }
}

