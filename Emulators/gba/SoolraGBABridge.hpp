//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#ifndef SoolraGBABridge_hpp
#define SoolraGBABridge_hpp

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

// Constants for video output
enum GBAVideoConstants {
    GBA_WIDTH = 240,
    GBA_HEIGHT = 160,
    GBA_BYTES_PER_PIXEL = 2  /* RGB565 format */
};

// Constants for audio output
enum GBAAudioConstants {
    AUDIO_SAMPLE_RATE = 44100,
    AUDIO_FRAMES_PER_SECOND = 60,
    AUDIO_CHANNELS = 2,
    AUDIO_BYTES_PER_SAMPLE = 2,
    AUDIO_SAMPLES_PER_FRAME = AUDIO_SAMPLE_RATE / AUDIO_FRAMES_PER_SECOND,
    AUDIO_FRAME_SIZE = AUDIO_SAMPLES_PER_FRAME * AUDIO_CHANNELS * AUDIO_BYTES_PER_SAMPLE
};

// Audio buffer - size matches Swift's calculation
// (44100Hz / 60fps) * 2 channels * 2 bytes per sample = 2940 bytes per frame
const int AUDIO_BUFFER_SIZE = 2940;  // One frame of stereo audio at 44100Hz

// Callback type definitions
typedef void (*VideoCallback)(const uint8_t* buffer, int32_t size);
typedef void (*AudioCallback)(const uint8_t* buffer, int32_t size);

// External declarations
extern uint8_t* g_audioBuffer;
extern uint16_t* g_videoBuffer;
extern VideoCallback g_videoCallback;
extern AudioCallback g_audioCallback;

// Resource path function - implemented in Swift
const char* getBundleResourcePath(void);

// Initialization and cleanup
void GBAInitialize(VideoCallback videoCallback, AudioCallback audioCallback);
bool GBALoadGame(const char* path);
void GBAShutdown();
void GBACleanup();

// Frame execution and timing
void GBARunFrame(bool processVideo);
double GBAGetFrameTime();
uint32_t GBAGetAudioFrameLength();

// Input handling
void GBAActivateInput(int button);
void GBADeactivateInput(int button);
void GBAResetInputs();

// Buffer management
void GBASetVideoBuffer(uint8_t* buffer);
void GBASetAudioBuffer(uint8_t* buffer);
const uint8_t* GBAGetVideoBuffer();
const uint8_t* GBAGetAudioBuffer();

// Cheats

bool GBAddCheatCode(const char* cheatCode, const char* type);
void GBAResetCheats();


// Save and Load game states
void GBASaveState(const char* path);
void GBASaveGameSave(const char* path);
void GBALoadState(const char* path);
void GBALoadGameSave(const char* path);

#if defined(__cplusplus)
}
#endif

#endif /* SoolraGBABridge_hpp */
