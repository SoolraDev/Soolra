//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

// Include our bridge header first
#include "SoolraGBABridge.hpp"

#include <memory>
#include <cstring>     // for strcmp, memcpy, etc.
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

#include <string>      // for std::string
#include <sstream>     // for std::istringstream, std::getline
#include <cctype>      // for isxdigit, isspace


// Include our internal header that handles VBA includes
#include "GBABridgeInternal.hpp"

// Global variables (non-static since they're extern in header)
VideoCallback g_videoCallback = nullptr;
AudioCallback g_audioCallback = nullptr;
uint16_t* g_videoBuffer = nullptr;  // RGB565 format
uint8_t* g_audioBuffer = nullptr;
uint32_t g_inputState = 0;

// Internal state
static bool g_frameReady = false;
static bool g_emulating = false;

// Frame timing
static constexpr double FRAME_TIME = 1.0 / AUDIO_FRAMES_PER_SECOND;

// Video buffer is 240x160 pixels in RGB565 format (2 bytes per pixel)
static const int VIDEO_WIDTH = GBA_WIDTH;
static const int VIDEO_HEIGHT = GBA_HEIGHT;
static const int VIDEO_BUFFER_SIZE = VIDEO_WIDTH * VIDEO_HEIGHT * 2;  // 2 bytes per pixel for RGB565


void updateColorMapping(bool isLcdMode) {
    switch (systemColorDepth) {
        case 16: {
            for (int i = 0; i < 0x10000; i++) {
                systemColorMap16[i] = ((i & 0x1f) << systemRedShift) |
                                    (((i & 0x3e0) >> 5) << systemGreenShift) |
                                    (((i & 0x7c00) >> 10) << systemBlueShift);
            }
        } break;
        case 24:
        case 32: {
            for (int i = 0; i < 0x10000; i++) {
                systemColorMap32[i] = ((i & 0x1f) << systemRedShift) |
                                    (((i & 0x3e0) >> 5) << systemGreenShift) |
                                    (((i & 0x7c00) >> 10) << systemBlueShift);
            }
        } break;
    }
}

void systemSendScreen() {
    systemDrawScreen();
    g_frameReady = true;
}

void systemDrawScreen() {
    if (!g_videoBuffer || !g_pix) {
        printf("systemDrawScreen: buffers not ready - g_videoBuffer=%p g_pix=%p\n", 
               (void*)g_videoBuffer, (void*)g_pix);
        return;
    }
    
    // Get rid of the first line and the last row
    for (int y = 0; y < VIDEO_HEIGHT; y++) {
        uint32_t* srcLine = (uint32_t*)(g_pix + ((y + 1) * (VIDEO_WIDTH + 1) * 4));
        uint16_t* dstLine = g_videoBuffer + (y * VIDEO_WIDTH);
        
        for (int x = 0; x < VIDEO_WIDTH; x++) {
            uint32_t color = srcLine[x + 1];  // Skip padding pixel
            
            // Convert from RGB888 to RGB565
            uint8_t r = (color >> 16) & 0xFF;
            uint8_t g = (color >> 8) & 0xFF;
            uint8_t b = color & 0xFF;
            
            // Convert to 5-6-5 format
            uint16_t r5 = r >> 3;
            uint16_t g6 = g >> 2;
            uint16_t b5 = b >> 3;
            
            uint16_t rgb565 = (r5 << 11) | (g6 << 5) | b5;
            dstLine[x] = rgb565;
        }
    }
    
    // Notify Swift through callback
    if (g_videoCallback) {
        g_videoCallback(reinterpret_cast<const uint8_t*>(g_videoBuffer), VIDEO_BUFFER_SIZE);
    } else {
        printf("systemDrawScreen: Warning - no video callback registered\n");
    }
    
    // Signal frame completion
    g_frameReady = true;
}

void systemOnWriteDataToSoundBuffer(const uint16_t* finalWave, int length) {
    if (g_audioCallback && g_audioBuffer) {
        memcpy(g_audioBuffer, finalWave, length);
        g_audioCallback(g_audioBuffer, length);
    }
}

uint32_t systemReadJoypad(int which) {
    return g_inputState;
}

