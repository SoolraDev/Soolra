//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//



import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("keyboardColor") var keyboardColor: KeyboardColor = .gray
    
    enum KeyboardColor: String, CaseIterable {
        case gray, black, pink, lightBlue
        
        var color: Color {
            switch self {
            case .gray: return Color.gray
            case .black: return Color.black
            case .pink: return Color(red: 216/255, green: 154/255, blue: 187/255)
            case .lightBlue: return Color(red: 135/255, green: 206/255, blue: 235/255)
            }
        }
        
        var joystickGradientColors: [Gradient.Stop] {
            switch self {
            case .gray:
                return [
                    .init(color: Color(red: 130/255, green: 130/255, blue: 130/255), location: 0.0),
                    .init(color: Color(red: 197/255, green: 195/255, blue: 195/255), location: 1.0)
                ]
            case .black:
                return [
                    .init(color: Color(red: 60/255, green: 60/255, blue: 60/255), location: 0.0),
                    .init(color: Color(red: 100/255, green: 100/255, blue: 100/255), location: 1.0)
                ]
            case .pink:
                return [
                    .init(color: Color(red: 216/255, green: 154/255, blue: 187/255), location: 0.0),
                    .init(color: Color(red: 226/255, green: 164/255, blue: 197/255), location: 1.0)
                ]
            case .lightBlue:
                return [
                    .init(color: Color(red: 135/255, green: 206/255, blue: 235/255), location: 0.0),
                    .init(color: Color(red: 176/255, green: 224/255, blue: 230/255), location: 1.0)
                ]
            }
        }
        
        var gradientColors: [Gradient.Stop] {
            switch self {
            case .gray:
                return [
                    .init(color: Color(red: 175/255, green: 173/255, blue: 173/255), location: 0.00),
                    .init(color: Color(red: 195/255, green: 191/255, blue: 191/255), location: 0.07),
                    .init(color: Color(red: 179/255, green: 176/255, blue: 176/255), location: 0.68),
                    .init(color: Color(red: 146/255, green: 146/255, blue: 146/255), location: 1.0)
                ]
            case .black:
                return [
                    .init(color: Color(red: 70/255, green: 70/255, blue: 70/255), location: 0.00),
                    .init(color: Color(red: 90/255, green: 90/255, blue: 90/255), location: 0.07),
                    .init(color: Color(red: 60/255, green: 60/255, blue: 60/255), location: 0.68),
                    .init(color: Color(red: 40/255, green: 40/255, blue: 40/255), location: 1.0)
                ]
            case .pink:
                return [
                    .init(color: Color(red: 226/255, green: 164/255, blue: 197/255), location: 0.00),
                    .init(color: Color(red: 231/255, green: 169/255, blue: 202/255), location: 0.07),
                    .init(color: Color(red: 216/255, green: 154/255, blue: 187/255), location: 0.68),
                    .init(color: Color(red: 206/255, green: 144/255, blue: 177/255), location: 1.0)
                ]
            case .lightBlue:
                return [
                    .init(color: Color(red: 176/255, green: 224/255, blue: 230/255), location: 0.00),
                    .init(color: Color(red: 186/255, green: 234/255, blue: 240/255), location: 0.07),
                    .init(color: Color(red: 135/255, green: 206/255, blue: 235/255), location: 0.68),
                    .init(color: Color(red: 115/255, green: 186/255, blue: 215/255), location: 1.0)
                ]
            }
        }
    }

    // Define colors for light and dark modes
    var backgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }
    
    
    var whitetextColor: Color {
        isDarkMode ? Color.white : Color.white
    }
    var textColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var keyForegroundColor: Color {
        isDarkMode ? Color.white : Color.white
    }
    
    var keyBackgroundColor: Color {
        keyboardColor.color.opacity(0.6)
    }
    
    var keyBorderColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var keyShadowColor: Color {
        keyboardColor.color.opacity(0.7)
    }
    
    
    // Define colors for light and dark modes
        var joystickBackgroundColor: Color {
            isDarkMode ? Color.white : Color.black
        }
        
        var joystickForegroundColor: Color {
            isDarkMode ? Color.white : Color.black
        }
        
    
    // Function to toggle dark mode
    func toggleTheme() {
        isDarkMode.toggle()
    }
}
