//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

class GBAAudioMaker: NSObject, AudioMakerProtocol {
    private var audioEngine: AVAudioEngine
    private var audioPlayerNode: AVAudioPlayerNode
    private var audioFormat: AVAudioFormat
    private var audioConverter: AVAudioConverter?
    private weak var bridge: GBABridge?
    private var isEngineRunning = false
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private let pendingBufferLock = NSLock()
    private var timePitchNode: AVAudioUnitTimePitch?
     var currentRate: Float = 1.0
    
    override init() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        // Use GBABridge's audio format configuration
        guard let bridge = GBABridge.shared else {
            fatalError("GBABridge must be initialized before GBAAudioMaker")
        }
        
        self.bridge = bridge
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)! // Supported format
        
        super.init()
        
        setupAudio()
    }
    
    private func setupAudio() {
        print("🎵 Setting up GBA audio...")

        // Create and configure time pitch node
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = currentRate
        self.timePitchNode = timePitch

        // Attach nodes (custom nodes ONLY)
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(timePitch)

        // Connect player ➝ timePitch ➝ mainMixer (mainMixer is already attached)
        audioEngine.connect(audioPlayerNode, to: timePitch, format: audioFormat)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: audioFormat)

        // Setup audio converter
        if let inputFormat = bridge?.audioFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: audioFormat)
        } else {
            print("❌ Error: GBABridge audioFormat is nil, cannot create audio converter.")
        }

        // Start the engine
        startEngine()
    }


    
    private func startEngine() {
        guard !isEngineRunning else { return }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isEngineRunning = true
            print("✅ GBA audio engine started successfully")
            
            // Schedule any pending buffers
            playPendingBuffers()
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    private func playPendingBuffers() {
        pendingBufferLock.lock()
        defer { pendingBufferLock.unlock() }
        
        guard isEngineRunning else { return }
        
        for buffer in pendingBuffers {
            audioPlayerNode.scheduleBuffer(buffer, completionHandler: nil)
        }
        pendingBuffers.removeAll()
        
        if !audioPlayerNode.isPlaying {
            audioPlayerNode.play()
        }
    }
    
    func queueBuffer(_ buffer: UnsafePointer<UInt16>, size: Int) {
        guard size > 0 else { return }
        
        // Create input buffer from raw data
        let samplesPerFrame = size / 4  // 4 bytes per frame (2 channels * 2 bytes per sample)
        guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 2, interleaved: true),
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samplesPerFrame)) else {
            print("Failed to create input buffer")
            return
        }
        
        inputBuffer.frameLength = inputBuffer.frameCapacity
        memcpy(inputBuffer.int16ChannelData?[0], buffer, size)
        
        // Convert to supported format
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: inputBuffer.frameCapacity) else {
            print("Failed to create output buffer")
            return
        }
        
        var error: NSError?
        let status = audioConverter?.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if status == .error {
            print("Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        pendingBufferLock.lock()
        if isEngineRunning {
            // If engine is running, schedule immediately
            audioPlayerNode.scheduleBuffer(outputBuffer, completionHandler: nil)
            if !audioPlayerNode.isPlaying {
                audioPlayerNode.play()
            }
        } else {
            // Otherwise, store for later
            pendingBuffers.append(outputBuffer)
            // Try to start the engine
            startEngine()
        }
        pendingBufferLock.unlock()
    }
    
    func play() {
        startEngine()
        if isEngineRunning {
            audioPlayerNode.play()
        }
    }
    
    func pause() {
        audioPlayerNode.pause()
    }
    
    func stop() {
        pendingBufferLock.lock()
        pendingBuffers.removeAll()
        pendingBufferLock.unlock()
        
        audioPlayerNode.stop()
        audioEngine.stop()
        isEngineRunning = false
    }
    
    func reset() {
        print("🔄 Resetting GBA audio maker")
        stop()
        
        // Create new instances
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        // Reconfigure
        setupAudio()
    }
    
    deinit {
        print("🎵 GBA AudioMaker being deallocated")
        NotificationCenter.default.removeObserver(self)
        stop()
    }
    
    public func setPlaybackRate(_ rate: Float) {
        currentRate = rate;
    }
    
}
