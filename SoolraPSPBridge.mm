#include "SoolraPSPBridge.h"

#include "Core/System.h"
#include "Core/CoreParameter.h"

// SoolraPSPBridge.cpp
void start_ppsspp_core_with_path(const char *iso_path) {
    CoreParameter coreParam;
    coreParam.fileToStart = Path(iso_path);
    coreParam.enableSound = true;

    bool started = PSP_InitStart(coreParam);
    if (!started) {
        printf("Failed to start PPSSPP\n");
        return;
    }

    std::string errorString;
    while (PSP_InitUpdate(&errorString) == BootState::Booting) {
        printf("Booting PPSSPP...\n");
    }

    printf("PPSSPP is now running!\n");
}