// Implementation of the bridge functions
void GBAInitialize(VideoCallback videoCallback, AudioCallback audioCallback) {
    g_videoCallback = videoCallback;
    g_audioCallback = audioCallback;
    
    auto allocateBuffer = [](uint8_t*& buffer, size_t size) -> bool {
        buffer = (uint8_t*)calloc(1, size);
        return buffer != nullptr;
    };
    
    if (!g_bios && allocateBuffer(g_bios, SIZE_BIOS)) {
        memcpy(g_bios, myROM, SIZE_BIOS);
    }
    
    if (!g_rom) allocateBuffer(g_rom, SIZE_ROM);
    if (!g_internalRAM) allocateBuffer(g_internalRAM, SIZE_IRAM);
    if (!g_workRAM) allocateBuffer(g_workRAM, SIZE_WRAM);
    if (!g_paletteRAM) allocateBuffer(g_paletteRAM, SIZE_PRAM);
    if (!g_vram) allocateBuffer(g_vram, SIZE_VRAM);
    if (!g_oam) allocateBuffer(g_oam, SIZE_OAM);
    if (!g_ioMem) allocateBuffer(g_ioMem, SIZE_IOMEM);
    if (!g_pix) allocateBuffer(g_pix, SIZE_PIX);
    
    systemColorDepth = 32;
    systemRedShift = 19;
    systemGreenShift = 11;
    systemBlueShift = 3;
    RGB_LOW_BITS_MASK = 0x010101;
    
    for (int i = 0; i < 0x10000; i++) {
        systemColorMap32[i] = ((i & 0x1f) << systemRedShift) |
                            (((i & 0x3e0) >> 5) << systemGreenShift) |
                            (((i & 0x7c00) >> 10) << systemBlueShift);
        systemColorMap16[i] = i;
    }
    
    coreOptions.skipBios = true;
    coreOptions.useBios = 0;
    coreOptions.cpuSaveType = 0;
    coreOptions.layerSettings = 0xFF00;
    coreOptions.layerEnable = 0xFF00;
    coreOptions.rtcEnabled = true;
    
    flashInit();
    
    soundInit();
    soundSetSampleRate(AUDIO_SAMPLE_RATE);
    soundReset();
    soundSetVolume(0.8f);
    soundSetEnable(0x3ff);
    soundResume();
    
    CPUInit(nullptr, false);
    CPUReset();
    
    g_emulating = true;
}

void updateRomSettings(const char* romPath, int detectedSaveType, int detectedFlashSize, bool detectedRtc) {
    char gameID[5] = {0};
    if (g_rom) {
        memcpy(gameID, g_rom + 0xAC, 4);
        gameID[4] = '\0';
    }
    
    int saveType = detectedSaveType;
    int flashSize = detectedFlashSize;
    bool rtcEnabled = detectedRtc;
    bool mirroringEnabled = false;
    bool settingsFound = false;
    
    const char* bundlePath = getBundleResourcePath();
    if (bundlePath) {
        char iniPath[1024];
        std::snprintf(iniPath, sizeof(iniPath), "%s/vba-over.ini", bundlePath);
        std::FILE* fp = std::fopen(iniPath, "r");
        
        if (fp) {
            char line[256];
            bool inGameSection = false;
            
            while (std::fgets(line, sizeof(line), fp)) {
                char* newline = std::strchr(line, '\n');
                if (newline) *newline = 0;
                if (line[0] == '#' || line[0] == 0) continue;
                
                if (line[0] == '[') {
                    char sectionID[5] = {0};
                    std::sscanf(line, "[%4[^]]", sectionID);
                    if (std::strcmp(sectionID, gameID) == 0) {
                        inGameSection = true;
                        settingsFound = true;
                        continue;
                    } else {
                        inGameSection = false;
                    }
                }
                
                if (inGameSection) {
                    if (std::strncmp(line, "saveType=", 9) == 0) {
                        saveType = std::atoi(line + 9);
                    }
                    else if (std::strncmp(line, "flashSize=", 10) == 0) {
                        flashSize = std::atoi(line + 10);
                    }
                    else if (std::strncmp(line, "rtcEnabled=", 11) == 0) {
                        rtcEnabled = std::atoi(line + 11) != 0;
                    }
                    else if (std::strncmp(line, "mirroringEnabled=", 17) == 0) {
                        mirroringEnabled = std::atoi(line + 17) != 0;
                    }
                }
            }
            
            std::fclose(fp);
        }
    }
    
    coreOptions.saveType = saveType;
    
    flashInit();
    flashSetSize(flashSize);
    g_flashSize = flashSize;
    flashReset();
    
    rtcEnable(true);
    rtcEnableRumble(false);
    
    coreOptions.mirroringEnable = mirroringEnabled;
    if (mirroringEnabled) {
        doMirroring(true);
    }
}

