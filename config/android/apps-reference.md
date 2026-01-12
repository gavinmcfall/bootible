# Android Apps Reference

This document provides detailed information about apps available for Android gaming handhelds. For the configuration options, see `config.yml`.

---

## Winlator on Android Handhelds

Winlator is not "one emulator" — it's a **family of builds** wrapping Wine, Box64, and DirectX→Vulkan translation layers. Different variants exist to deal with **GPU drivers, performance quirks, and controller usability**.

### The Golden Rule

> **Install one Winlator variant at a time.**
>
> Test it, keep it if it works for your device, and uninstall the rest.

Running multiple variants simultaneously only creates confusion.

---

### Tier 1: Official & General-Purpose Builds

#### Winlator – Official
**Use for:** Baseline testing, Snapdragon / Adreno devices
This is the clean upstream build and the reference point for all others. Always start here.

#### Winlator Bionic / glibc
**Use for:** Adreno devices needing better compatibility
Includes alternative libc handling and tweaks that help with certain games and drivers.

#### Winlator CMOD
**Use for:** Controller-first handheld setups
Focuses on usability, presets, and input handling rather than raw performance.

#### Winlator Frost
**Use for:** "Try everything" compatibility
A performance-oriented mod with aggressive defaults and bundled tweaks. Good when a game fails on vanilla builds.

#### Winlator Ludashi
**Use for:** Input and UX quirks
Chosen by users who hit controller or window-management issues in other builds.

---

### Tier 2: Mali / Non-Adreno Builds

#### Winlator Vortex
**Use for:** Mali GPUs
Avoids reliance on Turnip (Adreno-focused) and instead uses Vortek-style paths.

#### WinlatorMali
**Use for:** Explicit Mali tuning
Ships with Mali-friendly defaults and environment variables.

#### Winlator Bionic + Vulkan Wrapper
**Use for:** Mali, Samsung Xclipse, or problematic Vulkan stacks
Best when standard Vulkan translation paths fail outright.

---

### Tier 3: Convenience Wrappers

#### GameHub Lite
**Use for:** Privacy-conscious users
Community fork with fewer telemetry concerns.

#### GameHub (official)
**Use for:** GameSir ecosystem users
More polished UI, but heavier and less flexible.

#### Steamlator
**Use for:** Steam-only workflows
Winlator with Steam pre-integrated — convenient, but less modular.

---

### Practical Advice

- **Adreno (Snapdragon):**
  - Start with Official → Bionic → CMOD
- **Mali (Mediatek / budget handhelds):**
  - Start with Vortex or WinlatorMali
- **One game failing?**
  - Try Frost or CMOD before giving up
- **Steam-only user?**
  - Steamlator is acceptable, but less flexible long-term

---

### What Winlator Is *Not*

- Not a replacement for native Android ports
- Not a "set and forget" emulator
- Not something you should update blindly

Treat it like a **toolchain**, not an app.

---

### Final Thought

If you remember nothing else:

> **Pick the build that matches your GPU, then stop.**

Winlator rewards restraint more than experimentation.

---

## Emulator Notes

### Multi-System Emulators

- **RetroArch**: The most comprehensive option with cores for nearly every system. Recommended as the primary multi-system solution.
- **Lemuroid**: Simpler RetroArch alternative with automatic game detection.

### Nintendo Emulators

- **melonDS**: Recommended for DS emulation, active development.
- **DraStic**: Legacy DS emulator, no longer updated but still functional.
- **Lime3DS**: Active fork for 3DS emulation.
- **Citra**: Legacy 3DS emulator, development halted.
- **Dolphin**: Gold standard for GameCube/Wii emulation.
- **Sudachi/Citron**: Switch emulation, hardware-dependent results.

### PlayStation Emulators

- **DuckStation**: Excellent PS1 emulation with enhancements.
- **PPSSPP**: Mature PSP emulator with good compatibility.
- **nethersx2**: Community fork of AetherSX2 for PS2 emulation.
- **AetherSX2**: Legacy PS2 emulator, development halted.
- **Vita3K**: PS Vita emulation, still maturing.

### Sega Emulators

- **Flycast**: Recommended for Dreamcast/Naomi.
- **Redream**: Alternative Dreamcast emulator with simpler setup.
- **Yaba Sanshiro 2**: Saturn emulation, hardware-dependent.

---

## Frontend Recommendations

For gaming handhelds, recommended frontends in order:

1. **Daijisho** - Modern, actively developed, good handheld support
2. **Pegasus Frontend** - Highly customizable, cross-platform
3. **ES-DE** - Comprehensive, desktop-style interface
4. **Arc Browser** - Clean, touch-friendly interface

---

## Cloud Gaming Services

Latency-sensitive. Best results with:

1. **Moonlight** - For NVIDIA GameStream (local network)
2. **Steam Link** - For Steam games (local/remote)
3. **Chiaki-ng** - For PlayStation Remote Play
4. **Parsec** - General-purpose game streaming

Cloud services (GeForce NOW, Xbox Cloud, Luna) require stable internet and are region-dependent.
