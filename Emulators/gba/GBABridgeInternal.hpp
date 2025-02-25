//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#ifndef GBABridgeInternal_hpp
#define GBABridgeInternal_hpp

// VBA Core includes
#include "core/gba/gba.h"
#include "core/gba/gbaSound.h"
#include "core/gba/gbaRtc.h"
#include "core/gba/gbaGlobals.h"
#include "core/gba/gbaFlash.h"
#include "core/base/port.h"

// External VBA memory buffers
extern uint8_t* g_bios;
extern uint8_t* g_rom;
extern uint8_t* g_internalRAM;
extern uint8_t* g_workRAM;
extern uint8_t* g_paletteRAM;
extern uint8_t* g_vram;
extern uint8_t* g_pix;
extern uint8_t* g_oam;
extern uint8_t* g_ioMem;

// External VBA variables we need
extern int systemRedShift;
extern int systemGreenShift;
extern int systemBlueShift;
extern int systemColorDepth;
extern int systemFrameSkip;
extern int RGB_LOW_BITS_MASK;
extern bool emulating;
extern struct CoreOptions coreOptions;  // Use VBA's CoreOptions definition
extern uint32_t myROM[];  // Built-in BIOS ROM data
void updateColorMapping(bool isLcdMode);

#endif /* GBABridgeInternal_hpp */ 
