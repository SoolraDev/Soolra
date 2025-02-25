//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

#include "SoolraNESBridge.hpp"

// Include Nestopia core API
#include "NstBase.hpp"
#include "NstApiEmulator.hpp"
#include "NstApiMachine.hpp"
#include "NstApiCartridge.hpp"
#include "NstApiInput.hpp"
#include "NstApiVideo.hpp"
#include "NstApiSound.hpp"

#include <iostream>
#include <fstream>
#include <vector>
#include <functional>
#include <memory>

// NES core components
namespace {
    // Constants
    constexpr size_t NES_WIDTH = Nes::Api::Video::Output::WIDTH;
    constexpr size_t NES_HEIGHT = Nes::Api::Video::Output::HEIGHT;
    constexpr size_t FRAME_BUFFER_SIZE = NES_WIDTH * NES_HEIGHT;
    constexpr size_t SAMPLE_RATE = 44100;
    constexpr size_t PAL_SAMPLES_PER_FRAME = SAMPLE_RATE / 50;  // 882 samples
    constexpr size_t NTSC_SAMPLES_PER_FRAME = SAMPLE_RATE / 60; // 735 samples
    
    std::unique_ptr<Nes::Api::Emulator> emulator;
    std::unique_ptr<Nes::Api::Machine> machine;
    std::unique_ptr<Nes::Api::Video> video;
    std::unique_ptr<Nes::Api::Sound> audio;
    std::unique_ptr<Nes::Api::Input> input;

    Nes::Api::Video::Output videoOutput;
    Nes::Api::Sound::Output audioOutput;
    Nes::Api::Input::Controllers controllers;

    // Fixed-size arrays instead of vectors
    alignas(16) uint16_t frameBuffer[FRAME_BUFFER_SIZE];
    alignas(16) uint16_t audioBuffer[PAL_SAMPLES_PER_FRAME]; // Use larger of the two sizes

    // Callbacks
    NESBufferCallback videoCallback;
    NESBufferCallback audioCallback;

    bool isInitialized = false;
}

// Internal callback handlers
bool videoLock(void*, Nes::Api::Video::Output&) { return true; }
void videoUnlock(void*, Nes::Api::Video::Output&) {
    if (videoCallback) {
        videoCallback(frameBuffer, FRAME_BUFFER_SIZE);
    }
}
bool audioLock(void*, Nes::Api::Sound::Output&) { return true; }
void audioUnlock(void*, Nes::Api::Sound::Output& output) {
    if (audioCallback) {
        audioCallback(audioBuffer,
                      machine->GetMode() == Nes::Api::Machine::PAL ?
                                             PAL_SAMPLES_PER_FRAME : NTSC_SAMPLES_PER_FRAME
                      );
    }
}

bool NES_IsPAL(void) {
    if (!machine) return false;  // Default to NTSC if not initialized
    return machine->GetMode() == Nes::Api::Machine::PAL;
}


// --- NES Setup Functions ---
void NES_Init() {
    std::cout << "[NESBridge] Initializing NES Core..." << std::endl;

    emulator = std::make_unique<Nes::Api::Emulator>();
    machine = std::make_unique<Nes::Api::Machine>(*emulator);
    video = std::make_unique<Nes::Api::Video>(*emulator);
    audio = std::make_unique<Nes::Api::Sound>(*emulator);
    input = std::make_unique<Nes::Api::Input>(*emulator);

    // Assign callbacks
    Nes::Api::Video::Output::lockCallback.Set(videoLock, nullptr);
    Nes::Api::Video::Output::unlockCallback.Set(videoUnlock, nullptr);
    Nes::Api::Sound::Output::lockCallback.Set(audioLock, nullptr);
    Nes::Api::Sound::Output::unlockCallback.Set(audioUnlock, nullptr);

    isInitialized = true;
    std::cout << "[NESBridge] Initialization complete." << std::endl;
}

bool NES_LoadROM(const char* romPath) {
    if (!isInitialized) {
        std::cerr << "[NESBridge] Error: NES Core not initialized!" << std::endl;
        return false;
    }

    std::cout << "[NESBridge] Loading ROM: " << romPath << std::endl;

    std::ifstream romFile(romPath, std::ios::in | std::ios::binary);
    if (!romFile.good()) {
        std::cerr << "[NESBridge] Error: Failed to open ROM file." << std::endl;
        return false;
    }

    if (NES_FAILED(machine->Load(romFile, Nes::Api::Machine::FAVORED_NES_NTSC))) {
        std::cerr << "[NESBridge] Error: Failed to load ROM." << std::endl;
        return false;
    }

    machine->SetMode(machine->GetDesiredMode());

    // Configure video output - simplified setup
    video->EnableUnlimSprites(true);
    videoOutput.pixels = frameBuffer;
    videoOutput.pitch = NES_WIDTH * sizeof(uint16_t);

    // Create a RenderState object to configure video rendering parameters
    Nes::Api::Video::RenderState renderState;
    renderState.filter = Nes::Api::Video::RenderState::FILTER_NONE;
    renderState.width = NES_WIDTH;
    renderState.height = NES_HEIGHT;
    renderState.bits.count = 16;
    renderState.bits.mask.r = 0xF800;
    renderState.bits.mask.g = 0x07E0;
    renderState.bits.mask.b = 0x001F;

    if (NES_FAILED(video->SetRenderState(renderState))) {
        std::cerr << "[NESBridge] Error: Failed to set render state." << std::endl;
        return false;
    }

    // Configure audio with optimized buffer management
    audio->SetSampleRate(SAMPLE_RATE);
    audioOutput.samples[0] = audioBuffer;
    audioOutput.length[0] = machine->GetMode() == Nes::Api::Machine::PAL ? 
                           PAL_SAMPLES_PER_FRAME : NTSC_SAMPLES_PER_FRAME;
    
    // Set to null and 0 if not using a circular buffer
    audioOutput.samples[1] = nullptr;
    audioOutput.length[1] = 0;

    // Configure controller
    input->ConnectController(0, Nes::Api::Input::PAD1);

    // Start emulation
    machine->Power(true);

    std::cout << "[NESBridge] ROM successfully loaded!" << std::endl;
    return true;
}

void NES_Shutdown() {
    if (!isInitialized) return;
    
    std::cout << "[NESBridge] Shutting down NES..." << std::endl;
    
    machine->Unload();
    machine->Power(false);
    
    videoCallback = nullptr;
    audioCallback = nullptr;
    
    isInitialized = false;
    
    std::cout << "[NESBridge] Shutdown complete." << std::endl;
}

void NES_RunFrame() {
    // Execute a single frame
    emulator->Execute(&videoOutput, &audioOutput, &controllers);
}

// --- Input Management ---
void NES_SetInput(int button) {
    controllers.pad[0].buttons |= button;
}

void NES_ClearInput(int button) {
    controllers.pad[0].buttons &= ~button;
}

void NES_ResetInputs() {
    controllers.pad[0].buttons = 0;
}

// --- Callback Management ---
void NES_SetVideoCallback(NESBufferCallback callback) {
    videoCallback = callback;
}

void NES_SetAudioCallback(NESBufferCallback callback) {
    audioCallback = callback;
}
