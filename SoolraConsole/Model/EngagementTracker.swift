//
//  EngagementTracker.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 17/05/2025.
//

import Foundation
import FirebaseAnalytics

class EngagementTracker: ObservableObject {
    private var timer: Timer?
    private var currentRom: String = "none"

    func startTracking() {
        stopTracking() // stop any previous timer

        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Analytics.logEvent("session_heartbeat", parameters: [
                "current_rom": self.currentRom,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    func setCurrentRom(_ rom: String) {
        self.currentRom = rom
    }
}
