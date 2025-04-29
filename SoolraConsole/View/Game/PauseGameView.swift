//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct PauseGameView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var pauseViewModel: PauseGameViewModel

    var body: some View {
        NavigationView {
            ZStack {
                GeometryReader { geometry in
                    PauseGameContentView(
                        geometry: geometry,
                        pauseViewModel: pauseViewModel,
                        themeManager: themeManager
                    )
                }

                // Hidden NavigationLinks
                NavigationLink(
                    destination: CheatCodesView(consoleManager: pauseViewModel.consoleManager!)
                    .environmentObject(pauseViewModel.consoleManager!),
                    isActive: $pauseViewModel.showCheatCodesView
                ) {
                    EmptyView()
                }
                NavigationLink(
                    destination: SaveStateView(consoleManager: pauseViewModel.consoleManager!, mode: .saving)
                        .environmentObject(SaveStateManager.shared),
                    isActive: $pauseViewModel.showSaveStateView
                ) {
                    EmptyView()
                }

                NavigationLink(
                    destination: SaveStateView(consoleManager: pauseViewModel.consoleManager!, mode: .loading)
                        .environmentObject(SaveStateManager.shared),
                    isActive: $pauseViewModel.showLoadStateView
                ) {
                    EmptyView()
                }

            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For iPhone-style navigation
    }
}



// Background overlay view
private struct PauseBackgroundView: View {
    var body: some View {
        Color.black.opacity(0.7)
            .edgesIgnoringSafeArea(.all)
    }
}

// Menu content view
private struct PauseMenuContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var pauseViewModel: PauseGameViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("PAUSED")
                .font(.custom("Orbitron-Black", size: 32))
                .foregroundColor(themeManager.whitetextColor)
                .padding(.bottom, 30)
            
            ForEach(Array(pauseViewModel.menuItems.enumerated()), id: \.element.id) { index, item in
                // 1️⃣ Compute once, outside of the view modifiers
                let fgColor = item.isExit
                    ? Color(red: 209/255, green: 31/255, blue: 38/255)
                    : themeManager.whitetextColor
                let isSelected = pauseViewModel.selectedMenuIndex == index

                Button(action: { handleMenuAction(index) }) {
                    Text(item.title)
                        .font(.custom("Orbitron-Bold", size: 18))
                        .foregroundColor(fgColor)                // 2️⃣ Apply here
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Capsule()
                                .fill(themeManager.keyBackgroundColor)
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected
                                                ? Color.white
                                                : themeManager.keyBorderColor.opacity(0.8),
                                                lineWidth: isSelected ? 3 : 2
                                        )
                                        .shadow(color: themeManager.keyShadowColor,
                                                radius: 4, x: 0, y: 2)
                                )
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                }
                .animation(.easeInOut(duration: 0.2), value: pauseViewModel.selectedMenuIndex)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppGray"))
                .shadow(radius: 10)
        )
        .padding(.horizontal, 40)
    }
    
    private func handleMenuAction(_ index: Int) {
        let item = pauseViewModel.menuItems[index]
        
        switch item {
        case .resume:
            pauseViewModel.togglePause()
        case .exit:
            pauseViewModel.initiateExit()
        case .cheatCodes:
            pauseViewModel.showCheatCodesView = true
        case .fastForward(_):
            pauseViewModel.isFastForwardEnabled.toggle()
            pauseViewModel.consoleManager?.toggleFastForward()
            pauseViewModel.menuItems[index] = .fastForward(pauseViewModel.isFastForwardEnabled)
        case .saveState:
            pauseViewModel.showSaveStateView = true
        case .loadState:
            pauseViewModel.showLoadStateView = true
        }
    }

}

// Main content view combining background and menu
private struct PauseGameContentView: View {
    let geometry: GeometryProxy
    let pauseViewModel: PauseGameViewModel
    let themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            PauseBackgroundView()
            
            PauseMenuContent(pauseViewModel: pauseViewModel)
                .environmentObject(themeManager)
                .position(
                    x: geometry.size.width / 2,
                    y: (geometry.size.height * 0.3) - 80
                )
        }
    }
}

// Menu button view
private struct MenuButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Orbitron-Bold", size: 18))
                .foregroundColor(themeManager.whitetextColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .fill(themeManager.keyBackgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.white : themeManager.keyBorderColor.opacity(0.8), lineWidth: isSelected ? 3 : 2)
                                .shadow(color: themeManager.keyShadowColor, radius: 4, x: 0, y: 2)
                        )
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}
