#include "SoolraPSPBridge.h"

#include "Core/System.h"
#include "Core/CoreParameter.h"

void start_ppsspp_core() {
    // 1. Set up graphics context (e.g., Metal/GL) and other services

    // 2. Prepare CoreParameter
    CoreParameter coreParam;
    coreParam.fileToStart = Path("/path/to/your/game.iso");
//    coreParam.graphicsContext = yourGraphicsContextPointer;
    coreParam.enableSound = true;
    // ... set other fields as needed

    // 3. Start PPSSPP core
    bool started = PSP_InitStart(coreParam);
    if (!started) {
        // Handle error
    }

    // 4. Poll for completion
    std::string errorString;
    while (PSP_InitUpdate(&errorString) == BootState::Booting) {
        // Optionally sleep or update UI
        printf("Hello, PPSSPP!\n");
    }

    // 5. Emulation is now running!
}

