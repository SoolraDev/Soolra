//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation

// MARK: - C Function Declarations
@_silgen_name("NES_IsPAL")
func NES_IsPAL() -> Bool

// MARK: - NES Button Mapping
enum NESButton: UInt32 {
    case right   = 0b10000000
    case left    = 0b01000000
    case down    = 0b00100000
    case up      = 0b00010000
    case start   = 0b00001000
    case select  = 0b00000100
    case b       = 0b00000010
    case a       = 0b00000001
}

// MARK: - NES Bridge
class NESBridge: NSObject {
    public static var shared: NESBridge!

    private var _videoBuffer: UnsafeMutablePointer<UInt16>?
    private var _audioBuffer: UnsafeMutablePointer<UInt16>?
    
    public var videoBufferPublic: UnsafeMutablePointer<UInt16>? {
        return _videoBuffer
    }
    
    public var audioBufferPublic: UnsafeMutablePointer<UInt16>? {
        return _audioBuffer
    }

    public private(set) var gameURL: URL?
    private var isReady = false
    public private(set) var frameDuration: TimeInterval = (1.0 / 60.0)
    
    // Static callbacks
    private static let videoCallback: @convention(c) (UnsafePointer<UInt16>?, Int) -> Void = { buffer, size in
        guard let videoBuffer = NESBridge.shared?.videoBufferPublic,
              let sourceBuffer = buffer else {
            print("⚠️ Video buffer not available")
            return
        }
        memcpy(videoBuffer, sourceBuffer, size * MemoryLayout<UInt16>.size)  // Account for UInt16 size
    }
    
    
    private static let audioCallback: @convention(c) (UnsafePointer<UInt16>?, Int) -> Void = { buffer, size in
        guard let audioBuffer = NESBridge.shared?.audioBufferPublic,
              let sourceBuffer = buffer else {
            print("⚠️ Audio buffer not available")
            return
        }
        memcpy(audioBuffer, sourceBuffer, size * MemoryLayout<Int16>.size)
        //memcpy(audioBuffer, sourceBuffer, size)
    }
    
    public init(
        videoBuffer: UnsafeMutablePointer<UInt16>,
        audioBuffer: UnsafeMutablePointer<UInt16>
    ) {
        self._videoBuffer = videoBuffer
        self._audioBuffer = audioBuffer
        super.init()
        
        print("🎮 Initializing NESBridge")
        
        // Set shared instance before setting callbacks
        NESBridge.shared = self
        
        // Initialize core
        NES_Init()
        
        // Set callbacks
        NES_SetVideoCallback(NESBridge.videoCallback)
        NES_SetAudioCallback(NESBridge.audioCallback)
        
        print("✅ NESBridge initialization complete")
        self.isReady = true
    }
    
    deinit {
        deallocateBuffers()
    }
    
    private func deallocateBuffers() {
        _videoBuffer?.deallocate()
        _videoBuffer = nil
        print("🗑️ Video buffer deallocated")
        
        _audioBuffer?.deallocate()
        _audioBuffer = nil
        print("🗑️ Audio buffer deallocated")
    }
    
    public func start(withGameURL gameURL: URL) {
        guard self.isReady else {
            print("⚠️ NESBridge not ready")
            return
        }

        print("🎮 Starting game from URL: \(gameURL.path)")
        
        self.gameURL = gameURL
        gameURL.withUnsafeFileSystemRepresentation { path in
            guard let path = path else { return }
            _ = NES_LoadROM(path)
        }

        print("✅ Game loaded successfully")
    }
    
    public func stop() {
        print("🛑 Stopping NES emulation...")
        self.isReady = false

        // Shutdown the emulator first - this will stop the PPU
        NES_Shutdown()

        // Finally cleanup our own resources
        self.gameURL = nil

        print("✅ NES emulation stopped")
    }
    
    public func runFrame() {
        if self.isReady {
            NES_RunFrame()
        }
    }
    
    public func activateInput(_ input: Int32) {
        NES_SetInput(input)
    }
    
    public func deactivateInput(_ input: Int32) {
        NES_ClearInput(input)
    }
    
    public func resetInputs() {
        NES_ResetInputs()
    }
    
    public func isPAL() -> Bool {
        return NES_IsPAL()
    }
    
    func activateCheat(_ cheat: Cheat)
    {
        cheat.code.withCString { codeStr in
            NES_AddCheatCode(codeStr)
        }
    }
    
    func resetCheats()
    {
        NES_ResetCheats()
    }
    
    func loadSaveState(from url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESLoadGameSave($0!) }
    }
    
    func saveGameSave(to url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESSaveGameSave($0!) }

    }
}
