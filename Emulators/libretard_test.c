#include <stdio.h>
#include "libretro.h"

void test_libretro_core_loaded() {
    if (&retro_init && &retro_set_environment && &retro_load_game && &retro_run) {
        printf("✅ Libretro core functions are present\n");
    } else {
        printf("❌ Libretro core functions are missing or not linked\n");
    }
}
