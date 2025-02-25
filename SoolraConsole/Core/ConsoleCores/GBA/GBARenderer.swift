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


// MARK: - Frame Extensions
struct GBAFrame: ConsoleFrame {
    var data: UnsafeMutablePointer<UInt16>  // RGB565 format
    
    func update(_ frame: Any) {
        guard let gbaFrame = frame as? GBAFrame else { return }
        memcpy(data, gbaFrame.data, 240 * 160 * 2)  // 2 bytes per pixel for RGB565
    }
}


class GBARenderer: NSObject, MTKViewDelegate, ConsoleRenderer {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    let texture: MTLTexture
    private var frameCount: UInt = 0
    private weak var gbaCore: GBACore?
    private weak var metalView: MTKView?
    
    // Simplified state tracking
    private var isCleaningUp = false
    private var isPaused = false
    private let renderLock = NSLock()
    
    // Performance tracking
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimeAccumulator: CFTimeInterval = 0
    private let frameTimeWindow: UInt = 60
    private var startTime: CFTimeInterval = 0
    
    @MainActor
    static func initializeRenderer(metalView: MTKView, metalManager: MetalManager) throws -> Self {
        return try Self(metalView: metalView, metalManager: metalManager)
    }
    
    @MainActor
    required init(metalView: MTKView, metalManager: MetalManager) throws {
        self.startTime = CACurrentMediaTime()
        self.metalView = metalView
        
        self.device = metalManager.device
        self.commandQueue = try metalManager.getCommandQueue()
        
        // Calculate the aspect ratio to maintain GBA's 3:2 ratio
        let gbaAspectRatio: Float = 3.0 / 2.0
        let scaleX: Float = 1.0
        let scaleY: Float = scaleX / gbaAspectRatio
        
        let vertices: [Vertex] = [
            Vertex(position: [-scaleX,  scaleY], texCoord: [0.0, 0.0]),
            Vertex(position: [ scaleX,  scaleY], texCoord: [1.0, 0.0]),
            Vertex(position: [-scaleX, -scaleY], texCoord: [0.0, 1.0]),
            Vertex(position: [ scaleX, -scaleY], texCoord: [1.0, 1.0])
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                 length: vertices.count * MemoryLayout<Vertex>.stride,
                                                 options: .storageModeShared) else {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        self.vertexBuffer = vertexBuffer
        
        // Create texture using BGRA8 format with GBA's native resolution
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = 240  // GBA native width
        textureDescriptor.height = 160 // GBA native height
        textureDescriptor.usage = [.shaderRead, .shaderWrite]  // Allow CPU writes
        textureDescriptor.storageMode = .shared  // Allow CPU access
        textureDescriptor.sampleCount = 1
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw ConsoleCoreManagerError.rendererInitializationFailed
        }
        self.texture = texture
        
        // Configure Metal view
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        
        let shaderSource = """
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
                                    texture2d<float> tex [[texture(0)]]) {
            constexpr sampler texSampler(mag_filter::nearest,
                                       min_filter::nearest,
                                       address::clamp_to_edge);
            return tex.sample(texSampler, in.texCoord);
        }
        """
        
        // Create shader library
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
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
        
        metalView.delegate = self
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.preferredFramesPerSecond = 60
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("🖼️ View size changed to: \(size)")
    }
    
    func draw(in view: MTKView) {
        // this function can cause errors, and also the deinit stage can cause errors
        renderLock.lock()
        defer { renderLock.unlock() }
        
        guard !isCleaningUp,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let currentDrawable = view.currentDrawable else { 
            return 
        }
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
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

    func updateTexture(with pixels: [UInt16]) {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        guard !isCleaningUp else { return }
        
        // Convert RGB565 to BGRA8 on a background queue
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            var bgra8Pixels = [UInt32](repeating: 0, count: 240 * 160)
            
            // Process pixels in chunks for better cache utilization
            let chunkSize = 64
            let chunks = pixels.count / chunkSize
            
            for chunk in 0..<chunks {
                let start = chunk * chunkSize
                let end = start + chunkSize
                
                for i in start..<end {
                    let rgb565 = pixels[i]
                    let r = UInt32((rgb565 & 0xF800) >> 11) * 255 / 31
                    let g = UInt32((rgb565 & 0x07E0) >> 5) * 255 / 63
                    let b = UInt32(rgb565 & 0x001F) * 255 / 31
                    bgra8Pixels[i] = (UInt32(255) << 24) | (r << 16) | (g << 8) | b
                }
            }
            
            // Handle remaining pixels
            let remainingStart = chunks * chunkSize
            for i in remainingStart..<pixels.count {
                let rgb565 = pixels[i]
                let r = UInt32((rgb565 & 0xF800) >> 11) * 255 / 31
                let g = UInt32((rgb565 & 0x07E0) >> 5) * 255 / 63
                let b = UInt32(rgb565 & 0x001F) * 255 / 31
                bgra8Pixels[i] = (UInt32(255) << 24) | (r << 16) | (g << 8) | b
            }
            
            // Update texture on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      !self.isCleaningUp else { return }
                
                let region = MTLRegionMake2D(0, 0, 240, 160)
                self.texture.replace(region: region,
                                  mipmapLevel: 0,
                                  withBytes: bgra8Pixels,
                                  bytesPerRow: 240 * 4)
            }
        }
    }
    
    func prepareForCleanup() async {
        print("🧹 [GBARenderer] Starting cleanup...")
        // Just set the flag - any in-flight operations will check this
        isCleaningUp = true
        
        // Create a final command buffer to flush any pending work
        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer?.commit()
        
        print("✅ [GBARenderer] Cleanup complete")
    }
    
    func pause() {
        isPaused = true
        metalView?.isPaused = true
    }
    
    func resume() {
        isPaused = false
        metalView?.isPaused = false
    }
    
}
