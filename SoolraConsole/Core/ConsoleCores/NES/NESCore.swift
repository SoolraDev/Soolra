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



// NES specific implementation
class NESCore: ConsoleCore {

    
    // MARK: - Constants
    enum Constants {
        static let frameWidth: Int = 256
        static let frameHeight: Int = 240
        static let frameBufferSize = frameWidth * frameHeight
        static let sampleRate: Int = 44100
        static let palFrameRate: Double = 50.0
        static let ntscFrameRate: Double = 60.0
        static let palSamplesPerFrame = sampleRate / Int(palFrameRate)
        static let ntscSamplesPerFrame = sampleRate / Int(ntscFrameRate)
    }
    
    // MARK: - Protocol Requirements
    typealias FrameType = NESFrame
    typealias ConsoleRendererType = NESRenderer
    typealias AudioMakerType = NESAudioMaker
    
    // MARK: - Properties
    private var frameCount: UInt = 0
    private var videoBuffer: UnsafeMutablePointer<UInt16>
    private var audioBuffer: UnsafeMutablePointer<UInt16>
    private var renderer: NESRenderer?
    private var bridge: NESBridge?
    private var isPaused: Bool = false
    private var _audioMaker: NESAudioMaker?
    public var audioMaker: NESAudioMaker? { return _audioMaker }
    public var autosavePath: URL
    
    // MARK: - Required Protocol Methods
    required init(romPath: URL, autosavePath: URL) throws {
        print("📝 Loading initial ROM from path: \(romPath.path)")
        
        // Verify ROM file
        guard FileManager.default.fileExists(atPath: romPath.path),
              FileManager.default.isReadableFile(atPath: romPath.path) else {
            throw NSError(domain: "NESCore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to verify ROM file"])
        }
        
        // Allocate buffers
        videoBuffer = .allocate(capacity: Constants.frameBufferSize)
        audioBuffer = .allocate(capacity: Constants.palSamplesPerFrame)
        
        // Initialize bridge with our buffers
        bridge = NESBridge(videoBuffer: videoBuffer, audioBuffer: audioBuffer)
        self.autosavePath = autosavePath
        // Start emulation
        try initialize(withROM: romPath)
    }
    
    func initialize(withROM romPath: URL) throws {
        print("🔄 Initializing NESCore with new ROM...")
        bridge?.setAutosavePath(to: autosavePath)
        bridge?.start(withGameURL: romPath)
        _audioMaker?.play()

        print("✅ NESCore initialization complete")
    }

    
    func performFrame() -> NESFrame {
        guard !isPaused else {
            return NESFrame(data: videoBuffer)
        }
        
        bridge?.runFrame()
        
        // Process audio buffer
        if let audioMaker = _audioMaker {
            let samplesPerFrame = bridge?.isPAL() == true ? 
                Constants.palSamplesPerFrame : Constants.ntscSamplesPerFrame
            audioMaker.queueBuffer(audioBuffer, size: samplesPerFrame)
        }
        
        frameCount += 1
        return NESFrame(data: videoBuffer)
    }
    
    func shutdown() {
        print("🛑 Starting NESCore shutdown...")
        _audioMaker?.stop()
        bridge?.stop()
        print("✅ NESCore shutdown complete")
    }
    
    // MARK: - Audio Management
    func initializeAudio(audioMaker: AudioMakerType) {
        print("🎵 Initializing audio maker for NES...")
        _audioMaker = audioMaker
        print("✅ Audio maker initialized for NES")
    }
    
    // MARK: - Input Management
    func pressButton(_ action: SoolraControllerAction) {
        guard let bridge = bridge else { return }
        
        let button: Int32
        switch action {
        case .up: button = Int32(NESButton.up.rawValue)
        case .down: button = Int32(NESButton.down.rawValue)
        case .left: button = Int32(NESButton.left.rawValue)
        case .right: button = Int32(NESButton.right.rawValue)
        case .a: button = Int32(NESButton.a.rawValue)
        case .b: button = Int32(NESButton.b.rawValue)
        case .start: button = Int32(NESButton.start.rawValue)
        case .select: button = Int32(NESButton.select.rawValue)
        default: return
        }
        
        bridge.activateInput(button)
    }
    
    func releaseButton(_ action: SoolraControllerAction) {
        guard let bridge = bridge else { return }
        
        let button: Int32
        switch action {
        case .up: button = Int32(NESButton.up.rawValue)
        case .down: button = Int32(NESButton.down.rawValue)
        case .left: button = Int32(NESButton.left.rawValue)
        case .right: button = Int32(NESButton.right.rawValue)
        case .a: button = Int32(NESButton.a.rawValue)
        case .b: button = Int32(NESButton.b.rawValue)
        case .start: button = Int32(NESButton.start.rawValue)
        case .select: button = Int32(NESButton.select.rawValue)
        default: return
        }
        
        bridge.deactivateInput(button)
    }
    
    // MARK: - Pause Control
    func pause() {
        isPaused = true
        _audioMaker?.pause()
    }
    
    func resume() {
        isPaused = false
        _audioMaker?.play()
    }
    
    func isPauseState() -> Bool {
        return isPaused
    }
    
    func powerUp() {
        print("🎮 NES Core powered up")
    }
    
    func startEmulation() {
        print("🎮 Starting NES emulation...")
        guard let bridge = bridge else {
            print("⚠️ Cannot start emulation - bridge not ready")
            return
        }
        print("✅ NES emulation started")
    }
    
    @MainActor
    func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> NESRenderer {
        print("🎮 Initializing renderer...")
        
        // Clean up existing renderer if any
        if renderer != nil {
            print("🧹 Cleaning up existing renderer")
            renderer = nil
        }
        
        // Create new renderer
        let newRenderer = try NESRenderer.initializeRenderer(metalView: metalView, metalManager: metalManager)
        self.renderer = newRenderer
        print("✅ Renderer initialization complete")
        return newRenderer
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
        ScreenshotSaver.saveRGB565BufferAsPNG(buffer: buffer, width: 256, height: 240, to: url)
    }
    
    func loadGameState(from: URL) {
        bridge?.loadSaveState(from: from)
    }
    
    func saveGameState(to: URL)
    {
        bridge?.saveGameSave(to: to)
    }


}
