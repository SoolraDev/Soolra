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
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark) // ← Pause menu always dark

        // ——— Cheat Codes (modal) ———
        .fullScreenCover(isPresented: $pauseViewModel.showCheatCodesView) {
            NavigationView {
                CheatCodesView(consoleManager: pauseViewModel.consoleManager!)
                    .environmentObject(pauseViewModel.consoleManager!)
                    .environmentObject(themeManager)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }

        // ——— Save State (modal) ———
        .fullScreenCover(isPresented: $pauseViewModel.showSaveStateView) {
            NavigationView {
                SaveStateView(
                    consoleManager: pauseViewModel.consoleManager!,
                    pauseViewModel: pauseViewModel,
                    mode: .saving
                )
                .environmentObject(themeManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }

        // ——— Load State (modal) ———
        .fullScreenCover(isPresented: $pauseViewModel.showLoadStateView) {
            NavigationView {
                SaveStateView(
                    consoleManager: pauseViewModel.consoleManager!,
                    pauseViewModel: pauseViewModel,
                    mode: .loading
                )
                .environmentObject(themeManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
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

private struct PauseMenuContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var pauseViewModel: PauseGameViewModel

    private let columns: [GridItem] = [
        GridItem(.flexible(minimum: 0), spacing: 16, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 16, alignment: .top)
    ]


    var body: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(pauseViewModel.menuItems.enumerated()), id: \.element.id) { index, item in
                    let isSelected = pauseViewModel.selectedMenuIndex == index
                    let iconName = icon(for: item)
                    let fgColor = item.isExit
                        ? Color(red: 209/255, green: 31/255, blue: 38/255)
                        : themeManager.whitetextColor
                    VStack {
                        Button(action: { handleMenuAction(index) }) {
                            VStack(spacing: 6) {
                                if let iconName {
                                    Image(systemName: iconName)
                                        .font(.system(size: 31))
                                        .foregroundColor(.white)

                                }

                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(fgColor)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1) // 👈 Enforce single-line layout
                                    .minimumScaleFactor(0.6) // 👈 Shrink font if needed
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // 👈 Fill full available space
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? themeManager.keyBackgroundColor.opacity(0.7) : Color.white.opacity(0.1))
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(isSelected ? 0.8 : 0.3), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .frame(height: 80) // 👈 FIXED button height
                        .frame(maxWidth: .infinity)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                    }
                    .frame(maxWidth: .infinity)

                }
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
                    .padding(.top, 10) // Slight breathing room from top

                Spacer()
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .preferredColorScheme(.dark)
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
