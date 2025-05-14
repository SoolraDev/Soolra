//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import AVFoundation
import MetalKit
import CoreGraphics
import CoreImage

@_cdecl("getBundleResourcePath")
public func getBundleResourcePath() -> UnsafePointer<Int8>? {
    guard let resourcePath = Bundle.main.resourcePath else {
        return nil
    }
    
    // Convert to C string and make it static so it persists
    let cString = strdup(resourcePath)
    return UnsafePointer(cString)
}

// MARK: - GBA Button Mapping
enum GBAButton: UInt32 {
    case a       = 0b00000000_00000001  // 0x0001
    case b       = 0b00000000_00000010  // 0x0002
    case select  = 0b00000000_00000100  // 0x0004
    case start   = 0b00000000_00001000  // 0x0008
    case right   = 0b00000000_00010000  // 0x0010
    case left    = 0b00000000_00100000  // 0x0020
    case up      = 0b00000000_01000000  // 0x0040
    case down    = 0b00000000_10000000  // 0x0080
    case l       = 0b00000001_00000000  // 0x0100
    case r       = 0b00000010_00000000  // 0x0200
}


// MARK: - GBA Bridge
class GBABridge: NSObject {
    public static var shared: GBABridge!
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 2, interleaved: true)!
    
    // Video properties
    public let screenWidth: Int = 240
    public let screenHeight: Int = 160
    public let bytesPerPixel: Int = 4  // BGRA8 format
    
    // Buffer sizes
    private let videoBufferSize: Int
    private var audioBufferSize: Int
    
    private var _videoBuffer: UnsafeMutablePointer<UInt16>?
    private var _audioBuffer: UnsafeMutablePointer<UInt16>?
    
    // Audio processing properties
    private let frameDuration: TimeInterval = 1.0 / 60.0
    private let audioBufferCount = 3  // Number of audio buffers to pre-allocate
    
    public var videoBufferPublic: UnsafeMutablePointer<UInt16>? {
        return _videoBuffer
    }
    
    public var audioBufferPublic: UnsafeMutablePointer<UInt16>? {
        return _audioBuffer
    }
    
    public private(set) var gameURL: URL?
    private var isReady = false
    public private(set) var audioFrameLength: UInt32 = 0
    
    // Video callback
    private let videoCallback: @convention(c) (UnsafePointer<UInt8>?, Int32) -> Void = { buffer, size in
        guard let videoBuffer = GBABridge.shared?.videoBufferPublic,
              let sourceBuffer = buffer else {
            print("⚠️ Video buffer not available")
            return
        }
        memcpy(videoBuffer, sourceBuffer, Int(size))
    }
    
    // Audio callback
    private let audioCallback: @convention(c) (UnsafePointer<UInt8>?, Int32) -> Void = { buffer, size in
        guard let audioBuffer = GBABridge.shared?.audioBufferPublic,
              let sourceBuffer = buffer else {
            print("⚠️ Audio buffer not available")
            return
        }
        memcpy(audioBuffer, sourceBuffer, Int(size))
    }
    
    private func allocateAudioBuffer() {
        // Calculate buffer sizes based on format and frame duration
        let inputAudioBufferFrameCount = Int(audioFormat.sampleRate * frameDuration)  // samples per frame
        
        // Calculate buffer size with some headroom
        let bufferAudioBufferCount = 10  // Provide enough headroom
        let preferredBufferSize = inputAudioBufferFrameCount * Int(audioFormat.channelCount) * 2 * bufferAudioBufferCount
        
        print("🎵 Allocating audio buffer:")
        print("  - Sample rate: \(audioFormat.sampleRate)Hz")
        print("  - Channels: \(audioFormat.channelCount)")
        print("  - Frame count: \(inputAudioBufferFrameCount)")
        print("  - Buffer size: \(preferredBufferSize) bytes")
        
        // Allocate the audio buffer
        _audioBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: preferredBufferSize)
        audioBufferSize = preferredBufferSize
        
        print("✅ Audio buffer allocated successfully")
    }
    
    public override init() {
        // Calculate video buffer size
        videoBufferSize = screenWidth * screenHeight * bytesPerPixel
        
        // Temporary initialization of audioBufferSize - will be set properly in allocateAudioBuffer
        audioBufferSize = 0
        
        super.init()
        
        print("🎮 Initializing GBABridge")
        print("📊 Buffer sizes:")
        print("  - Video: \(videoBufferSize) bytes (\(screenWidth)x\(screenHeight))")
        
        // Allocate video buffer
        _videoBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: videoBufferSize)
        
        // Allocate audio buffer with proper calculations
        allocateAudioBuffer()
        
        // Set shared instance before setting callbacks
        GBABridge.shared = self
        
        // Set buffers in C++ bridge
        GBASetVideoBuffer(_videoBuffer!)
        GBASetAudioBuffer(_audioBuffer!)
        
        // Initialize the emulator
        GBAInitialize(videoCallback, audioCallback)
        
        self.audioFrameLength = GBAGetAudioFrameLength()
        
        print("✅ GBABridge initialization complete")
        self.isReady = true
    }
    
    deinit {
        // Clean up allocated buffers
        if let videoBuffer = _videoBuffer {
            videoBuffer.deallocate()
            _videoBuffer = nil
        }
        
        if let audioBuffer = _audioBuffer {
            audioBuffer.deallocate()
            _audioBuffer = nil
        }
        
        print("🎮 GBABridge deinit - buffers deallocated")
    }
    
    public func start(withGameURL gameURL: URL) {
        guard self.isReady else {
            print("⚠️ GBABridge not ready")
            return
        }
        
        print("🎮 Starting game from URL: \(gameURL.path)")
        
        self.gameURL = gameURL
        gameURL.withUnsafeFileSystemRepresentation { path in
            guard let path = path else { return }
            _ = GBALoadGame(path)
        }
        
        self.audioFrameLength = GBAGetAudioFrameLength()
        print("⏱️ Frame duration set to: \(frameDuration)")
        print("🔊 Audio frame length: \(audioFrameLength) samples")
    }
    
    public func stop() {
        GBAShutdown()
        self.gameURL = nil
        
        //GBACleanup()
        //deallocateBuffers()
    }
    
    public func runFrame(processVideo: Bool) {
        GBARunFrame(processVideo)
    }
    
    public func activateInput(_ input: Int) {
        GBAActivateInput(Int32(input))
    }
    
    public func deactivateInput(_ input: Int) {
        GBADeactivateInput(Int32(input))
    }
    
    public func resetInputs() {
        GBAResetInputs()
    }
    
    public func activateCheat(_ cheat: Cheat){
        GBAddCheatCode(cheat.code, cheat.type.rawValue);
    }
    
    public func resetCheats(){
        GBAResetCheats();
    }
    
    func loadGameState(from url: URL)
    {
        if let path = url.path.cString(using: .utf8) {
            GBALoadState(path)
        }
    }
    
    func saveGameState(to url: URL)
    {
        if let path = url.path.cString(using: .utf8) {
            GBASaveState(path)
        }

    }
    
    func loadAutosave(from url: URL)
    {
        if let path = url.path.cString(using: .utf8) {
            GBALoadGameSave(path)
        }

    }
    
    func saveAutosave(to url: URL)
    {
        if let path = url.path.cString(using: .utf8) {
            GBASaveGameSave(path)
        }

    }
    
}


