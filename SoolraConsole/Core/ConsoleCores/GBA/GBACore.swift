//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import Combine
import MetalKit

// Import from our project
@_exported import struct Foundation.Data
@_exported import class Foundation.NSObject

// MARK: - GBA Core Implementation
class GBACore: ConsoleCore {

    

    
    typealias FrameType = GBAFrame
    typealias ConsoleRendererType = GBARenderer
    typealias AudioMakerType = GBAAudioMaker
    
    // Required by ConsoleCore protocol
    var renderer: GBARenderer?
    var audioMaker: GBAAudioMaker?
    var frameDuration: TimeInterval { return 1.0 / 60.0 }
    
    // Existing properties
    private var frameCount: UInt = 0
    private var videoBuffer: UnsafeMutablePointer<UInt8>?
    private var audioBuffer: UnsafeMutablePointer<UInt8>?
    private var audioPhase: Double = 0
    private var lastFrameTime: TimeInterval = Date().timeIntervalSinceReferenceDate
    private var startTime: TimeInterval = Date().timeIntervalSinceReferenceDate
    private var frameTimer: AnyCancellable?
    public var bridge: GBABridge?
    public var autosavePath: URL
    
    // Add state tracking
    private var isCleaningUp = false
    private var lastMenuPressTime: TimeInterval = 0
    private let menuDebounceInterval: TimeInterval = 0.5  // 500ms debounce
    
    // Audio handling
    private var _audioMaker: GBAAudioMaker?
    
