//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import Combine
import MetalKit
import AVFoundation


public enum ConsoleCoreManagerError: Error {
    case failedToLoadRom
    case invalidCoreType
    case rendererInitializationFailed
    case custom(String)
}

// Core Manager to handle different console types
public class ConsoleCoreManager: ObservableObject {
    public enum ConsoleType: String, CaseIterable {
        case nes
        case gba
        // Add more console types as needed
        
        var fileExtension: String {
            return self.rawValue
        }
        
        static var allFileExtensions: [String] {
            return Self.allCases.map { $0.fileExtension }
        }
        
        static func from(fileExtension: String) -> ConsoleType? {
            return Self.allCases.first { $0.fileExtension.lowercased() == fileExtension.lowercased() }
        }
    }
    
    // Add state management
     struct ManagerState {
        var isRendererInitialized = false
        var currentCoreType: ConsoleType?
        var isEmulationStarted = false
        var isShuttingDown = false
        var isPaused = false
    }
    
    @Published private(set) var currentFrame: ConsoleFrame?
    @Published private(set) var isRendererReady: Bool = false
    @Published var shouldShowPauseMenu = false
    @Published public private(set) var isGameRunning: Bool = false
    @Published var cheatCodesManager: CheatCodesManager?
    var maxFastForwardSpeed: Float = 1
    var currentFastForwardSpeed: Float = 1
    var gameName: String
    
    private var currentCore: (any ConsoleCore)?
    public var currentRenderer: (any ConsoleRenderer)?
    private var frameTimer: AnyCancellable?
    private var currentButtonStates: [SoolraControllerAction: Bool] = [:]
    private var sharedNESAudioMaker = NESAudioMaker()
    private lazy var sharedGBAAudioMaker: GBAAudioMaker = {
        print("🎮 Initializing GBA audio maker on demand")
        return GBAAudioMaker()
    }()
    
    // Use shared Metal resources
    private let metalManager: MetalManager
    
    // Input queue handling
    private let inputQueue = DispatchQueue(label: "com.soolra.inputQueue", qos: .userInteractive)
    private let inputLock = NSLock()
    private var pendingInputs: [(action: SoolraControllerAction, pressed: Bool)] = []
    private var inputProcessingTimer: Timer?
    
    // Add timestamp tracking for each button
    private var lastPressTime: [SoolraControllerAction: TimeInterval] = [:]
    private let keyRepeatThreshold: TimeInterval = 0.05  // 50ms threshold to prevent key repeat issues
    
    // Add state management properties
    private(set) var managerState = ManagerState()
    private var stateLock = os_unfair_lock()
    
    @Published private(set) var isLoading = false
    @Published private(set) var loadingMessage = ""
    
    public private(set) var audioSessionManager: AudioSessionManager?
    
    public var isAudioSessionActive: Bool {
        return audioSessionManager?.isAudioSessionActive == true
    }
    
    private func updateState(_ update: (inout ManagerState) -> Void) {
        os_unfair_lock_lock(&stateLock)
        defer { os_unfair_lock_unlock(&stateLock) }
        update(&managerState)
        
        // Update published state
        let newState = managerState
        Task { @MainActor in
            self.isRendererReady = newState.isRendererInitialized
        }
    }
    
