import FirebaseAnalytics
import Foundation
import UIKit

@MainActor
let globalEngagementTracker = EngagementTracker.shared

class EngagementTracker: ObservableObject {
    static let shared = EngagementTracker()

    private let apiClient = ApiClient()
    private var privyId: String?

    // Timer for the heartbeat mechanism
    private var heartbeatTimer: Timer?

    // Properties for tracking the *active* game session
    private var currentRomName: String?
    private var sessionStartTime: Date?
    private var lastHeartbeatTime: Date?  // Tracks the start of the last time slice
    
    // Time slice scoring
    private var currentRomScoreModifier: Float = 1.0;
    private var buttonPressPerSliceCounter: Int = 0;
    private var buttonsRequiredToScoreSlice: Int = 5;

    // Make init private for singleton pattern
    private init() {
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

    // ... (rest of the EngagementTracker code is unchanged)

    // MARK: - App Lifecycle & Tracking Control

    @objc private func appDidBecomeActive() {
        // When the app is active, start the heartbeat timer and upload any pending sessions.
        startTracking()
        Task {
            await uploadPendingSessions()
        }
    }

    @objc private func appDidEnterBackground() {
        // When backgrounding, save any final in-progress time and stop the timer.
        saveCurrentTimeSlice()
        stopTracking()
    }

    
    func trackButtonPress(){
        buttonPressPerSliceCounter+=1
        print("buttonPressPerSliceCounter is: \(buttonPressPerSliceCounter)")
    }
    
    func timeSliceHadEnoughButtonPresses() -> Bool{
        print("buttonPressPerSliceCounter is: \(buttonPressPerSliceCounter)")
        print("buttonsRequiredToScoreSlice is: \(buttonsRequiredToScoreSlice)")
        return buttonPressPerSliceCounter >= buttonsRequiredToScoreSlice
    }
    
    /// Starts the heartbeat timer. The HomeView can call this in onAppear.
    func startTracking() {
        // Ensure we don't have multiple timers running.
        stopTracking()

        // The timer will call onHeartbeat every 30 seconds.
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            self?.onHeartbeat()
        }
        print("❤️ Tracking started.")
    }

    /// Stops the heartbeat timer.
    func stopTracking() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("🚫 Tracking stopped.")
    }

    // MARK: - Public API

    func setPrivyId(_ id: String?) {
        guard let id = id, !id.isEmpty else {
            self.privyId = nil
            // Clear any pending sessions for the logged-out user if needed
            return
        }
        self.privyId = id
        Task { await syncWithBackend() }
    }

    /// Call this when a game starts or the user navigates away.
    /// Pass the name of the game to start, or `nil`/`"none"` to end the current session.
    func setCurrentRom(_ romName: String?, romScoreModifier: Float) {
        // Finalize and save any existing game session before starting a new one.
        saveCurrentTimeSlice()

        Analytics.logEvent(
            "game_started",
            parameters: [
                "current_rom": romName ?? "unknown",
                "timestamp": Date().timeIntervalSince1970,
            ]
        )

        guard let romName = romName, romName != "none", !romName.isEmpty else {
            // If the new name is nil or "none", we just end the session.
            currentRomName = nil
            currentRomScoreModifier = 1.0
            lastHeartbeatTime = nil
            return
        }

        // Start a new game session.
        self.currentRomName = romName
        self.currentRomScoreModifier = romScoreModifier
        // The lastHeartbeatTime is the anchor for our next time slice.
        self.lastHeartbeatTime = Date()
        print("🎮 Game started: \(romName)")
    }

    // MARK: - Core Logic

    /// The heartbeat function, called by the timer.
    @objc private func onHeartbeat() {
        print("❤️ Heartbeat fired.")
        // The heartbeat's job is to save the current slice of time.
        saveCurrentTimeSlice()
    }

    /// Calculates the time since the last heartbeat, saves it as a record, and resets the timer anchor.
    private func saveCurrentTimeSlice() {
        // Ensure a game is actually running.
        guard let romName = currentRomName, let startTime = lastHeartbeatTime
        else {
            return
        }

        // Upload Firebase analytics
        Analytics.logEvent(
            "session_heartbeat",
            parameters: [
                "current_rom": romName,
                "timestamp": Date().timeIntervalSince1970,
            ]
        )

        let now = Date()
        let duration = now.timeIntervalSince(startTime)
        
        let score = Int(round(timeSliceHadEnoughButtonPresses() ? currentRomScoreModifier : 0))
        print("currentRomScoreModifier is: \(currentRomScoreModifier)")
        // Ignore tiny fragments that are likely noise.
        guard duration >= 1.0 else { return }
            
        let timeSlice = GameSessionRecord(
            id: UUID(),
            gameName: romName,
            duration: duration,
            score: score,  // Score can be added later if needed
            recordedAt: now
        )

        print("💾 Saving time slice for \(romName). Duration: \(Int(duration))s. Score: \(score).")
        saveSessionLocally(timeSlice)

        // IMPORTANT: Reset the anchor time to now for the next slice.
        self.lastHeartbeatTime = now
        self.buttonPressPerSliceCounter = 0
        
        // After saving, trigger an upload attempt.
        Task {
            await uploadPendingSessions()
        }
    }

    private func syncWithBackend() async {
        guard let userId = privyId else { return }
        print("🔄 Syncing with backend for user \(userId)...")

        guard
            let remoteMetrics = await apiClient.fetchUserMetrics(userId: userId)
        else {
            print("Could not sync metrics from server.")
            return
        }

        let remoteTotalSeconds = TimeInterval(
            remoteMetrics.totalTimePlayed / 1000
        )
        UserDefaults.standard.set(
            remoteTotalSeconds,
            forKey: totalPlayTimeKey()
        )
        print(
            "✅ Synced total playtime from backend: \(Int(remoteTotalSeconds))s"
        )

        await uploadPendingSessions()
    }

    private func uploadPendingSessions() async {
        guard let userId = privyId, !getPendingSessions().isEmpty else {
            return
        }

        var pending = getPendingSessions()
        print("📤 Found \(pending.count) session(s) to upload.")

        for session in pending {
            let success = await apiClient.postGameSession(
                session,
                userId: userId
            )
            if success {
                removeLocalSession(withId: session.id)
            } else {
                print(
                    "🛑 Upload failed for session \(session.id). Will retry later."
                )
                break
            }
        }
    }

    // MARK: - UserDefaults Persistence (Unchanged)

    private func pendingSessionsKey() -> String {
        "pending_sessions_\(privyId ?? "guest")"
    }
    private func totalPlayTimeKey() -> String {
        "total_play_time_\(privyId ?? "guest")"
    }

    private func saveSessionLocally(_ session: GameSessionRecord) {
        var pending = getPendingSessions()
        pending.append(session)
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingSessionsKey())
        }
    }

    private func getPendingSessions() -> [GameSessionRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: pendingSessionsKey()),
            let sessions = try? JSONDecoder().decode(
                [GameSessionRecord].self,
                from: data
            )
        else {
            return []
        }
        return sessions
    }

    private func removeLocalSession(withId sessionId: UUID) {
        var pending = getPendingSessions()
        pending.removeAll { $0.id == sessionId }
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingSessionsKey())
        }
    }
}
