//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#include "GBABridgeInternal.hpp"

struct CoreOptions coreOptions = {
    .cpuIsMultiBoot = false,
    .mirroringEnable = false,
    .useBios = false,
    .skipBios = true,
    .parseDebug = true,
    .speedHack = false,
    .speedup = false,
    .speedup_throttle_frame_skip = false,
    .speedup_mute = true,
    .cheatsEnabled = 1,
    .cpuDisableSfx = 0,
    .cpuSaveType = 0,
    .layerSettings = 0xff00,
    .layerEnable = 0xff00,
    .rtcEnabled = 0,
    .saveType = 0,
    .skipSaveGameBattery = 1,
    .skipSaveGameCheats = 0,
    .useBios = 0,
    .winGbPrinterEnabled = 1,
    .speedup_throttle = 100,
    .speedup_frame_skip = 9,
    .throttle = 100,
    .loadDotCodeFile = nullptr,
    .saveDotCodeFile = nullptr
}; 