    public init(metalManager: MetalManager, gameName: String) throws {
        self.metalManager = metalManager
        self.gameName = gameName
        self.currentFrame = nil
        self.currentCore = nil
        self.currentRenderer = nil
        self.frameTimer = nil
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewFrame(_:)),
            name: NSNotification.Name("NewFrameAvailable"),
            object: nil
        )
        
        startInputProcessing()
    }
    
    private func startInputProcessing() {
        // Process inputs every 1/60th of a second
        inputProcessingTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.processInputQueue()
        }
    }
    
    private func processInputQueue() {
        guard let core = currentCore else { return }
        
        inputLock.lock()
        let inputs = pendingInputs
        pendingInputs.removeAll()
        inputLock.unlock()
        
        // Process all pending inputs
        for (action, pressed) in inputs {
            if pressed {
                core.pressButton(action)
            } else {
                core.releaseButton(action)
            }
        }
    }
    
    @objc private func handleNewFrame(_ notification: Notification) {
        if let frame = notification.object as? ConsoleFrame {
            DispatchQueue.main.async {
                self.currentFrame = frame
            }
        }
    }


    public func loadConsole(type: ConsoleType, romPath: URL) async throws {
        print("🎮 Loading console type: \(type) with ROM: \(romPath.path)")
        
        await MainActor.run {
            self.isLoading = true
            self.loadingMessage = "Loading \(type.rawValue.uppercased()) game..."
            self.isGameRunning = false
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.loadingMessage = ""
            }
        }
        
        // Create appropriate core
        switch type {
        case .nes:
            let core = try NESCore(romPath: romPath)
            await MainActor.run {
                core.initializeAudio(audioMaker: sharedNESAudioMaker)
            }
            await MainActor.run {
                self.currentCore = core
                self.isGameRunning = true
            }
        case .gba:
            let core = try GBACore(romPath: romPath)
            await MainActor.run {
                core.initializeAudio(audioMaker: sharedGBAAudioMaker)
            }
            await MainActor.run {
                self.currentCore = core
                self.isGameRunning = true
            }
        }
        
        // Initialize on main thread
        await MainActor.run {
            updateState { state in
                state.currentCoreType = type
                state.isEmulationStarted = false
                state.isRendererInitialized = false // Reset renderer state
            }
        }
        
        // Power up the core before starting emulation
        currentCore?.powerUp()
        setMaxFastForwardSpeed(type: type)
        print("✅ Console loaded successfully")
    }
    
    public func shutdown() async {
        print("🛑 Starting shutdown sequence...")
        
        // Set shutdown state first to prevent new operations
        updateState { state in
            state.isShuttingDown = true
        }
        
        await MainActor.run {
            self.isGameRunning = false
        }
        
        // Clear renderer with timeout
        print("🎨 Preparing renderer for cleanup...")
        if let renderer = currentRenderer {
            try? await withTimeout(seconds: 0.5) {
                await renderer.prepareForCleanup()
            }
        }
        
        // Stop input processing first
        inputProcessingTimer?.invalidate()
        inputProcessingTimer = nil
        
        //  stop the emulation to prevent new frames
        currentCore?.shutdown()
        
        // Cancel frame timer to stop new frames from being generated
        frameTimer?.cancel()
   
        
        // Now safe to clear inputs since processing is stopped
        print("🎮 Clearing input state...")
        pendingInputs.removeAll()
        currentButtonStates.removeAll()
        lastPressTime.removeAll()

        
        // Finally cleanup resources
        print("🧹 Cleaning up core...")
        //currentCore?.cleanup()
 
        print("✅ Shutdown complete")
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Return the first completed result, or throw if timeout
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // Cancel any remaining tasks
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
    public func handleControllerAction(_ action: SoolraControllerAction, pressed: Bool) {
        // Don't process inputs during shutdown
        var isShuttingDown = false
        updateState { state in
            isShuttingDown = state.isShuttingDown
        }
        if isShuttingDown { return }
        
        guard currentCore != nil else {
            print("🎮 ❌ No active core to handle controller action: \(action)")
            return
        }
        
        let currentTime = Date().timeIntervalSinceReferenceDate
        
        // For releases, validate that the button was actually pressed
        if !pressed {
            if currentButtonStates[action] != true {
                print("🎮 ⚠️ Ignoring release for unpressed button: \(action)")
                return
            }
        }
        
        // For button presses, check if we're within the repeat threshold
        if pressed {
            if let lastPress = lastPressTime[action] {
                let timeSinceLastPress = currentTime - lastPress
                if timeSinceLastPress < keyRepeatThreshold {
                    print("🎮 ⚠️ Ignoring repeat press within threshold: \(action)")
                    return
                }
            }
            lastPressTime[action] = currentTime
        } else {
            // Only clear timestamp if this was a legitimate release
            if currentButtonStates[action] == true {
                lastPressTime.removeValue(forKey: action)
            }
        }
        
        // Check if the state actually changed
        if currentButtonStates[action] == pressed {
            print("🎮 ⚠️ Ignoring redundant state: \(action) pressed=\(pressed)")
            return
        }
        
        // Update state
        currentButtonStates[action] = pressed
        
        // Handle opposing directional inputs only for button presses
        if pressed {
            switch action {
            case .left where currentButtonStates[.right] == true:
                currentButtonStates[.right] = false
                queueInput(.right, pressed: false)
            case .right where currentButtonStates[.left] == true:
                currentButtonStates[.left] = false
                queueInput(.left, pressed: false)
            case .up where currentButtonStates[.down] == true:
                currentButtonStates[.down] = false
                queueInput(.down, pressed: false)
            case .down where currentButtonStates[.up] == true:
                currentButtonStates[.up] = false
                queueInput(.up, pressed: false)
            default:
                break
            }
        }
        
        // Queue the input with debug logging
        if pressed {
            print("🎮 ✅ press: \(action) at \(String(format: "%.3f", currentTime))")
        } else {
            print("🎮 ✅ release: \(action) at \(String(format: "%.3f", currentTime))")
        }
        queueInput(action, pressed: pressed)
    }
    
    private func queueInput(_ action: SoolraControllerAction, pressed: Bool) {
        inputLock.lock()
        defer { inputLock.unlock() }
        
        if pressed {
            print("🎮 ⬇️ Queued button press: \(action)")
        } else {
            print("🎮 ⬆️ Queued button release: \(action)")
        }
        
        pendingInputs.append((action, pressed))
    }
    
    @MainActor
    public func initializeRenderer(metalView: MTKView) throws {
        print("🔄 Initializing renderer with MTKView...")
        
        guard let core = currentCore else {
            print("❌ No core available for renderer initialization")
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        
        // Initialize on main thread if we're not already there
        if !Thread.isMainThread {
            return try DispatchQueue.main.sync {
                try initializeRenderer(metalView: metalView)
            }
        }
        
        // Configure Metal view with shared device
        metalView.device = metalManager.device
        
        // Initialize renderer with shared Metal manager
        let renderer = try core.initializeRenderer(metalView: metalView, metalManager: metalManager)
        self.currentRenderer = renderer
        updateState { state in
            state.isRendererInitialized = true
        }
        
        print("✅ Renderer initialized successfully")
    }
    
    private var isEmulationStarted: Bool {
        var started = false
        updateState { state in
            started = state.isEmulationStarted
        }
        return started
    }
    
    public func connectAudioSessionManager(_ manager: AudioSessionManager) {
        print("🔊 Connecting audio session manager to console manager")
        self.audioSessionManager = manager
        manager.onAudioSessionStateChange = { [weak self] isActive in
            guard let self = self else {
                print("🔊 ❌ Self was deallocated in audio session callback")
                return
            }
            
            Task { @MainActor in
                if isActive {
                    print("🔊 Audio session active - ready to resume")
                    // Reset audio components without resuming emulation
                    if let core = self.currentCore {
                        if let gbaCore = core as? GBACore {
                            gbaCore.audioMaker?.stop()
                            gbaCore.audioMaker?.reset()
                        } else if let nesCore = core as? NESCore {
                            nesCore.audioMaker?.stop()
                            nesCore.audioMaker?.reset()
                        }
                    }
                } else {
                    print("🔊 Audio session inactive - pausing emulation")
                    // Directly pause emulation and set the pause menu state
                    self.pauseEmulation()
                    // Set shouldShowPauseMenu for when the app becomes active again
                    self.shouldShowPauseMenu = true
                }
            }
        }
    }
    
    public func pauseEmulation() {
        guard let core = currentCore else { return }
        
        print("⏸️ Pausing emulation - current thread: \(Thread.isMainThread ? "main" : "background")")
        
        updateState { state in
            state.isPaused = true
        }
        
        // Pause audio first
        if let gbaCore = core as? GBACore {
            gbaCore.audioMaker?.stop()
        } else if let nesCore = core as? NESCore {
            nesCore.audioMaker?.stop()
        }
        
        // Then pause the core
        core.pause()
        
        // Stop frame timer
        frameTimer?.cancel()
        frameTimer = nil
    }
    
    public func resumeEmulation() {
        guard let core = currentCore else { return }
        
        print("▶️ Resuming emulation - current thread: \(Thread.isMainThread ? "main" : "background")")
        
        // If audio session is inactive, try to reactivate it
        if !isAudioSessionActive {
            print("🔊 Audio session inactive - attempting to reactivate...")
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try audioSession.setPreferredIOBufferDuration(0.005)
                try audioSession.setPreferredSampleRate(44100)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Failed to reactivate audio session: \(error)")
                shouldShowPauseMenu = true
                return
            }
        }
        
        updateState { state in
            state.isPaused = false
        }
        
        // Reset and resume audio first
        if let gbaCore = core as? GBACore {
            gbaCore.audioMaker?.stop()
            gbaCore.audioMaker?.reset()
            // Add a small delay before starting playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gbaCore.audioMaker?.play()
            }
        } else if let nesCore = core as? NESCore {
            nesCore.audioMaker?.stop()
            nesCore.audioMaker?.reset()
            // Add a small delay before starting playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nesCore.audioMaker?.play()
            }
        }
        
        // Then resume the core
        core.resume()
        
        // Start frame timer
        startFrameTimer()
    }
    
    private func startFrameTimer() {
        // Cancel any existing timer
        frameTimer?.cancel()

        // Tick at the screen’s native 60 Hz rate
        let tickInterval = 1.0 / 60.0

        frameTimer = Timer
            .publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self,
                      let core = self.currentCore,
                      let renderer = self.currentRenderer else {
                    return
                }

                // Don’t do anything when paused
                var paused = false
                self.updateState { paused = $0.isPaused }
                if paused { return }

                // How many sub-frames to run this tick
                let factor = Int(self.currentFastForwardSpeed)
                var lastFrame: ConsoleFrame?

                // 1️⃣ Run N emulation frames (and queue N audio chunks)…
                for _ in 0..<max(1, factor) {
                    lastFrame = core.performFrame()
                }

                // 2️⃣ …then render exactly one video frame
                if let gba = lastFrame as? GBAFrame {
                    let pixels = Array(UnsafeBufferPointer(start: gba.data, count: 240 * 160))
                    renderer.updateTexture(with: pixels)
                } else if let nes = lastFrame as? NESFrame {
                    let pixels = Array(UnsafeBufferPointer(start: nes.data, count: 256 * 240))
                    renderer.updateTexture(with: pixels)
                }
            }
    }

    
    
    
    public func startEmulation() {
        print("🎮 Starting emulation...")
        
        guard let core = currentCore, let renderer = currentRenderer else {
            print("❌ Cannot start emulation - core or renderer not ready")
            return
        }
        
        // Check if already started
        if isEmulationStarted {
            print("⚠️ Emulation already started")
            return
        }
        
        // Start the core's emulation
        core.startEmulation()
        
        // Start frame timer
        startFrameTimer()
        
        updateState { state in
            state.isEmulationStarted = true
            state.isPaused = false
        }
        
        print("✅ Emulation started")
    }
    
    func activateCheat(_ cheat: Cheat) {
        currentCore?.activateCheat(cheat)
    }

    func resetCheats(){
        currentCore?.resetCheats()
    }
    
    private func setMaxFastForwardSpeed(type: ConsoleType) {
        switch type {
        case .gba:
            self.maxFastForwardSpeed = 3
        default:
            self.maxFastForwardSpeed = 4
        }
    }
    
    public func toggleFastForward() {
        currentFastForwardSpeed = (currentFastForwardSpeed == 1) ? maxFastForwardSpeed : 1
        currentCore?.setPlaybackRate(currentFastForwardSpeed)
    }
    
    public func saveState(to: URL) {
        
    }
    
    public func loadState(from: URL) {
        
    }
    
    public func captureScreenshot(to: URL) {
        
    }


    public func getCurrentGameName() -> String {
        return "adad"
    }

}

