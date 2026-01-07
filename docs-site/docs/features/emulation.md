---
title: Emulation
description: Set up retro gaming on your handheld
---

# Emulation

Play classic games from retro consoles on your gaming handheld.

---

## EmuDeck: The All-in-One Solution

EmuDeck is the recommended way to set up emulation. It:

- Downloads and configures emulators automatically
- Sets optimal settings for your device
- Organizes your ROM library
- Adds games to Steam with artwork
- Configures controller mappings and hotkeys

### Enable EmuDeck

=== "Steam Deck"

    ```yaml
    install_emudeck: true
    emulation_storage: "sdcard"  # Recommended - save internal space
    ```

=== "ROG Ally"

    ```yaml
    install_emulation: true
    install_emudeck: true
    ```

### Patreon/Early Access Version

If you have EmuDeck Patreon access, place your installer in:

```
private/scripts/EmuDeck EA SteamOS.desktop.download  # Steam Deck
private/scripts/EmuDeck EA Windows.bat               # ROG Ally
```

Bootible will use the EA version automatically.

### After Bootible Runs

EmuDeck requires interactive setup:

1. Switch to Desktop Mode (Steam Deck) or open EmuDeck (Windows)
2. Run the EmuDeck installer
3. Choose **Easy Mode** (recommended) or **Custom Mode**
4. Select which emulators to install
5. Wait for download and configuration

---

## Storage Location

### Steam Deck

| Option | Use When |
|--------|----------|
| `emulation_storage: "auto"` | SD card if present, else internal |
| `emulation_storage: "sdcard"` | Always use SD card |
| `emulation_storage: "internal"` | Always use internal storage |

**Recommendation:** Use SD card. ROMs and saves can use 100GB+.

### ROG Ally

Configure paths in your config:

```yaml
games_path: "D:\\Games"          # Secondary drive
roms_path: "D:\\Emulation\\ROMs"
bios_path: "D:\\Emulation\\BIOS"
```

---

## ROM Organization

EmuDeck creates a standard folder structure:

```
Emulation/
├── roms/
│   ├── gc/           # GameCube
│   ├── n64/          # Nintendo 64
│   ├── nds/          # Nintendo DS
│   ├── nes/          # NES
│   ├── ps2/          # PlayStation 2
│   ├── psp/          # PlayStation Portable
│   ├── snes/         # Super Nintendo
│   ├── switch/       # Nintendo Switch
│   └── wii/          # Wii
├── bios/             # BIOS files
├── saves/            # Save files
└── states/           # Save states
```

### Adding ROMs

1. Copy ROMs to the appropriate folder
2. Run **Steam ROM Manager** (in EmuDeck tools)
3. Click **Preview** to see what will be added
4. Click **Save to Steam**
5. Restart Steam to see your games

---

## Recommended ROM Formats

Use compressed formats to save space:

| System | Best Format | Notes |
|--------|-------------|-------|
| **GameCube** | .rvz | 50-70% smaller than ISO |
| **Wii** | .rvz | 50-70% smaller than ISO |
| **PS1** | .chd | 60-70% smaller than BIN/CUE |
| **PS2** | .chd | 50-60% smaller than ISO |
| **PSP** | .cso | 30-50% smaller than ISO |
| **Dreamcast** | .chd | 60-70% smaller |
| **Saturn** | .chd | 60-70% smaller |
| **Cartridge systems** | .zip | Most emulators support zipped ROMs |

### Converting ROMs

**CHDMAN** (for CHD conversion):
```bash
chdman createcd -i game.cue -o game.chd
```

**Dolphin** (for RVZ conversion):
Right-click game > Convert File > RVZ

---

## BIOS Files

Some systems require BIOS files from your own consoles:

| System | Required BIOS |
|--------|---------------|
| **PS1** | `scph1001.bin` or similar |
| **PS2** | Various (check PCSX2 docs) |
| **Dreamcast** | `dc_boot.bin`, `dc_flash.bin` |
| **Saturn** | `saturn_bios.bin` |
| **3DO** | `panafz10.bin` |

Place BIOS files in `Emulation/bios/`.

!!! warning "Legal Note"
    You must dump BIOS files from consoles you own. We cannot provide BIOS files.

