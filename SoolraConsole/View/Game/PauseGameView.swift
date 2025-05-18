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
                    destination: CheatCodesView(
                        consoleManager: pauseViewModel.consoleManager!
                    )
                    .environmentObject(pauseViewModel.consoleManager!),
                    isActive: $pauseViewModel.showCheatCodesView
                ) {
                    EmptyView()
                }
                NavigationLink(
                    destination: SaveStateView(consoleManager: pauseViewModel.consoleManager!,
                                               pauseViewModel: pauseViewModel,
                                               mode: .saving)
                    .environmentObject(themeManager),
                    isActive: $pauseViewModel.showSaveStateView
                ) {
                    EmptyView()
                }
                
                NavigationLink(
                    destination: SaveStateView(consoleManager: pauseViewModel.consoleManager!,
                                               pauseViewModel: pauseViewModel,
                                               mode: .loading)
                    .environmentObject(themeManager),
                    isActive: $pauseViewModel.showLoadStateView
                ) {
                    EmptyView()
                }
                
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}



// Background overlay view
private struct PauseBackgroundView: View {
    var body: some View {
        Color.black.opacity(0.7)
            .edgesIgnoringSafeArea(.all)
    }
}

private struct PauseMenuContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var pauseViewModel: PauseGameViewModel

    var body: some View {
        VStack {
            Spacer() // Push to center vertically
            
            VStack(spacing: 24) {
                Text("Paused")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ForEach(Array(pauseViewModel.menuItems.enumerated()), id: \.element.id) { index, item in
                    let isSelected = pauseViewModel.selectedMenuIndex == index
                    let iconName = icon(for: item)

                    Button(action: { handleMenuAction(index) }) {
                        HStack {
                            if let iconName {
                                Image(systemName: iconName)
                                    .foregroundColor(.white)
                            }
                            Text(item.title)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSelected ? themeManager.keyBackgroundColor.opacity(0.7) : Color.white.opacity(0.1))
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(isSelected ? 0.8 : 0.3), lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: 500)

            Spacer() // Push to center vertically
        }
        .frame(maxHeight: .infinity) // Ensure full height
    }

    private func icon(for item: PauseMenuItem) -> String? {
        switch item {
        case .resume: return "play.circle.fill"
        case .exit: return "xmark.circle.fill"
        case .cheatCodes: return "wand.and.stars"
        case .fastForward(let enabled): return enabled ? "forward.fill" : "forward"
        case .saveState: return "square.and.arrow.down"
        case .loadState: return "square.and.arrow.up"
        }
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



private struct PauseGameContentView: View {
    let geometry: GeometryProxy
    let pauseViewModel: PauseGameViewModel
    let themeManager: ThemeManager

    var body: some View {
        ZStack {
            PauseBackgroundView()

            VStack {
                PauseMenuContent(pauseViewModel: pauseViewModel)
                    .environmentObject(themeManager)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 500)
                    .frame(height: geometry.size.height * 0.45) // Confine to top half
                    .padding(.top, 20) // Slight breathing room from top

                Spacer()
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
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
                                .stroke(
                                    isSelected ? Color.white : themeManager.keyBorderColor
                                        .opacity(0.8),
                                    lineWidth: isSelected ? 3 : 2
                                )
                                .shadow(
                                    color: themeManager.keyShadowColor,
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                        )
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}
