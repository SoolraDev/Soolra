//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct SoolraControllerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @ObservedObject var controllerViewModel: ControllerViewModel 
    @Binding var currentView: CurrentView
    var pauseViewModel: PauseGameViewModel?
    var onButtonPress: ((SoolraControllerAction) -> Void)?
    var onButton: ((SoolraControllerAction, Bool) -> Void)? = nil

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .environmentObject(themeManager)
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .top) {
                    ArrowsView(
                        controllerViewModel: controllerViewModel,
                        onButton: { action, pressed in
                            onButton?(action, pressed)
                    })
                        .padding(.leading, 35)
                        .environmentObject(consoleManager)
                    if let pauseViewModel = pauseViewModel {
                        // if we are in game, load the MenuButton with pauseViewModel
                        MenuButtonView(pauseViewModel: pauseViewModel, onButton: onButton)
                            .offset(y: -15)
                            .environmentObject(consoleManager)
                    } else {
                        // if we are not in game
                        MenuButtonView(pauseViewModel: nil, onButton: onButton)
                            .offset(y: -15)
                            .environmentObject(consoleManager)
                    }
                    RhombusButtonView(
                        controllerViewModel: controllerViewModel,
                        onButton: { action, pressed in
                            onButton?(action, pressed)
                        }
                    )
                    .padding(.trailing, 35)
                    .environmentObject(consoleManager)

                }
                MergedFunctionalKeyView(onButtonPress: onButtonPress)
                    .environmentObject(consoleManager)
                ShoulderButtonView(
                    controllerViewModel: controllerViewModel,
                    onButton: { action, pressed in
                    onButton?(action, pressed)
                })
                    .environmentObject(consoleManager)
                HStack {
                    JoystickView(onButtonPress: onButtonPress)
                        .zIndex(1)
                        .environmentObject(consoleManager)
                    Spacer()
                    Image("controller-sound")
                        .resizable()
                        .frame(width: 60, height: 40)
                        .zIndex(0)
                        .padding(.top, 60)
                    Spacer()
                    JoystickView(onButtonPress: onButtonPress)
                        .zIndex(1)
                        .environmentObject(consoleManager)
                }
                .padding(.horizontal, 30)
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    struct GradientBackgroundView: View {
        @EnvironmentObject var themeManager: ThemeManager
        
        var body: some View {
            LinearGradient(
                gradient: Gradient(stops: themeManager.keyboardColor.gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .border(Color.clear)
            .clipped()
            .opacity(1)
        }
    }
}