---

## Hotkeys

EmuDeck configures standard hotkeys:

### RetroArch (Most Systems)

| Action | Hotkey |
|--------|--------|
| Quick Save | Select + R1 |
| Quick Load | Select + L1 |
| Fast Forward | Select + R2 |
| Rewind | Select + L2 |
| Exit Game | Select + Start (hold) |
| RetroArch Menu | L3 + R3 |

### Standalone Emulators

| Emulator | Exit Hotkey |
|----------|-------------|
| **Dolphin** | Select + Start |
| **PCSX2** | Select + Start |
| **RPCS3** | Close window |
| **Yuzu/Ryujinx** | Close window |

---

## System-Specific Tips

### Nintendo Switch (Yuzu/Ryujinx)

**Requirements:**

- `prod.keys` and `title.keys` from your Switch
- Firmware files (optional, some games need it)
- Powerful hardware (especially for RPCS3)

**Steam Deck Performance:**

- 720p/30fps for most games
- Some games like Zelda: Tears of the Kingdom are demanding
- Use FSR or in-game resolution scaling

### PlayStation 3 (RPCS3)

**Requirements:**

- PS3 firmware (from Sony's website)
- Decrypted games (or decrypt with your keys)

**Performance:**

- Steam Deck: Limited to simpler games
- ROG Ally: Better, but still demanding
- Many games are playable with tweaks

### PlayStation 2 (PCSX2)

**Excellent compatibility.** Most games work great on both devices.

**Tips:**

- Use hardware rendering when possible
- Upscale to 2x-3x native for sharper graphics
- Some games need software rendering

### Nintendo 64

**Multiple emulator options:**

| Emulator | Pros | Cons |
|----------|------|------|
| **Mupen64Plus** | High compatibility | Some games need tweaks |
| **ParaLLEl** | Accurate | More demanding |

Most games work great with default settings.

---

## Steam ROM Manager

Adds emulated games to your Steam library with artwork.

### Using Steam ROM Manager

1. Launch **Steam ROM Manager** from EmuDeck
2. Select which parsers (systems) to use
3. Click **Preview** to see games and artwork
4. Click **Save to Steam**
5. **Close Steam ROM Manager**
6. **Restart Steam** to see games

### Fixing Missing Artwork

1. In Preview, click on game with missing art
2. Click **Fix** to search SteamGridDB
3. Choose alternative artwork
4. Save to Steam

### Custom Categories

Steam ROM Manager creates categories like:

- Nintendo GameCube
- Sony PlayStation 2
- etc.

You can customize these in the parser settings.

---

## Performance Tips

### Steam Deck

1. **Use 40Hz/40fps lock** - Better battery, feels smooth
2. **Enable FSR** - If supported by emulator
3. **Per-game TDP limits** - Use PowerTools Decky plugin
4. **Shader cache** - Let games compile shaders before judging performance

### ROG Ally

1. **Turbo Mode** - For demanding emulators
2. **RTSS framerate limit** - Match your target fps
3. **RSR (AMD scaling)** - For better performance at lower resolution
4. **Close background apps** - More RAM for emulation

---

## Decky Plugins for Emulation

=== "Steam Deck Only"

    | Plugin | Purpose |
    |--------|---------|
    | **PowerTools** | Per-game TDP and GPU limits |
    | **SteamGridDB** | Fix missing game artwork |
    | **ProtonDB Badges** | N/A for emulation, but useful |

---

## Troubleshooting

### Games Not Appearing in Steam

1. Did you run Steam ROM Manager?
2. Did you click "Save to Steam"?
3. Did you restart Steam?
4. Check ROM folder path matches parser

### Black Screen on Launch

1. Check BIOS files are present
2. Verify ROM isn't corrupted
3. Try different emulator backend
4. Check emulator logs for errors

### Poor Performance

1. Lower resolution/upscaling
2. Disable enhancements (anti-aliasing, etc.)
3. Use different backend (Vulkan vs OpenGL)
4. Ensure running on dGPU (Ally)

### Controller Not Working

1. Run EmuDeck's controller configuration
2. Check Steam Input settings
3. Some games need specific controller layout
4. Reset to defaults in emulator
