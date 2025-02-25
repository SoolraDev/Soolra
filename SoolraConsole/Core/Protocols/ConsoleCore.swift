//
//  ConsoleCore.swift
//  SOOLRA
//
//  Created on 06/02/2025.
//  This file defines which functions each console core must implement
//


import Foundation
import Combine
import MetalKit
//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

// Protocol for any console core
public protocol ConsoleCore {
    associatedtype ConsoleRendererType: ConsoleRenderer
    associatedtype FrameType: ConsoleFrame
    associatedtype AudioMakerType: AudioMakerProtocol
    
    // Audio handling
    var audioMaker: AudioMakerType? { get }
    
    func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> ConsoleRendererType
    func initializeAudio(audioMaker: AudioMakerType)
    func powerUp()
    func startEmulation()
    func shutdown()
    func pause()
    func resume()
    func isPauseState() -> Bool
    func performFrame() -> FrameType
    func pressButton(_ action: SoolraControllerAction)
    func releaseButton(_ action: SoolraControllerAction)
}

