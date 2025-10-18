//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//


import AVFoundation
import Combine
import Foundation

    
public class NESAudioMaker : AudioMakerProtocol {
    
        // Audio configuration
        private let sampleRate: Int
        private let frameRate: Int
        private let samplesPerFrame: Int
        private let audioConverter: AVAudioConverter?
        private let inputFormat: AVAudioFormat
        private let format: AVAudioFormat
        private var timePitchNode: AVAudioUnitTimePitch?
        private var currentRate: Float = 1.0
    
        // Audio engine components
        private var ae: AVAudioEngine
        private var player: AVAudioPlayerNode
        private var mainMixer: AVAudioMixerNode
        
        // State tracking
        private var isEngineRunning = false
        private var pendingBuffers: [AVAudioPCMBuffer] = []
        private let pendingBufferLock = NSLock()
        
        // Debug counters
        private var totalSamplesQueued: Int = 0
        private var totalSamplesProcessed: Int = 0
        private var lastDebugPrint: TimeInterval = Date().timeIntervalSinceReferenceDate
        private let debugInterval: TimeInterval = 1.0  // Log every second

        public init(sampleRate: Int = 44100, frameRate: Int = 60) {
            print("🎵 Initializing NES AudioMaker with sample rate: \(sampleRate)Hz, frame rate: \(frameRate)fps")
            
            self.sampleRate = sampleRate
            self.frameRate = frameRate
            self.samplesPerFrame = sampleRate / frameRate
            
            // Create input format (mono, 16-bit integer)
            guard let inputAudioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                     sampleRate: Double(sampleRate),
                                                     channels: 1,
                                                     interleaved: true) else {
                fatalError("Failed to create input audio format")
            }
            self.inputFormat = inputAudioFormat
            
            // Create output format (mono, 32-bit float)
            guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate),
                                                channels: 1) else {
                fatalError("Failed to create audio format")
            }
            self.format = audioFormat
            
            // Initialize audio components
            self.ae = AVAudioEngine()
            self.player = AVAudioPlayerNode()
            self.mainMixer = AVAudioMixerNode()
            
            // Create converter
            self.audioConverter = AVAudioConverter(from: inputFormat, to: format)
            
       
            
            setupAudio()
        }
        
        private func setupAudio() {
            print("🎵 Setting up NES audio...")
            
            // Create time pitch unit
            let timePitch = AVAudioUnitTimePitch()
            timePitch.rate = currentRate
            self.timePitchNode = timePitch

            // Attach to engine
            ae.attach(player)
            ae.attach(timePitch)
            ae.attach(mainMixer)

            // Connect: player -> timePitch -> mixer -> output
            ae.connect(player, to: timePitch, format: format)
            ae.connect(timePitch, to: mainMixer, format: format)
            ae.connect(mainMixer, to: ae.outputNode, format: format)

            
            // Set conservative volume
            mainMixer.volume = 0.8
            
            // Start audio engine
            startEngine()
        }
        
        private func startEngine() {
            guard !isEngineRunning else { return }
            
            do {
                ae.prepare()
                try ae.start()
                isEngineRunning = true
                print("✅ NES audio engine started successfully")
                
                // Schedule any pending buffers
                playPendingBuffers()
            } catch {
                print("❌ Failed to start NES audio engine: \(error)")
                isEngineRunning = false
            }
        }
        
        private func playPendingBuffers() {
            pendingBufferLock.lock()
            defer { pendingBufferLock.unlock() }
            
            guard isEngineRunning else { return }
            
            for buffer in pendingBuffers {
                player.scheduleBuffer(buffer, completionHandler: nil)
            }
            pendingBuffers.removeAll()
            
            if !player.isPlaying {
                player.play()
            }
        }
        
        public func play() {
            startEngine()
            if isEngineRunning {
                player.play()
            }
        }
        
        public func pause() {
            player.pause()
        }
        
        public func stop() {
            pendingBufferLock.lock()
            pendingBuffers.removeAll()
            pendingBufferLock.unlock()
            
            player.stop()
            ae.stop()
            isEngineRunning = false
        }
        
        public func reset() {
            print("🔄 Resetting NES audio maker")
            stop()
            
            // Create new instances
            ae = AVAudioEngine()
            player = AVAudioPlayerNode()
            mainMixer = AVAudioMixerNode()
            
            // Reconfigure
            setupAudio()
        }
        
        public func queueBuffer(_ buffer: UnsafePointer<UInt16>, size: Int) {
            guard size > 0 else { return }
            
            // Create input buffer
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                                   frameCapacity: AVAudioFrameCount(size)) else {
                print("❌ Failed to create input buffer")
                return
            }
            
            inputBuffer.frameLength = AVAudioFrameCount(size)
            
            // Copy input data directly
            memcpy(inputBuffer.int16ChannelData?[0], buffer, size * MemoryLayout<Int16>.size)
            
            // Create output buffer
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                                    frameCapacity: inputBuffer.frameCapacity) else {
                print("❌ Failed to create output buffer")
                return
            }
            
            // Convert to float format
            var error: NSError?
            guard let converter = audioConverter else {
                print("❌ No audio converter available")
                return
            }
            
            let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }
            
            if status == .error {
                print("❌ Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            pendingBufferLock.lock()
            if isEngineRunning {
                // If engine is running, schedule immediately
                player.scheduleBuffer(outputBuffer, completionHandler: nil)
                if !player.isPlaying {
                    player.play()
                }
            } else {
                // Otherwise, store for later
                pendingBuffers.append(outputBuffer)
                // Try to start the engine
                startEngine()
            }
            pendingBufferLock.unlock()
            
            totalSamplesQueued += size
        }
        
        deinit {
            print("🎵 NES AudioMaker being deallocated")
            NotificationCenter.default.removeObserver(self)
            stop()
        }
    
    public func setPlaybackRate(_ rate: Float) {
        currentRate = rate;
    }

    }

