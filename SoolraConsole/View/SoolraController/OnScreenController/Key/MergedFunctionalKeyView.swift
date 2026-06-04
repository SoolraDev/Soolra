//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct MergedFunctionalKeyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @ObservedObject var controllerViewModel: ControllerViewModel
    @State private var isSelectPressed = false
    @State private var isStartPressed = false
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
                            if !isSelectPressed {
                                isSelectPressed = true
                                onButtonPress?(.select)
                                HapticManager.shared.buttonPress()
                                // Route through controllerViewModel so the same path
                                // reaches both native cores (GameView) and web games
                                // (HomeView → web → BluetoothControllerService delegate).
                                controllerViewModel.controllerDidPress(action: .select, pressed: true)
                            }
                        })
                        .onEnded({ _ in
                            isSelectPressed = false
                            HapticManager.shared.buttonRelease()
                            controllerViewModel.controllerDidPress(action: .select, pressed: false)
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
                            if !isStartPressed {
                                isStartPressed = true
                                onButtonPress?(.start)
                                HapticManager.shared.buttonPress()
                                controllerViewModel.controllerDidPress(action: .start, pressed: true)
                            }
                        })
                        .onEnded({ _ in
                            isStartPressed = false
                            HapticManager.shared.buttonRelease()
                            controllerViewModel.controllerDidPress(action: .start, pressed: false)
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

