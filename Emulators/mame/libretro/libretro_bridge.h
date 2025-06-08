#ifndef LIBRETRO_BRIDGE_H
#define LIBRETRO_BRIDGE_H

#include <stdbool.h>

bool lr_load_game(const char *romPath);
void lr_run_frame(void);
const void *lr_get_video_buffer(void);
int lr_get_width(void);
int lr_get_height(void);
void lr_set_input(int port, int id, bool pressed);
void lr_unload_game(void);

#endif
