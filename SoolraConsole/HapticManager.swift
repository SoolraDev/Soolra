//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func buttonPress() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func buttonRelease() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
} 
