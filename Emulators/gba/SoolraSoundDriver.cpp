//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#include "SoolraSoundDriver.hpp"
#include "GBABridgeInternal.hpp"
#include "core/gba/gbaSound.h"
#include "SoolraGBABridge.hpp"  // For AudioCallback type and shared declarations
#include <cstdio>  // For printf
#include <cstring>  // For memcpy


// Declare external buffer from SoolraGBABridge.cpp
extern uint8_t* g_audioBuffer;
extern int g_audioBufferSize;
extern const int AUDIO_BUFFER_SIZE;

SoolraSoundDriver::SoolraSoundDriver() 
    : currentSampleRate(AUDIO_SAMPLE_RATE)
    , isInitialized(false)
    , isPaused(false) {}

bool SoolraSoundDriver::init(long sampleRate) {
    // Always use our fixed sample rate for consistency
    currentSampleRate = AUDIO_SAMPLE_RATE;
    
    if (!isInitialized && emulating) {
        soundSetSampleRate(currentSampleRate);
        soundReset();
        isInitialized = true;
        printf("SoolraSoundDriver: Initialized with sample rate %ld Hz\n", currentSampleRate);
        return true;
    }
    
    return emulating;
}

void SoolraSoundDriver::pause() {
    if (isInitialized && emulating && !isPaused) {
        soundPause();
        isPaused = true;
        printf("SoolraSoundDriver: Audio paused\n");
    }
}

void SoolraSoundDriver::reset() {
    if (isInitialized && emulating) {
        soundReset();
        isPaused = false;
        printf("SoolraSoundDriver: Audio reset\n");
    }
}

void SoolraSoundDriver::resume() {
    if (isInitialized && emulating && isPaused) {
        soundResume();
        isPaused = false;
        printf("SoolraSoundDriver: Audio resumed\n");
    }
}

void SoolraSoundDriver::write(uint16_t* finalWave, int length) {
    if (!isInitialized || !emulating || !finalWave || length <= 0 || isPaused) {
        return;
    }
    
    // Validate length against buffer size
    if (length > AUDIO_BUFFER_SIZE) {
        printf("SoolraSoundDriver: Warning - truncating audio data %d -> %d bytes\n",
               length, AUDIO_BUFFER_SIZE);
        length = AUDIO_BUFFER_SIZE;
    }
    
    // Copy to our internal buffer maintaining stereo format
    memcpy(g_audioBuffer, finalWave, length);
    
    // Forward to Swift through callback
    if (g_audioCallback) {
        g_audioCallback(g_audioBuffer, length);
    }
}

void SoolraSoundDriver::setThrottle(unsigned short throttle) {
    // Throttle is not implemented for GBA
} 