    // Test pattern colors
    private let colors: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (255, 0, 0),    // Red
        (0, 255, 0),    // Green
        (0, 0, 255),    // Blue
        (255, 255, 0),  // Yellow
        (255, 0, 255),  // Magenta
        (0, 255, 255),  // Cyan
    ]
    
    // Add input lock
    private let inputLock = NSLock()
    
    // Add buffer ownership tracking
    private var ownsVideoBuffer = false
    private var ownsAudioBuffer = false
    
    // Add at class level
    private let cleanupGroup = DispatchGroup()
    private let initializationGroup = DispatchGroup()
    
    // Add pause state
    private var isPaused: Bool = false
    
    private var firstFrame = false;
    
    // Required initializer
    required init(romPath: URL, autosavePath: URL) throws {
        print("📝 Loading initial ROM from path: \(romPath.path)")
        
        // Verify the file exists and is readable
        guard FileManager.default.fileExists(atPath: romPath.path),
              FileManager.default.isReadableFile(atPath: romPath.path) else {
            throw NSError(domain: "GBACore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to verify ROM file"])
        }
        
        // Get file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: romPath.path)[.size] as? UInt64 ?? 0
        print("✅ ROM file size verified: \(fileSize) bytes")
        
        // Initial setup
        startTime = Date().timeIntervalSinceReferenceDate
        lastFrameTime = startTime
        frameCount = 0
        self.autosavePath = autosavePath
        // Initialize with first ROM
        try initialize(withROM: romPath)
    }
    
    // Required protocol methods
    @MainActor func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> GBARenderer {
        print("🎮 Initializing renderer...")
        
        // Clean up existing renderer if any
        if renderer != nil {
            print("🧹 Cleaning up existing renderer")
            renderer = nil
        }
        
        // Create new renderer
        let newRenderer = try GBARenderer.initializeRenderer(metalView: metalView, metalManager: metalManager)
        self.renderer = newRenderer
        print("✅ Renderer initialization complete")
        return newRenderer
    }
    
    func initializeAudio(audioMaker: GBAAudioMaker) {
        print("🎵 Initializing audio maker for GBA...")
        self.audioMaker = audioMaker
        print("✅ Audio maker initialized for GBA")
    }
    
    func powerUp() {
        print("🎮 GBA Core powered up")
    }
    
    func isPauseState() -> Bool {
        return isPaused
    }
    
    func pause() {
        self.autoSave()
        isPaused = true
        audioMaker?.pause()
        renderer?.pause()
    }
    
    func resume() {
        isPaused = false
        audioMaker?.play()
        renderer?.resume()
    }
    
    func shutdown() {
        print("🛑 Shutting down GBA Core")
        self.autoSave()
        frameTimer?.cancel()
        audioMaker?.stop()
        bridge?.stop()
    }
    
    func initialize(withROM romPath: URL) throws {
        print("🔄 initializing GBACore with new ROM...")
        firstFrame = true;
        
        // Initialize audio if not already initialized
        if _audioMaker == nil {
            print("⚠️ Warning: Audio maker not initialized before initialize")
        }
        
        // Initialize bridge - it will allocate its own buffers
        bridge = GBABridge()
        
        // Reset state
        startTime = Date().timeIntervalSinceReferenceDate
        lastFrameTime = startTime
        frameCount = 0
        
        // Start the bridge with new ROM
        bridge?.start(withGameURL: romPath)
        self.loadAutoSave()
        
        // Start audio playback if available
        _audioMaker?.play()
        
        print("✅ GBACore initialization complete")
    }
    
    private func clamp(_ value: Double) -> UInt8 {
        return UInt8(max(0, min(255, value * 255)))
    }
    
    func performFrame() -> GBAFrame {
        // If paused, return current frame without running emulation
        if isPaused {
            guard let videoBuffer = bridge?.videoBufferPublic else {
                fatalError("No video buffer available")
            }
            return GBAFrame(data: UnsafeMutablePointer<UInt16>(OpaquePointer(videoBuffer)))
        }
    

        // Run one frame of emulation
        bridge?.runFrame(processVideo: true)
        
        // Process audio for this frame
        if let audioBuffer = bridge?.audioBufferPublic {
            let samplesPerFrame = Int(bridge?.audioFrameLength ?? 0)
            if samplesPerFrame > 0 {
                let audioSize = samplesPerFrame * 4  // 2 bytes per sample * 2 channels
                if (!firstFrame) {
                    // hack to skip the 'click' in the first frame
                    audioMaker?.queueBuffer(audioBuffer, size: audioSize)
                }
            }
        }
        firstFrame = false;
        
        guard let videoBuffer = bridge?.videoBufferPublic else {
            fatalError("No video buffer available")
        }
        
        frameCount += 1
        
        // Return frame directly from bridge's buffer
        return GBAFrame(data: UnsafeMutablePointer<UInt16>(OpaquePointer(videoBuffer)))
    }

    
    
    func pressButton(_ action: SoolraControllerAction) {
        // Prevent input during cleanup
        if isCleaningUp {
            return
        }
        
        inputLock.lock()
        defer { inputLock.unlock() }
        
        guard let bridge = bridge else { return }
        
        // Special handling for menu button to prevent crashes
        if action == .menu {
            let currentTime = Date().timeIntervalSinceReferenceDate
            if currentTime - lastMenuPressTime < menuDebounceInterval {
                return  // Ignore rapid menu presses
            }
            lastMenuPressTime = currentTime
        }
        
        // Only handle supported GBA buttons
        switch action {
        case .up:
            bridge.activateInput(Int(GBAButton.up.rawValue))
        case .down:
            bridge.activateInput(Int(GBAButton.down.rawValue))
        case .left:
            bridge.activateInput(Int(GBAButton.left.rawValue))
        case .right:
            bridge.activateInput(Int(GBAButton.right.rawValue))
        case .a:
            bridge.activateInput(Int(GBAButton.a.rawValue))
        case .b:
            bridge.activateInput(Int(GBAButton.b.rawValue))
        case .start:
            bridge.activateInput(Int(GBAButton.start.rawValue))
        case .select:
            bridge.activateInput(Int(GBAButton.select.rawValue))
        case .x, .r:
            bridge.activateInput(Int(GBAButton.r.rawValue))  // Map X to R trigger
        case .y, .l:
            bridge.activateInput(Int(GBAButton.l.rawValue))  // Map Y to L trigger
        case .menu, .upRight, .upLeft, .downRight, .downLeft:
            // Explicitly ignore unsupported buttons
            return
        }
    }
    
    func releaseButton(_ action: SoolraControllerAction) {
        inputLock.lock()
        defer { inputLock.unlock() }
        
        guard let bridge = bridge else { return }
        
        // Only handle supported GBA buttons
        switch action {
        case .up:
            bridge.deactivateInput(Int(GBAButton.up.rawValue))
        case .down:
            bridge.deactivateInput(Int(GBAButton.down.rawValue))
        case .left:
            bridge.deactivateInput(Int(GBAButton.left.rawValue))
        case .right:
            bridge.deactivateInput(Int(GBAButton.right.rawValue))
        case .a:
            bridge.deactivateInput(Int(GBAButton.a.rawValue))
        case .b:
            bridge.deactivateInput(Int(GBAButton.b.rawValue))
        case .start:
            bridge.deactivateInput(Int(GBAButton.start.rawValue))
        case .select:
            bridge.deactivateInput(Int(GBAButton.select.rawValue))
        case .x, .r:
            bridge.deactivateInput(Int(GBAButton.r.rawValue))  // Map X to R trigger
        case .y, .l:
            bridge.deactivateInput(Int(GBAButton.l.rawValue))  // Map Y to L trigger
        case .menu, .upRight, .upLeft, .downRight, .downLeft:
            // Explicitly ignore unsupported buttons
            return
        }
    }
    
    func startEmulation() {
        print("🎮 Starting GBA emulation...")
        
        // Ensure we're ready to start
        guard let bridge = self.bridge else {
            print("⚠️ Cannot start emulation - bridge not ready")
            return
        }
        
        print("✅ GBA emulation started")
    }
    func activateCheat(_ cheat: Cheat) {
        bridge?.activateCheat(cheat)
    }
    
    
    func resetCheats() {
        bridge?.resetCheats()
    }
    
    func setPlaybackRate(_ rate: Float) {
        audioMaker?.setPlaybackRate(rate)
    }
    
    func captureScreenshot(to url: URL) {
        guard let buffer = bridge?.videoBufferPublic else {
            print("❌ No video buffer available for screenshot")
            return
        }
        ScreenshotSaver.saveRGB565BufferAsPNG(buffer: buffer, width: 240, height: 160, to: url)
    }
    
    func loadGameState(from: URL) {
        bridge?.loadGameState(from: from)
    }
    
    func saveGameState(to: URL)
    {
        bridge?.saveGameState(to: to)
    }
    
    func autoSave()
    {
        bridge?.saveAutosave(to: self.autosavePath)
    }
    
    func loadAutoSave()
    {
        bridge?.loadAutosave(from: self.autosavePath)
    }
    
    
    
}
