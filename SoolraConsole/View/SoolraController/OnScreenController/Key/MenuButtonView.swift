//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct MenuButtonView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeManager: ThemeManager
    let pauseViewModel: PauseGameViewModel?

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonPress()
            DispatchQueue.main.async {
                    print("togglePause() called on main thread")
                guard let pauseViewModel = pauseViewModel else {
                       print("pauseViewModel is nil!")
                       return
                   }
                pauseViewModel.togglePause();
                }
            
            
            
            HapticManager.shared.buttonRelease()
        }) {
            ZStack {
                Capsule()
                    .frame(width: 72, height: 29)
                    .foregroundColor(themeManager.keyBackgroundColor)
                   
                    .overlay(
                        Capsule()
                            .stroke(themeManager.keyBorderColor.opacity(0.8), lineWidth: 2) // Border color
                            .shadow(color: themeManager.keyShadowColor, radius: 4, x: 0, y: 2) // Shadow color
                    )
                
                Text("Menu")
                    .foregroundColor(themeManager.whitetextColor)
                    .font(.custom("Orbitron-Black", size: 11))  // Custom font
                    .fontWeight(.bold).opacity(0.7)
                    
            }
            //.rotationEffect(.degrees(-45))
        }
    }
}

