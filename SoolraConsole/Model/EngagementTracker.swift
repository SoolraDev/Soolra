import Foundation
import FirebaseAnalytics
import UIKit

class EngagementTracker: ObservableObject {
    private var timer: Timer?
    private var currentRom: String = "none"
    private var privyId: String = "none"
    private var lastInGameTime: Double = 0  // Track when we last checkpointed game time (in ms)
    
    init() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - App lifecycle hooks
    
    @objc private func appDidBecomeActive() {
        
        // Resume heartbeats
        startTracking()
        
        // Reset game timer when app becomes active (if in a game)
        if currentRom != "none" {
            lastInGameTime = Date().timeIntervalSince1970 * 1000
        }
    }
    
    @objc private func appDidEnterBackground() {
        
        // Save any elapsed time if in a game
        if currentRom != "none" {
            addElapsedGameTime()
        }
        
        // Stop heartbeats
        stopTracking()
    }

    // MARK: - Public API
    
    func startTracking() {
        stopTracking()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.onHeartbeat()
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Heartbeat Handler
    
    private func onHeartbeat() {
        
        // If user is playing a game, checkpoint the elapsed time
        if currentRom != "none" {
            addElapsedGameTime()
            // Reset checkpoint
            lastInGameTime = Date().timeIntervalSince1970 * 1000
        }
        
        // Get current total (as integer, no decimals)
        let totalMs = Int(UserDefaults.standard.double(forKey: gametimeKey()))
        
        print("📊 Sending session_heartbeat - total_gametime_ms: \(totalMs)")
        
        // Send heartbeat event with total gametime
        Analytics.logEvent("session_heartbeat", parameters: [
            "privy_id": self.privyId,
            "current_rom": self.currentRom,
            "total_gametime_ms": totalMs,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func setCurrentRom(_ rom: String) {
        
        // Ending a game session
        if rom == "none" {
            
            // Add elapsed time since last checkpoint
            addElapsedGameTime()
            
            let totalMs = Int(UserDefaults.standard.double(forKey: gametimeKey()))
            
            
            Analytics.logEvent("game_ended", parameters: [
                "privy_id": self.privyId,
                "current_rom": self.currentRom,
                "total_gametime_ms": totalMs,
                "timestamp": Date().timeIntervalSince1970
            ])
            
            currentRom = "none"
            lastInGameTime = 0
            return
        }
        
        // Starting / switching to a game
        currentRom = rom
        lastInGameTime = Date().timeIntervalSince1970 * 1000
        
        let totalMs = Int(UserDefaults.standard.double(forKey: gametimeKey()))
        
        
        Analytics.logEvent("game_started", parameters: [
            "privy_id": self.privyId,
            "current_rom": rom,
            "total_gametime_ms": totalMs,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Add elapsed game time since last checkpoint
    
    private func addElapsedGameTime() {
        guard lastInGameTime > 0 else {
            return
        }
        
        let nowMs = Date().timeIntervalSince1970 * 1000
        let elapsedMs = nowMs - lastInGameTime
        let existingMs = UserDefaults.standard.double(forKey: gametimeKey())
        let updatedTotalMs = existingMs + elapsedMs
        
        UserDefaults.standard.set(updatedTotalMs, forKey: gametimeKey())
        
        print("⏱️ Added elapsed time: \(Int(elapsedMs)) ms (from \(Int(lastInGameTime)) to \(Int(nowMs)))")
        print("📦 Total for \(privyId): \(Int(existingMs)) ms → \(Int(updatedTotalMs)) ms")
    }
    
    // MARK: - Privy ID
    
    func setPrivyId(_ id: String?) {
        self.privyId = id ?? "none"
    
        
        let totalMs = UserDefaults.standard.double(forKey: gametimeKey())
        print("⏱️ Loaded total game time for \(privyId): \(Int(totalMs)) ms")
    }
    
    // MARK: - Keys for cached data
    
    private func gametimeKey() -> String {
        "total_gametime_\(privyId)"
    }
}
