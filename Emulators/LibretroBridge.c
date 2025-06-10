// LibretroBridge.c

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>

#include "libretro.h"

__attribute__((used))
static void (*force_link_retro_init)(void) = retro_init;

__attribute__((used))
static bool (*force_link_retro_load_game)(const struct retro_game_info *) = retro_load_game;

__attribute__((used))
static void (*force_link_retro_run)(void) = retro_run;

__attribute__((used)) static void *dummy_link[] = {
  (void *)retro_init,
  (void *)retro_load_game,
  (void *)retro_run,
  (void *)retro_set_environment,
  (void *)retro_set_video_refresh
};
__attribute__((used)) static void *force_link[] = {
    (void *)retro_init,
    (void *)retro_load_game,
    (void *)retro_set_environment,
    (void *)retro_run
};
__attribute__((used)) void *keep_link_symbols[] = {
    (void *)retro_init,
    (void *)retro_load_game,
    (void *)retro_run,
    (void *)retro_set_environment,
    (void *)retro_get_system_info
};
extern void retro_init(void) __attribute__((visibility("default")));

extern void retro_run(void);

void test_core_symbols() {
    printf("retro_init = %p\n", retro_init);
    printf("retro_run = %p\n", retro_run);
}


// === Callback implementations ===

bool retro_environment_cb(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            *(bool *)data = false;
            return true;

        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_LIBRETRO_PATH:
            *(const char **)data = NULL;
            return true;

        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            return true;

        default:
            return false;
    }
}


void retro_video_refresh_cb(const void *data, unsigned width, unsigned height, size_t pitch) {
    printf("Video callback: %ux%u\n", width, height);
}

void retro_audio_sample_cb(int16_t left, int16_t right) {
    (void)left; (void)right;
}

size_t retro_audio_sample_batch_cb(const int16_t *data, size_t frames) {
    return frames;
}

void retro_input_poll_cb(void) {}

int16_t retro_input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
    return 0;
}

// === Your bridge functions ===

void libretro_initialize_core() {
    // ✅ Step 1: Set all the callbacks BEFORE calling retro_init
    retro_set_environment(retro_environment_cb);
    retro_set_video_refresh(retro_video_refresh_cb);
    retro_set_audio_sample(retro_audio_sample_cb);
    retro_set_audio_sample_batch(retro_audio_sample_batch_cb);
    retro_set_input_poll(retro_input_poll_cb);
    retro_set_input_state(retro_input_state_cb);

    // ✅ Step 2: NOW it is safe to initialize the core
    retro_init();

    // ✅ Step 3: Optionally print system info
    struct retro_system_info info;
    retro_get_system_info(&info);
    if (info.library_name && info.library_version) {
        printf("✅ Core loaded: %s (%s)\n", info.library_name, info.library_version);
    } else {
        printf("⚠️  Core info not available\n");
    }

    printf("Core expects: %s\n", info.valid_extensions);
    printf("retro_load_game = %p\n", retro_load_game);
}


bool libretro_load_game(const char *rom_path) {
    struct retro_game_info game_info = {
        .path = rom_path,
        .data = NULL,
        .size = 0,
        .meta = NULL
    };
    printf("Calling retro_load_game: ptr = %p, path = %s\n", retro_load_game, rom_path);
    return retro_load_game(&game_info);
}

//bool libretro_load_game(const char *rom_path) {
//    FILE *fp = fopen(rom_path, "rb");
//    if (!fp) {
//        printf("❌ Failed to open ROM file: %s\n", rom_path);
//        return false;
//    }
//
//    fseek(fp, 0, SEEK_END);
//    long size = ftell(fp);
//    rewind(fp);
//
//    void *buffer = malloc(size);
//    if (!buffer) {
//        fclose(fp);
//        printf("❌ Failed to allocate memory for ROM\n");
//        return false;
//    }
//
//    fread(buffer, 1, size, fp);
//    fclose(fp);
//
//    struct retro_game_info game_info = {
//        .path = rom_path, // still helpful for metadata
//        .data = buffer,
//        .size = size,
//        .meta = NULL
//    };
//    printf("Loading game: %s\n", rom_path);
//    printf("Core expects: %s\n", info.valid_extensions);
//    printf("ROM size: %ld\n", size);
//    printf("retro_load_game = %p\n", retro_load_game);
//
//    bool result = retro_load_game(&game_info);
//    free(buffer); // optional: some cores take ownership, others don’t
//    return result;
//}

void libretro_run_one_frame() {
    retro_run();
}

void libretro_unload_core() {
    retro_unload_game();
    retro_deinit();
}
