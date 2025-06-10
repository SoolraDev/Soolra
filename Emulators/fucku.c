#include "libretro.h"

// Create a dummy function that references at least one retro_* symbol
void force_link_retro_core(void) {
    void *dummy = (void *)&retro_load_game;
    dummy = (void *)&retro_init;
    (void)dummy;
}
