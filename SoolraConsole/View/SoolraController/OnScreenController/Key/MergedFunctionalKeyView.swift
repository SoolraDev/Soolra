import SwiftUI

struct MergedFunctionalKeyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    var onButtonPress: ((SoolraControllerAction) -> Void)?

    var body: some View {
        HStack {
            // 🔹 Left Shoulder Button
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

            // 🔹 Start/Select group
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

            // 🔹 Right Shoulder Button
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
