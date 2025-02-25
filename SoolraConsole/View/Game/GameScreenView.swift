//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import MetalKit
import SwiftUI


struct GameScreenView: View {
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    private let metalView: MTKView
    
    init() {
        metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.framebufferOnly = true
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.preferredFramesPerSecond = 60
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
    }
    
    var body: some View {
        MetalViewRepresentable(metalView: metalView)
            .onAppear {
                Task { @MainActor in
                    try consoleManager.initializeRenderer(metalView: metalView)
                    try consoleManager.startEmulation()
                }
            }
    }
}

// Metal View wrapper
struct MetalViewRepresentable: UIViewRepresentable {
    let metalView: MTKView
    
    func makeUIView(context: Context) -> MTKView {
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Updates are handled by the renderer
    }
}

#Preview {
    GameScreenView()
}
