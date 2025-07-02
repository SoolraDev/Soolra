#include "SoolraPSPBridge.h"

#include "Core/System.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Common/GraphicsContext.h"
#include "Common/System/NativeApp.h"
#include "GPU/GPUState.h"
#include "Common/File/FileUtil.h"



#include <cstdio>
#import <AVFoundation/AVFoundation.h>



extern "C" int GetScreenWidth() {
    return 1280;
}

extern "C" int GetScreenHeight() {
    return 720;
}

extern "C" const uint16_t *ppsspp_getRGB565FrameBuffer() {
    if (!gpu) return nullptr;
    return gpu->FramebufferManager()->GetDisplayFramebuffer();
}

void start_ppsspp_core_with_path(const char *iso_path) {
    const char *docPathCStr = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] UTF8String];
    const char *assetsPathCStr = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"assets"] UTF8String];

    NativeInit(0, nullptr, docPathCStr, assetsPathCStr, nullptr);

    
    CoreParameter coreParam;

    // === Core selection ===
    coreParam.cpuCore = CPUCore::INTERPRETER;       // iOS does not allow JIT
//    coreParam.gpuCore = GPUCORE_GLES;
    coreParam.gpuCore = GPUCORE_SOFTWARE;     // ✅ Use software rendering


    // === Graphics context ===
    coreParam.graphicsContext = nullptr;  // 🚨 no GL context
    coreParam.enableSound = true;
    coreParam.headLess = true;         // 🚨 disables messageboxes etc

    // === File to start ===
    coreParam.fileToStart = Path(iso_path);

    // === Render settings ===
    coreParam.renderScaleFactor = 1;
    coreParam.pixelWidth = 480;
    coreParam.pixelHeight = 272;
    coreParam.renderWidth = 480;
    coreParam.renderHeight = 272;

    // === Runtime settings ===
    coreParam.fpsLimit = FPSLimit::NORMAL;
    coreParam.analogFpsLimit = 0;
    coreParam.fastForward = false;
    coreParam.updateRecent = true;

    // === Misc ===
    coreParam.startBreak = false;
    coreParam.headLess = false;
    coreParam.freezeNext = false;
    coreParam.frozen = false;
    coreParam.mountIsoLoader = nullptr;

    // Compatibility defaults
    coreParam.compat = Compatibility();

    // === Start PPSSPP ===
    bool started = PSP_InitStart(coreParam);
    if (!started) {
        printf("Failed to start PPSSPP core\n");
        return;
    }

    std::string errorString;
    while (PSP_InitUpdate(&errorString) == BootState::Booting) {
        printf("Booting PPSSPP...\n");
    }

    printf("PPSSPP is done Booting!\n");
    
    if (PSP_IsInited()) {
        printf("✅ PPSSPP core is initialized and running a game.\n");
    }
    
    Core_NextFrame();
    Core_NextFrame();
    Core_NextFrame();
    Core_NextFrame();
    Core_NextFrame();
    Core_NextFrame();
    Core_NextFrame();
    
   

}
