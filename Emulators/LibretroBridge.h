#ifndef LIBRETRO_BRIDGE_H
#define LIBRETRO_BRIDGE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Initializes the libretro core.
/// Must be called before any other libretro function.
void libretro_initialize_core(void);

/// Loads a ROM/game file at the given path.
/// Returns true if successful.
bool libretro_load_game(const char *rom_path);

/// Runs one emulation frame.
void libretro_run_one_frame(void);

/// Unloads the current game and shuts down the core.
void libretro_unload_core(void);

#ifdef __cplusplus
}
#endif

#endif /* LIBRETRO_BRIDGE_H */
