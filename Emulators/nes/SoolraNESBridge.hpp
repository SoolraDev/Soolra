//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#ifndef NESBRIDGE_HPP
#define NESBRIDGE_HPP

#ifdef __cplusplus
    #include <cstdint>  // C++ version of stdint.h
    #include <cstddef>  // C++ version of stddef.h
    
#else
    #include <stdint.h> // Standard C version
    #include <stddef.h> // Standard C version
#endif

#if defined(__cplusplus)
extern "C" {


#endif

// Callback type definitions
typedef void (*NESBufferCallback)(const uint16_t* buffer, size_t size);


// Core functions
void NES_Init(void);
bool NES_LoadROM(const char* romPath);
void NES_Shutdown(void);
void NES_RunFrame(void);
bool NES_IsPAL(void);
bool NES_AddCheatCode(const char *_Nonnull cheatCode);
void NES_ResetCheats();

// Input handling
void NES_SetInput(int button);
void NES_ClearInput(int button);
void NES_ResetInputs(void);

// Callback setters
void NES_SetVideoCallback(NESBufferCallback callback);
void NES_SetAudioCallback(NESBufferCallback callback);

#if defined(__cplusplus)
}
#endif

#endif /* NESBRIDGE_HPP */
