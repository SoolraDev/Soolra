//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#include <algorithm>
#include <memory>
#include <string>
#include <cstdint>
#include <cstdarg>
#include <vector>
#include <chrono>
#include <cstdio>

// Include our sound driver
#include "SoolraSoundDriver.hpp"

// Include VBA sound driver header
#include "core/base/sound_driver.h"
#include "core/gba/gbaSound.h"
#include "core/gb/gbSound.h"

class SoundDriver;

int systemVerbose;
int systemFrameSkip;

int systemRedShift;
int systemGreenShift;
int systemBlueShift;
int systemSaveUpdateCounter = 0;
int  emulating;
int systemColorDepth;

uint16_t systemColorMap16[0x10000];
uint32_t systemColorMap32[0x10000];
#define gs555(x) (x | (x << 5) | (x << 10))
uint16_t systemGbPalette[24] = {
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0,
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0,
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0,
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0,
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0,
    gs555(0x1f), gs555(0x15), gs555(0x0c), 0
};
int RGB_LOW_BITS_MASK;

// Local variables
int autofire, autohold;
static int sensorx[4], sensory[4], sensorz[4];
int sunBars = 1;
bool pause_next;
bool turbo;

bool soundBufferLow;


struct MVFormatID {
    int dummy;
};

const MVFormatID MV_FORMAT_ID_VMV = {0};
const MVFormatID MV_FORMAT_ID_VMV1 = {1};
const MVFormatID MV_FORMAT_ID_VMV2 = {2};

struct supportedMovie {
    MVFormatID formatId;
    const char* longName;
    const char* exts;
};

const supportedMovie movieSupportedToRecord[] = {
    { MV_FORMAT_ID_VMV2, "VBA Movie v2, Time Diff Format", "vmv" },
    { MV_FORMAT_ID_VMV1, "VBA Movie v1, Old Version for Compatibility", "vmv" }
};

const supportedMovie movieSupportedToPlayback[] = {
    { MV_FORMAT_ID_VMV, "VBA Movie", "vmv" }
};

std::vector<MVFormatID> getSupMovFormatsToRecord() {
    std::vector<MVFormatID> result;
    for (auto&& fmt : movieSupportedToRecord)
        result.push_back(fmt.formatId);
    return result;
}

std::vector<char*> getSupMovNamesToRecord() {
    std::vector<char*> result;
    for (auto&& fmt : movieSupportedToRecord)
        result.push_back((char*)fmt.longName);
    return result;
}

std::vector<char*> getSupMovExtsToRecord() {
    std::vector<char*> result;
    for (auto&& fmt : movieSupportedToRecord)
        result.push_back((char*)fmt.exts);
    return result;
}

std::vector<MVFormatID> getSupMovFormatsToPlayback() {
    std::vector<MVFormatID> result;
    for (auto&& fmt : movieSupportedToPlayback)
        result.push_back(fmt.formatId);
    return result;
}

std::vector<char*> getSupMovNamesToPlayback() {
    std::vector<char*> result;
    for (auto&& fmt : movieSupportedToPlayback)
        result.push_back((char*)fmt.longName);
    return result;
}

std::vector<char*> getSupMovExtsToPlayback() {
    std::vector<char*> result;
    for (auto&& fmt : movieSupportedToPlayback)
        result.push_back((char*)fmt.exts);
    return result;
}

std::unique_ptr<SoundDriver> systemSoundInit() {
    return std::make_unique<SoolraSoundDriver>();
}

uint32_t systemGetClock() {
    auto now = std::chrono::steady_clock::now();
    auto duration = now.time_since_epoch();
    auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(duration);
    return static_cast<uint32_t>(millis.count());
}

// Game recording/playback stubs
void systemStartGameRecording(const std::string& fname, MVFormatID format) {}
void systemStopGameRecording() {}
void systemStartGamePlayback(const std::string& fname, MVFormatID format) {}
void systemStopGamePlayback() {}

bool systemReadJoypads() { return true; }
//uint32_t systemReadJoypad(int joy) { return 0; }
void systemShowSpeed(int speed) {}
void systemFrame() {}
void system10Frames() {}
void systemScreenCapture(int num) {}
void systemSaveOldest() {}
void systemLoadRecent() {}
void systemCartridgeRumble(bool b) {}

static uint8_t sensorDarkness = 0xE8;
uint8_t systemGetSensorDarkness() { return sensorDarkness; }
void systemUpdateSolarSensor() {}
void systemUpdateMotionSensor() {}
int systemGetSensorX() { return sensorx[0]; }
int systemGetSensorY() { return sensory[0]; }
int systemGetSensorZ() { return sensorz[0] / 10; }

void systemGbPrint(uint8_t* data, int len, int pages, int feed, int pal, int cont) {}
void systemScreenMessage(const char* msg) {}
bool systemCanChangeSoundQuality() { return true; }
bool systemPauseOnFrame() { return false; }
void systemGbBorderOn() {}
void log(const char* msg, ...) {}
void systemMessage(int id, const char* fmt, ...) {}
void systemOnSoundShutdown() {
    // do nothing
}

// Debug functions
#if defined(VBAM_ENABLE_DEBUGGER)
int (*remoteSendFnc)(char*, int) = nullptr;
int (*remoteRecvFnc)(char*, int) = nullptr;
void (*remoteCleanUpFnc)() = nullptr;

bool debugOpenPty() { return false; }
bool debugWaitPty() { return false; }
bool debugStartListen(int port) { return false; }
bool debugWaitSocket() { return false; }
#endif
