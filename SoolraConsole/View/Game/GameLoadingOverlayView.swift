//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct GameLoadingOverlayView: View {
    let message: String
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isAnimating = false
    
    private var spinnerColor: Color {
        themeManager.keyShadowColor == .black ? .white : themeManager.keyShadowColor
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            themeManager.keyBorderColor.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Loading spinner
                ZStack {
                    // Outer circle
                    Circle()
                        .stroke(lineWidth: 4)
                        .foregroundColor(spinnerColor.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    // Animated arc
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(spinnerColor, lineWidth: 4)
                        .frame(width: 50, height: 50)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                }
                .onAppear {
                    isAnimating = true
                }
                
                // Loading message
                Text(message)
                    .font(.custom("Orbitron-Regular", size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 300)
                
                // Progress dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .opacity(isAnimating ? 1 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(0.2 * Double(index)),
                                value: isAnimating
                            )
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.6))
                    .shadow(color: themeManager.keyShadowColor.opacity(0.5), radius: 10)
            )
            .padding(.bottom, 400)
        }
    }
}
