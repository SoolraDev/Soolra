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
        GeometryReader { geometry in
            PauseGameContentView(
                geometry: geometry,
                pauseViewModel: pauseViewModel,
                themeManager: themeManager
            )
        }
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
            
            ForEach(Array(pauseViewModel.menuItems.enumerated()), id: \.offset) { index, title in
                Button(action: { handleMenuAction(index) }) {
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
                                        .stroke(pauseViewModel.selectedMenuIndex == index ? Color.white : themeManager.keyBorderColor.opacity(0.8), 
                                               lineWidth: pauseViewModel.selectedMenuIndex == index ? 3 : 2)
                                        .shadow(color: themeManager.keyShadowColor, radius: 4, x: 0, y: 2)
                                )
                        )
                        .scaleEffect(pauseViewModel.selectedMenuIndex == index ? 1.05 : 1.0)
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
        switch index {
        case 0: // Resume
            pauseViewModel.togglePause()
        case 1: // Exit Game
            pauseViewModel.initiateExit()
        default:
            break
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


