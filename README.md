# Soolra

Soolra is a multi-system game emulator designed for modern Apple platforms, bringing classic gaming to your devices with a beautiful, native interface. Visit [soolra.com](https://soolra.com) to learn more. The app is specifically designed to work with the Soolra Bluetooth Controller for the optimal gaming experience.

## License

Because Soolra incorporates emulator cores that are GPL-licensed, this project must be released under the GNU General Public License version 2.0 (GPLv2). Nevertheless, for the portions of code that we have personally created, I grant explicit permission to use, modify, and redistribute that code freely, with or without crediting me, and without any legal repercussions. The only exception to this permission is if you intend to publish your derivative work on the Apple App Store - in such cases, you must obtain explicit written consent from me first. All third-party dependencies and emulator cores continue to be governed by their respective original licenses.

For the complete GPLv2 license text, see the [LICENSE](LICENSE) file.

## Features

- Game Boy Advance (GBA) emulation
- Nintendo Entertainment System (NES) emulation
- Native SwiftUI interface
- Modern UI/UX design
- Custom audio implementation

## Building from Source

### Prerequisites

- Xcode 15.0 or later
- macOS 14.0 or later for development
- iOS/iPadOS 17.0 or later for deployment
- C++ compiler with C++17 support
- CMake (for building emulator cores)
- SDL2 2.30.11 (install via `brew install sdl2` to ensure it's in your Mac's include search path)

### Build Instructions

1. Clone or download this repository.

2. Open `SOOLRA.xcodeproj` in Xcode

3. Select your target device/simulator

4. Change the Team in Xcode to your own Apple Developer account:
   - Select the project in the navigator
   - Select the `SOOLRA` target
   - Under Signing & Capabilities, change the Team to your developer account

5. Build and run the project (⌘R)

### Project Structure

- `Emulators/` - C / C++ emulator core implementations
  - `gba/` - Game Boy Advance emulation core
    - `SoolraGBABridge` - C++ bridge between GBA core and Swift
    - `SoolraSoundDriver` - Custom audio implementation for GBA
    - Core components for CPU, memory, graphics, and timing emulation
  - `nes/` - NES emulation core
    - `SoolraNESBridge` - C++ bridge between NES core and Swift
    - Components for PPU (Picture Processing Unit)
    - CPU emulation and memory management
    - Audio Processing Unit (APU) implementation
- `SoolraConsole/` - Main iOS/macOS application
  - `Core/` - Swift bridges and core functionality
    - `ConsoleCores/GBA` - Swift-side GBA implementation
      - `GBACore` - Main GBA emulation coordinator
      - `GBARenderer` - SwiftUI-based rendering
      - `GBABridge` - Swift bridge to C++ core
    - `ConsoleCores/NES` - Swift-side NES implementation
      - `NESCore` - Main NES emulation coordinator
      - `NESRenderer` - SwiftUI-based rendering
      - `NESBridge` - Swift bridge to C++ core
      - `NESAudioMaker` - Audio processing and output
  - `View/` - SwiftUI views and view models
  - `Extension/` - Minor Swift extensions and utilities and views

## Source Code Notice

As required by GPLv2, any modifications to this code must be made available under the same license terms. This includes:

1. All modified source code must be made available
2. Clear documentation of changes must be provided
3. The original copyright notice must be preserved
4. The same license terms must be applied to derivative works

## Disclaimer

All game ROMs must be legally obtained. The developers do not endorse or promote piracy.

## Contact

Visit [soolra.com](https://soolra.com) for more information. 