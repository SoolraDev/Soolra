#include "SoolraPSPBridge.h"

#include "Core/System.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Common/GraphicsContext.h"
#include "Common/System/NativeApp.h"
#include "GPU/GPUState.h"
#include "GPU/Common/GPUDebugInterface.h"
#include "GPU/GPUCommon.h"     // defines GPUCommon class
#include "GPU/Software/SoftGpu.h"

#include "Common/File/FileUtil.h"
#include "Core/SaveState.h"
#include "GPU/Common/PresentationCommon.h"


#include <cstdio>
#import <AVFoundation/AVFoundation.h>

#include "GPU/GPUState.h"             // declares: extern GPUCommon *gpu

#include "DummyGraphicsContext.h"  // Make sure path is correct



extern "C" int GetScreenWidth() {
    return 1280;
}

extern "C" int GetScreenHeight() {
    return 720;
}

#include "GPU/Software/SoftGpu.h"
#include "GPU/Common/GPUDebugInterface.h"

PresentationCommon *g_presentation = nullptr;

extern "C" const uint16_t *ppsspp_getRGB565FrameBuffer() {
    static std::vector<uint16_t> rgb565Buffer;

    // Confirm the GPU pointer is valid and is using the Software GPU backend
    auto *softGpu = dynamic_cast<SoftGPU *>(gpu);
    if (!softGpu) return nullptr;

    // Request framebuffer
    static GPUDebugBuffer buffer;
    if (!softGpu->GetOutputFramebuffer(buffer)) {
        printf("❌ Failed to get output framebuffer from SoftGPU\n");
        return nullptr;
    }

    const uint8_t *src = buffer.GetData();
    int width = buffer.GetStride();   // Assume stride is equal to width here (double-check this!)
    int height = buffer.GetHeight();

    int pixelCount = width * height;
    rgb565Buffer.resize(pixelCount);

    // Convert from RGBA8888 (4 bytes per pixel) to RGB565
    for (int i = 0; i < pixelCount; i++) {
        uint8_t r = src[i * 4 + 0];
        uint8_t g = src[i * 4 + 1];
        uint8_t b = src[i * 4 + 2];
        // Alpha ignored
        rgb565Buffer[i] = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
    }

    return rgb565Buffer.data();
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
//    coreParam.graphicsContext = nullptr;  // 🚨 no GL context
    static DummyGraphicsContext dummyCtx;
    coreParam.graphicsContext = &dummyCtx;

    coreParam.headLess = false;
    
    coreParam.enableSound = false;

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

    
    coreParam.freezeNext = false;
    coreParam.frozen = false;
    coreParam.mountIsoLoader = nullptr;

    // Compatibility defaults
    coreParam.compat = Compatibility();
    // === Start PPSSPP ===
    if (!File::Exists(coreParam.fileToStart)) {
        printf("❌ ISO path invalid: %s\n", coreParam.fileToStart.c_str());
        return;
    }
    
    bool started = PSP_InitStart(coreParam);
    if (!started) {
        printf("Failed to start PPSSPP core\n");
        return;
    }

    // Step 1: Boot normally
    std::string errorString;
    while (PSP_InitUpdate(&errorString) == BootState::Booting) {
        printf("Booting PPSSPP...\n");
    }


    printf("PPSSPP is done Booting!\n");
    printf("Final core state after boot: %s\n", CoreStateToString(::coreState));

    // Start the core manually if it's idle or powered down
    if (coreState == CORE_POWERDOWN) {
        printf("⚠️ Core is powered down after boot — starting manually...\n");
        Core_UpdateState(CORE_RUNNING_CPU);
    }

    if (!PSP_IsInited()) {
        printf("❌ Core failed to initialize.\n");
        return;
    }

    printf("✅ PPSSPP core is initialized and running a game.\n");

    
    // ✅ Wait until the core is actively stepping (game loop started)
    int spinCount = 0;
    while (!Core_IsStepping() && spinCount++ < 300) {
        // Let the CPU thread spin up
        usleep(16000);  // ~1 frame (60 FPS)
    }
    // Prevent reuse of stale g_presentation state
    extern PresentationCommon *g_presentation;
    if (g_presentation) {
        g_presentation->DeviceLost();
        delete g_presentation;
        g_presentation = nullptr;
    }

    NativeInitGraphics(&dummyCtx);
    // Run NativeFrame loop to let the core and GPU actually advance
    for (int i = 0; i < 120; ++i) {
        NativeFrame(&dummyCtx);
        usleep(16000);  // Simulate ~60 FPS
    }

    // Step 3: Load the savestate
//    std::string isoStr(iso_path);
//    std::string savePath;
//    size_t dotPos = isoStr.rfind('.');
//    savePath = (dotPos != std::string::npos) ? isoStr.substr(0, dotPos) + ".ppst" : isoStr + ".ppst";
//
//    SaveState::Load(Path(savePath), -1, [](SaveState::Status status, std::string_view msg) {
//        if (status == SaveState::Status::SUCCESS) {
//            printf("✅ Savestate loaded successfully.\n");
//        } else {
//            printf("❌ Failed to load savestate: %s\n", std::string(msg).c_str());
//        }
//    });
    




    printf("Core_IsStepping(): %d\n", Core_IsStepping());
    printf("Core_IsActive(): %d\n", Core_IsActive());
    printf("Core_IsInited(): %d\n", PSP_IsInited());
    
   
    ppsspp_getRGB565FrameBuffer();
}
