//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import Combine
import MetalKit

// Generic protocol for frame data
public protocol ConsoleFrame {
    func update(_ frame: Any)
}

public struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

// Protocol for console renderers
public protocol ConsoleRenderer: MTKViewDelegate {
    var device: MTLDevice { get }
    var commandQueue: MTLCommandQueue { get }
    var pipelineState: MTLRenderPipelineState { get }
    var vertexBuffer: MTLBuffer { get }
    var texture: MTLTexture { get }
    
    // Support UInt16 (RGB565) formats
    func updateTexture(with pixels: [UInt16])
    func prepareForCleanup() async
    
    // Required initializer
    init(metalView: MTKView, metalManager: MetalManager) throws
    
    // Static initializer
    static func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> Self
}

