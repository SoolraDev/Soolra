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
    
    // Milestone definitions
    private let hourMilestones: [Int: Int] = [
        1: 100,
        2: 200,
        3: 300,
        4: 400,
        5: 500,
        6: 600,
        7: 700,
        8: 800,
        9: 900,
        10: 1000,
        24: 3000
    ]
    
    private let gamesMilestones: [Int: Int] = [
        3: 500,
        5: 750,
        10: 1000
    ]
    
    // Track which milestones have been awarded (store the milestone values, e.g., [1, 2, 3] for hours)
    private var completedHourMilestones: Set<Int> = []
    private var completedGamesMilestones: Set<Int> = []

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
        
        // Load milestone tracking from UserDefaults
        loadMilestoneTracking()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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

    
    func trackButtonPress(action: SoolraControllerAction) {
        switch action {
        case .a, .b, .x, .y, .up, .down, .left, .right, .l, .r:
            buttonPressPerSliceCounter+=1
            print("buttonPressPerSliceCounter is: \(buttonPressPerSliceCounter)")
        default:
            break
        }
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
        loadMilestoneTracking() // Reload milestones for the new user
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
        
        // Ignore tiny fragments that are likely noise.
        guard duration >= 1.0 else { return }
        
        let hadEnoughButtonPresses = timeSliceHadEnoughButtonPresses()
        var score = Int(round(hadEnoughButtonPresses ? currentRomScoreModifier : 0))
        
        // Track distinct game if session qualifies (>=15s with enough button presses)
        if duration >= 15.0 && hadEnoughButtonPresses {
            addDistinctGamePlayed(romName)
        }
        
        // Calculate milestone bonus points
        let bonusPoints = calcSessionPointEarningEvents(sessionDuration: duration)
        score = score + bonusPoints
        
        print("currentRomScoreModifier is: \(currentRomScoreModifier)")
            
        let timeSlice = GameSessionRecord(
            id: UUID(),
            gameName: romName,
            duration: duration,
            score: score,
            recordedAt: now
        )

        print("💾 Saving time slice for \(romName). Duration: \(Int(duration))s. Score: \(score). Bonus: \(bonusPoints).")
        saveSessionLocally(timeSlice)

        // IMPORTANT: Reset the anchor time to now for the next slice.
        self.lastHeartbeatTime = now
        self.buttonPressPerSliceCounter = 0
        
        // After saving, trigger an upload attempt.
        Task {
            await uploadPendingSessions()
        }
    }

    private func calcSessionPointEarningEvents(sessionDuration: TimeInterval) -> Int {
        var bonusPoints = 0
        
        // Get baseline from server sync
        let serverTotalSeconds = UserDefaults.standard.double(forKey: totalPlayTimeKey())
        
        // Calculate current total time (server baseline + all local pending sessions)
        let localSessions = getPendingSessions()
        let localAccumulatedTime = localSessions.reduce(0.0) { $0 + $1.duration }
        let currentTotalSeconds = serverTotalSeconds + localAccumulatedTime + sessionDuration
        
        // Calculate hours
        let currentTotalHours = Int(currentTotalSeconds / 3600)
        
        // Check for new hour milestones
        for (hourMilestone, points) in hourMilestones {
            if currentTotalHours >= hourMilestone && !completedHourMilestones.contains(hourMilestone) {
                bonusPoints += points
                completedHourMilestones.insert(hourMilestone)
                print("🎉 Hour milestone reached! \(hourMilestone) hours completed, awarded \(points) points")
            }
        }
        
        // Calculate games milestones
        let currentGamesCount = getDistinctGamesPlayed().count
        
        // Check for new games milestones
        for (gamesMilestone, points) in gamesMilestones {
            if currentGamesCount >= gamesMilestone && !completedGamesMilestones.contains(gamesMilestone) {
                bonusPoints += points
                completedGamesMilestones.insert(gamesMilestone)
                print("🎉 Games milestone reached! \(gamesMilestone) distinct games played, awarded \(points) points")
            }
        }
        
        // Save the updated milestone tracking
        if bonusPoints > 0 {
            saveMilestoneTracking()
        }
        
        return bonusPoints
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

        let remoteTotalSeconds = TimeInterval(remoteMetrics.totalTimePlayed / 1000)
        let remoteTotalPoints = remoteMetrics.points
        
        UserDefaults.standard.set(
            remoteTotalSeconds,
            forKey: totalPlayTimeKey()
        )
        UserDefaults.standard.set(
            remoteTotalPoints,
            forKey: totalPointsKey()
        )
        
        // Recalculate which hour milestones should already be completed based on server data
        let serverTotalHours = Int(remoteTotalSeconds / 3600)
        for (hourMilestone, _) in hourMilestones {
            if serverTotalHours >= hourMilestone {
                completedHourMilestones.insert(hourMilestone)
            }
        }
        
        // TODO: When server provides distinct games count, sync it here
        // let remoteGamesCount = remoteMetrics.distinctGamesPlayed
        // for (gamesMilestone, _) in gamesMilestones {
        //     if remoteGamesCount >= gamesMilestone {
        //         completedGamesMilestones.insert(gamesMilestone)
        //     }
        // }
        
        saveMilestoneTracking()
        
        print("✅ Synced from backend, total playtime: \(Int(remoteTotalSeconds))s, total points: \(remoteTotalPoints)")

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

    // MARK: - Distinct Games Tracking
    
    private func addDistinctGamePlayed(_ gameName: String) {
        var games = getDistinctGamesPlayed()
        let previousCount = games.count
        games.insert(gameName)
        
        if games.count > previousCount {
            saveDistinctGamesPlayed(games)
            print("🎮 New distinct game tracked: \(gameName). Total: \(games.count)")
        }
    }
    
    private func getDistinctGamesPlayed() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: distinctGamesPlayedKey()),
              let games = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return Set<String>()
        }
        return games
    }
    
    private func saveDistinctGamesPlayed(_ games: Set<String>) {
        if let data = try? JSONEncoder().encode(games) {
            UserDefaults.standard.set(data, forKey: distinctGamesPlayedKey())
        }
    }
    
    // MARK: - Milestone Tracking Persistence
    
    private func loadMilestoneTracking() {
        // Load completed hour milestones
        if let data = UserDefaults.standard.data(forKey: completedHourMilestonesKey()),
           let milestones = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            completedHourMilestones = milestones
        } else {
            completedHourMilestones = []
        }
        
        // Load completed games milestones
        if let data = UserDefaults.standard.data(forKey: completedGamesMilestonesKey()),
           let milestones = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            completedGamesMilestones = milestones
        } else {
            completedGamesMilestones = []
        }
        
        print("📊 Loaded milestones - Hours: \(completedHourMilestones.sorted()), Games: \(completedGamesMilestones.sorted())")
    }
    
    private func saveMilestoneTracking() {
        // Save completed hour milestones
        if let data = try? JSONEncoder().encode(completedHourMilestones) {
            UserDefaults.standard.set(data, forKey: completedHourMilestonesKey())
        }
        
        // Save completed games milestones
        if let data = try? JSONEncoder().encode(completedGamesMilestones) {
            UserDefaults.standard.set(data, forKey: completedGamesMilestonesKey())
        }
    }

    // MARK: - UserDefaults Persistence

    private func pendingSessionsKey() -> String {
        "pending_sessions_\(privyId ?? "guest")"
    }
    private func totalPlayTimeKey() -> String {
        "total_play_time_\(privyId ?? "guest")"
    }
    private func totalPointsKey() -> String {
        "total_points_\(privyId ?? "guest")"
    }
    private func distinctGamesPlayedKey() -> String {
        "distinct_games_played_\(privyId ?? "guest")"
    }
    private func completedHourMilestonesKey() -> String {
        "completed_hour_milestones_\(privyId ?? "guest")"
    }
    private func completedGamesMilestonesKey() -> String {
        "completed_games_milestones_\(privyId ?? "guest")"
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
