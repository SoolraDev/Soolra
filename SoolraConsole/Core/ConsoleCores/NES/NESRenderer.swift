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


// MARK: - NES Types
struct NESFrame: ConsoleFrame {
    let data: UnsafeMutablePointer<UInt16>
    
    func update(_ frame: Any) {
        guard let nesFrame = frame as? NESFrame else { return }
        memcpy(data, nesFrame.data, NESCore.Constants.frameBufferSize * MemoryLayout<UInt16>.stride)
    }
    
    func getPixel(at index: Int) -> UInt16 {
        return data[index]
    }
}


class NESRenderer: NSObject, MTKViewDelegate, ConsoleRenderer {
    // MARK: - Constants
    private enum Constants {
        static let frameWidth: Int = 256
        static let frameHeight: Int = 240
        static let aspectRatio: Float = 8.0 / 7.0  // NES aspect ratio
    }
    
    // MARK: - Protocol Properties
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let pipelineState: MTLRenderPipelineState
    public let vertexBuffer: MTLBuffer
    public let texture: MTLTexture
    
    // MARK: - Private Properties
    private var frameCount: UInt = 0
    private var isCleaningUp = false
    private let renderLock = NSLock()
    
    // MARK: - Initialization
    @MainActor
    static func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> Self {
        return try Self(metalView: metalView, metalManager: metalManager)
    }
    
    @MainActor
    required init(metalView: MTKView, metalManager: MetalManager) throws {
        self.device = metalManager.device
        self.commandQueue = try metalManager.getCommandQueue()
        
        // Create quad vertices with correct aspect ratio
        let scaleX: Float = 1.0
        let scaleY: Float = scaleX / Constants.aspectRatio
        
        let vertices: [Vertex] = [
            Vertex(position: [-scaleX,  scaleY], texCoord: [0.0, 0.0]),
            Vertex(position: [ scaleX,  scaleY], texCoord: [1.0, 0.0]),
            Vertex(position: [-scaleX, -scaleY], texCoord: [0.0, 1.0]),
            Vertex(position: [ scaleX, -scaleY], texCoord: [1.0, 1.0])
        ]
        
        // Create vertex buffer
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        ) else {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        self.vertexBuffer = vertexBuffer
        
        // Create texture descriptor
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .r16Uint
        textureDescriptor.width = Constants.frameWidth
        textureDescriptor.height = Constants.frameHeight
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared
        textureDescriptor.sampleCount = 1
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        self.texture = texture
        
        // Create pipeline state
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        } catch {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        
        super.init()
        
        // Configure Metal view
        metalView.device = device
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.preferredFramesPerSecond = 60
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        guard !isCleaningUp,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let currentDrawable = view.currentDrawable else { 
            return 
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
        
        frameCount += 1
    }
    
    // MARK: - Texture Updates
    func updateTexture(with pixels: [UInt16]) {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        guard !isCleaningUp else { return }
        
        let region = MTLRegionMake2D(0, 0, Constants.frameWidth, Constants.frameHeight)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: Constants.frameWidth * MemoryLayout<UInt16>.stride
        )
    }
    
    func prepareForCleanup() async {
        isCleaningUp = true
        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer?.commit()
    }
    
    deinit {
        print("🧹 Starting NESRenderer deinit...")
        print("✅ NESRenderer deinit complete")
    }
}

// MARK: - Shader Source
private extension NESRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.texCoord = in.texCoord;
        return out;
    }

    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                texture2d<uint> tex [[texture(0)]]) {
        constexpr sampler texSampler(mag_filter::nearest,
                                   min_filter::nearest,
                                   address::clamp_to_edge);
                                   
        uint2 texSize = uint2(256, 240);
        uint2 pixelCoord = uint2(in.texCoord.x * texSize.x, in.texCoord.y * texSize.y);
        pixelCoord = clamp(pixelCoord, uint2(0, 0), texSize - 1);
        
        uint rgb565 = tex.read(pixelCoord).r;
        
        float r = float((rgb565 & 0xF800) >> 11) / 31.0;
        float g = float((rgb565 & 0x07E0) >> 5) / 63.0;
        float b = float(rgb565 & 0x001F) / 31.0;
        
        return float4(r, g, b, 1.0);
    }
    """
}