bool GBALoadGame(const char* path) {
    if (!path) return false;
    
    std::unique_ptr<char[]> romData;
    size_t fileSize;
    
    {
        std::FILE* fp = std::fopen(path, "rb");
        if (!fp) return false;
        
        std::fseek(fp, 0, SEEK_END);
        fileSize = std::ftell(fp);
        std::fseek(fp, 0, SEEK_SET);
        
        romData = std::make_unique<char[]>(fileSize);
        if (!romData) {
            std::fclose(fp);
            return false;
        }
        
        if (std::fread(romData.get(), 1, fileSize, fp) != fileSize) {
            std::fclose(fp);
            return false;
        }
        std::fclose(fp);
    }
    
    int size = CPULoadRomData(romData.get(), fileSize);
    if (size <= 0) return false;
    
    // Update color mapping first
    updateColorMapping(false);
    
    flashDetectSaveType(size);
    int detectedSaveType = coreOptions.saveType;
    int detectedFlashSize = g_flashSize;
    bool detectedRtc = coreOptions.rtcEnabled;
    
    updateRomSettings(path, detectedSaveType, detectedFlashSize, detectedRtc);
    
    soundInit();
    soundSetSampleRate(AUDIO_SAMPLE_RATE);
    soundReset();
    
    CPUInit(nullptr, false);
    GBASystem.emuReset();
    
    g_emulating = true;
    return true;
}

void GBAShutdown() {
    g_emulating = false;
}

void GBACleanup() {
    GBASystem.emuCleanUp();
    soundShutdown();
}

void GBARunFrame(bool processVideo) {
    if (!g_emulating) return;
    
    g_frameReady = false;
    int frameAttempts = 0;
    const int MAX_ATTEMPTS = 100;
    
    while (!g_frameReady && frameAttempts < MAX_ATTEMPTS && g_emulating) {
        GBASystem.emuMain(GBASystem.emuCount);
        frameAttempts++;
    }
}

double GBAGetFrameTime() {
    return 1.0 / AUDIO_FRAMES_PER_SECOND;
}

uint32_t GBAGetAudioFrameLength() {
    return AUDIO_SAMPLES_PER_FRAME;
}

void GBAActivateInput(int input) {
    g_inputState |= input;
}

void GBADeactivateInput(int input) {
    g_inputState &= ~input;
}

void GBAResetInputs() {
    g_inputState = 0;
}

void GBASetVideoBuffer(uint8_t* buffer) {
    g_videoBuffer = reinterpret_cast<uint16_t*>(buffer);
}

void GBASetAudioBuffer(uint8_t* buffer) {
    g_audioBuffer = buffer;
}

const uint8_t* GBAGetVideoBuffer() {
    return reinterpret_cast<const uint8_t*>(g_videoBuffer);
}

const uint8_t* GBAGetAudioBuffer() {
    return g_audioBuffer;
}

bool GBAddCheatCode(const char* cheatCode, const char* type)
{
    std::string cheatCodeStr(cheatCode);
    std::istringstream stream(cheatCodeStr);
    std::string line;

    while (std::getline(stream, line))
    {
        // Remove leading/trailing whitespace
        line.erase(0, line.find_first_not_of(" \t\r\n"));
        line.erase(line.find_last_not_of(" \t\r\n") + 1);

        // Validate: must only contain hex digits and spaces
        for (char c : line)
        {
            if (!isxdigit(c) && c != ' ')
            {
                return false;
            }
        }

        if (strcmp(type, "ActionReplay") == 0 || strcmp(type, "GameShark") == 0)
        {
            std::string sanitizedCode;
            for (char c : line)
            {
                if (c != ' ') sanitizedCode += c;
            }

            if (sanitizedCode.length() != 16)
            {
                return false;
            }

            cheatsAddGSACode(sanitizedCode.c_str(), "code", true);
        }
        else if (strcmp(type, "CodeBreaker") == 0)
        {
            if (line.length() != 13)
            {
                return false;
            }

            cheatsAddCBACode(line.c_str(), "code");
        }
        else
        {
            // Unknown type
            return false;
        }
    }

    return true;
}

void GBAResetCheats()
{
    cheatsDeleteAll(true);
}



#pragma clang diagnostic pop

