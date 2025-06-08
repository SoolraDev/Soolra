#include "libretro.h"
#include "libretro_bridge.h"
#include <string.h>

// Static callback holders
static retro_video_refresh_t video_cb = NULL;
static retro_input_poll_t input_poll_cb = NULL;
static retro_input_state_t input_state_cb = NULL;
static retro_audio_sample_batch_t audio_batch_cb = NULL;

static struct retro_game_info game;
static bool input_state[2][16];
static const void *frame_buffer = NULL;
static unsigned frame_width = 0;
static unsigned frame_height = 0;

// Frontend → Core hooks
void retro_set_environment(retro_environment_t cb) {}
void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) {}
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }

// Frontend calls
bool lr_load_game(const char *romPath) {
    retro_init();

    struct retro_game_info info = {
        .path = romPath,
        .data = NULL,
        .size = 0,
        .meta = NULL
    };

    return retro_load_game(&info);
}

void lr_run_frame(void) {
    if (input_poll_cb) input_poll_cb();
    retro_run(); // internally triggers video_cb
}

const void *lr_get_video_buffer(void) {
    return frame_buffer;
}

int lr_get_width(void) {
    return frame_width;
}

int lr_get_height(void) {
    return frame_height;
}

void lr_set_input(int port, int id, bool pressed) {
    input_state[port][id] = pressed;
}

void lr_unload_game(void) {
    retro_unload_game();
    retro_deinit();
}
