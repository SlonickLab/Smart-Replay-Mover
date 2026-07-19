<div align="center">

# 🎮 Smart Replay Mover

### A Zero-Config Clip Organizer for OBS Studio

  **Automatically organize your Replay Buffer clips, Recordings, and Screenshots into game-specific folders.**

  [![Version](https://img.shields.io/badge/version-2.10.0-00d4aa.svg)](https://github.com/SlonickLab/Smart-Replay-Mover/releases)
  [![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-0078D6.svg)]()
  [![OBS](https://img.shields.io/badge/OBS-28.x+-302E31.svg)](https://obsproject.com/)

  [Features](#-features) • [Installation](#-installation) • [How It Works](#-how-it-works) • [Configuration](#%EF%B8%8F-configuration) • [Custom Names](#-custom-names)
  <br>
  [Notifications](#-notification-system) • [FFmpeg Setup](#%EF%B8%8F-video-thumbnails-ffmpeg) • [Replay Buffer Pro](#-replay-buffer-pro-support) • [Troubleshooting](#-troubleshooting) • [Changelog](#-changelog)

  ---

  </div>

## ✨ Why Smart Replay Mover?

  Smart Replay Mover is a single **Lua script** that you add to OBS. It requires no Python, no libraries, and no external dependencies.

  Instead of only checking what OBS is recording, it uses OS-level APIs (Win32 FFI on Windows, `xprop`/`gdbus` on Linux) to detect the active window focus. This allows it to correctly sort files even if you're using Display Capture, Borderless Windowed modes, or playing games with strict anti-cheat.

  <div align="center">

  | ❌ Before | ✅ After |
  |-----------|----------|
  | All clips in one messy folder | Organized by game automatically |
  | Manual sorting after each session | Set and forget |
  | No idea when clip was saved | Visual + sound notifications |
  | Python scripts with broken dependencies | Single Lua file, zero setup |

  </div>

  ---

## 🚀 Features

### 🎯 Intelligent Game Detection

- **Cross-Platform Detection** — Uses Windows API (Win32 FFI) or Linux tools (`xprop`, `gdbus`) to detect the active game
- **1900+ Built-in Games** — Massive embedded database, no external files needed
- **Auto-Pattern Matching** — `minecraft_1.20.exe` → Saves to `Minecraft`
- **Anti-Cheat Compatible** — Window title fallback for protected games (Valorant, Fortnite, Sea of Thieves)
- **🌍 Any-Language Names** — Correct folders for Chinese, Japanese, Korean & Cyrillic game names via native Unicode (UTF-16) detection
- **🔍 Background Game Scanning** — Optional: detect games even when alt-tabbed to Discord (Windows)
- **Linux OBS Sources** — Scans `xcomposite`, PipeWire, and X11 capture sources
- **99.9% Accuracy** — Smart fallback chain ensures correct detection

### 🔔 Notification System

- **Visual Popup** — ShadowPlay-style dark popup with smooth fade animations (Windows)
- **🐧 Linux Notifications** — Uses `notify-send` for native desktop notifications
- **Smart Fullscreen Detection** — Popup in Borderless, sound-only in Exclusive Fullscreen
- **Custom Sound** — Use your own `.wav` notification sound (`paplay`/`pw-play` on Linux)
- **📏 Scaling** — 100–300% for 4K/HiDPI monitors
- **📍 Positioning** — Choose any corner: Top Right, Top Left, Bottom Right, Bottom Left
- **Click-through** — Popup doesn't block your game

### 📁 Organization

- **Replay Buffer** — Automatically organized
- **Regular Recordings** — Start/Stop recording support
- **Screenshots** — Optional organization
- **File Splitting** — Handles long recording segments correctly
- **🖼️ FFmpeg Thumbnails** — Optional cover art embedding for your clips (Windows & Linux)
- **🔌 Replay Buffer Pro Compatible** — Waits for the trim-after-save plugin to finish, then organizes the final trimmed clip

### 🛡️ Quality of Life

- **Anti-Spam Protection** — Deletes duplicate files from panic-pressing hotkeys
- **Case-Insensitive** — Won't create duplicate folders with different cases
- **Date Subfolders** — Optional monthly organization (2025-06/)
- **230+ Ignored Programs** — Won't confuse Discord, Chrome, launchers or utilities with games
- **⚡ Smart Save Hotkey** — Instant "Saving..." notification when pressing your custom hotkey
- **📂 No-Folder Mode** — Map a process to `/`, `\`, or `.` to keep files in OBS output root
- **📦 Import/Export** — Share your custom name mappings with one click
- **🔄 Auto-Update Check** — Notifies you when a new version is available

  ---

## 📥 Installation

### Windows

  1. **Download** the latest release from [Releases](https://github.com/SlonickLab/Smart-Replay-Mover/releases)

  2. **Extract** the ZIP archive
     > ⚠️ Do NOT load the .zip file directly into OBS

  3. **Move** `Smart_Replay_Mover.lua` to a permanent location (e.g., Documents)

  4. **Add to OBS:**
     - Open OBS Studio
     - Go to `Tools` → `Scripts`
     - Click `+` and select the `.lua` file

  5. **Done!** The script works immediately with default settings. No Python, no dependencies.

### 🐧 Linux

  1. **Download** and extract the same way
  2. **Add to OBS** the same way (`Tools` → `Scripts` → `+`)
  3. **Install dependencies** — run the included setup script:

  ```bash
  cd "For Linux"
  chmod +x install_linux_deps.sh
  ./install_linux_deps.sh
  ```

  The script auto-detects your package manager (apt, pacman, dnf, zypper, apk) and installs everything needed:

- `xprop` — game detection (X11)
- `notify-send` — desktop notifications
- `paplay` / `pw-play` — notification sound
- `ffmpeg` — video thumbnails
- Also checks for `gdbus` (KDE Wayland support)

  1. **Done!** The script auto-detects Linux — no configuration needed.

  > 💡 On **KDE Plasma (Wayland)**, game detection uses `gdbus` which is included with GNOME/KDE — no extra install needed.

  <details>
  <summary>Manual installation (if you prefer)</summary>

  | Package | Purpose | Install (Arch) | Install (Debian/Ubuntu) |
  |---------|---------|----------------|------------------------|
  | `xprop` | Game detection (X11) | `sudo pacman -S xorg-xprop` | `sudo apt install x11-utils` |
  | `notify-send` | Desktop notifications | `sudo pacman -S libnotify` | `sudo apt install libnotify-bin` |
  | `paplay` / `pw-play` | Notification sound | Usually pre-installed | Usually pre-installed |
  | `ffmpeg` | Video thumbnails | `sudo pacman -S ffmpeg` | `sudo apt install ffmpeg` |

  </details>

  ---

## 🔍 How It Works

  The script uses a multi-step detection chain to identify what you're playing. Each step is a fallback for the previous one:

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │  Priority 1: Custom Names (your rules — ALWAYS highest)        │
  │  Priority 2: Active process name (Win32 / xprop / gdbus)       │
  │  Priority 3: Built-in game database (1900+ games)              │
  │  Priority 4: Pattern matching (auto-clean process names)       │
  │  Priority 5: Window title fallback (anti-cheat bypass)         │
  │  Priority 6: OBS capture source names                          │
  │  Priority 7: Background game scan (optional, Windows only)     │
  │  Priority 8: Fallback folder (default: "Desktop")              │
  └─────────────────────────────────────────────────────────────────┘
  ```

  Every platform-specific code path is wrapped in `pcall()` — the script **never crashes** regardless of OS or settings.

  ---

## ⚙️ Configuration

  Click on the script in OBS Scripts window to access settings:

### 📁 File Naming

  | Setting | Description |
  |---------|-------------|
  | Add game prefix | Adds game name to filename (e.g., `CS2 - Replay 2025-06-15.mp4`) |
  | Fallback folder | Folder name when no game detected (default: `Desktop`) |

### 🎮 Custom Names (Highest Priority)

  | Setting | Description |
  |---------|-------------|
  | Game field | Process name, `+keywords`, or `*pattern*` to match |
  | Folder field | Target folder name (or `.` / `/` for no subfolder) |
  | Add button | Saves the new mapping |
  | Your mappings | Edit or delete existing rules |

### 💾 Backup

  | Setting | Description |
  |---------|-------------|
  | File path | Optional custom path for import/export |
  | Import | Load custom names from file |
  | Export | Save custom names to file |

### 🔄 Buffer Control

  | Setting | Description |
  |---------|-------------|
  | Auto-restart after save | Stops and restarts buffer after each save (prevents overlap) |
  | Auto-start on launch | Automatically starts Replay Buffer when OBS opens |
  | Smart Save Hotkey | Assign in OBS Settings → Hotkeys → "Smart Save Replay" for instant feedback |

### 🎬 Replay Buffer Pro

  | Setting | Description |
  |---------|-------------|
  | Mode | Auto-Detect (default — activates only when the plugin is installed), Always On, or Off |
  | Remove "_trimmed" suffix | Renames Replay Buffer Pro's trimmed clip back to a clean name while organizing (on by default) |

### 🗂️ Organization

  | Setting | Description |
  |---------|-------------|
  | Monthly subfolders | Creates `YYYY-MM` subfolders |
  | Organize screenshots | Also sort screenshots |
  | Organize recordings | Sort regular recordings (not just replays) |
  | Scan all processes | Detect background games when alt-tabbed (Windows only) |

### 🛡️ Spam Protection

  | Setting | Description |
  |---------|-------------|
  | Cooldown | Seconds between saves (prevents duplicates) |
  | Auto-delete | Automatically remove duplicate files |

### 🔔 Notifications

  | Setting | Description |
  |---------|-------------|
  | Show popup | Visual notification — Win32 overlay (Windows) or `notify-send` (Linux) |
  | Play sound | Audio notification (works in Fullscreen too) |
  | Scale % | Resize popup for 4K/HiDPI monitors, 100–300% (Windows) |
  | Position | Choose popup corner: Top Right, Top Left, Bottom Right, Bottom Left (Windows) |
  | Quiet Sound | Switch to `notification_sound_silent.wav` for softer alert |
  | Duration | How long popup stays visible (1–10 seconds) |
  | Test button | Preview notifications instantly from settings |

### 🔧 Tools & Debug

  | Setting | Description |
  |---------|-------------|
  | Debug mode | Show detailed detection messages in OBS Script Log |
  | OS Mode | Auto-Detect (default), Windows, or Linux — for testing cross-platform |

### 🎬 FFmpeg Thumbnails (Advanced)

  | Setting | Description |
  |---------|-------------|
  | Enable Thumbnails | Embed frame from video as cover art |
  | FFmpeg Path | Path to `ffmpeg.exe` (Windows) or `ffmpeg` (Linux) |
  | Thumbnail Offset | Time (sec) from end of video to grab the frame |

  ---

## 🎮 Custom Names

  Three powerful matching modes for any situation:

### Exact Match

  ```
  CS2 > Counter-Strike 2
  ```

  Maps process name directly to folder name. Simplest and fastest.

### Keywords Mode

  ```
  +Warhammer Marine > Space Marine 2
  ```

  Matches if **all** keywords are present (AND logic). Prefix with `+`.

### Contains Mode

  ```
  *Space Marine 2* > Space Marine 2
  ```

  Matches if text is found **anywhere** in process name or window title. Wrap in `*`.

  > 💡 **Pro Tip:** Contains mode is perfect for games with version numbers that change with updates!
  >
  > Example: `*Space Marine 2*` matches `Warhammer 40,000 Space Marine 2 CLIENT v11.2.799056`

### No-Folder Mode

  ```
  chrome > /
  discord > .
  ```

  Map a process to `/`, `\`, or `.` to keep files in the OBS output root without creating a subfolder. The game prefix is still added if enabled.

### Examples

  | Custom Name | What It Matches |
  |-------------|-----------------|
  | `r5apex > Apex Legends` | Process `r5apex.exe` → folder `Apex Legends` |
  | `+Warhammer Space > WH40K` | Any window containing both words |
  | `*Cyberpunk* > Cyberpunk 2077` | `Cyberpunk 2077 v2.1 Patch...` |
  | `*Sea of Thieves* > Sea of Thieves` | Works even with anti-cheat blocking process |
  | `chrome > /` | Chrome clips stay in OBS output root (no subfolder) |

  > ⚠️ **CRITICAL TIP:** When using `*pattern*`, you are matching the **WINDOW TITLE**, not the .exe name!
  >
  > - ❌ `*cs2*` → Won't work because the window is named "Counter-Strike 2" (doesn't contain "cs2").
  > - ✅ `*Counter-Strike*` → Works perfectly!
  > - ❌ `*FactoryGamesteam*` → Won't work because window is named "Satisfactory".
  > - ✅ `*Satisfactory*` → Works perfectly!

  The `*pattern*` mode matches the window title, which works even when anti-cheat blocks process detection!

  ---

## 🔔 Notification System

### Windows

  The script creates a native Win32 overlay window — a dark semi-transparent popup similar to NVIDIA ShadowPlay. It fades in/out smoothly and is completely click-through.

- **Borderless/Windowed** → visual popup + optional sound
- **Exclusive Fullscreen** → sound only (popup can't overlay fullscreen)

### 🐧 Linux

  Notifications use `notify-send` for visual alerts and `paplay`/`pw-play` for sound. Works with any desktop environment.

### 🔊 Custom Notification Sound

  1. Find a short sound file (1–2 seconds recommended)
  2. Convert to **WAV format** if needed
  3. Rename to `notification_sound.wav`
  4. Place in the same folder as the script:

  ```
  📁 Your Folder/
  ├── Smart_Replay_Mover.lua
  ├── notification_sound.wav          ← Normal sound
  └── notification_sound_silent.wav   ← Quiet sound (optional)
  ```

  1. Reload the script — done!

### 🔇 Quiet Sound Option
  
  If the standard sound is too loud, you can use a separate "quiet" sound file:
  
  1. Prepare a quieter sound file
  2. Name it `notification_sound_silent.wav`
  3. Place it in the same folder
  4. In script settings, check **"Use Quiet Sound"**
  
  Now you can toggle between the Normal and Quiet versions instantly! Works on both Windows and Linux.

  ---

## 📂 Output Structure

  The script creates this folder structure automatically:

  ```
  📁 Videos/
  ├── 📁 Counter-Strike 2/
  │   ├── CS2 - 2025-06-15 14-30-01.mp4
  │   └── CS2 - 2025-06-15 14-35-22.png
  │
  ├── 📁 Valorant/
  │   └── Valorant - 2025-06-16 20-10-55.mp4
  │
  ├── 📁 Space Marine 2/
  │   └── Space Marine 2 - 2025-06-17 18-45-00.mp4
  │
  ├── 📁 Minecraft/
  │   └── 2025-06/                    ← Optional date subfolder
  │       └── Minecraft - 2025-06-18 11-22-33.mp4
  │
  └── 📁 Desktop/                     ← Fallback folder
      └── Desktop - 2025-06-17 09-00-00.mp4
  ```

  ---

## ❓ Troubleshooting

### 🛑 Nothing happens when I test?
  
  **IMPORTANT:** The script detects the **Active Window** (what you are currently looking at).
  
- If you Alt-Tab to OBS to change settings → The script sees "OBS Studio".
- Since OBS is in the ignores list, the script does nothing.
  
  **How to Test Properly:**

  1. Set up your Custom Names.
  2. **Alt-Tab back into the game.**
  3. Wait 3–5 seconds.
  4. Save a Replay.
  5. Check the folder.

  ---

### Clips save to "Desktop" instead of game folder?

  Some games with **anti-cheat protection** (Easy Anti-Cheat, Vanguard, etc.) block the script from reading the process name. If the game isn't in our built-in list, it will fall back to "Desktop".

  **Solution:** Add a Custom Name mapping:

  1. Open OBS → Tools → Scripts → Click on the script
  2. In **CUSTOM NAMES** section, enter:
     - Game: `*Your Game Name*` (with asterisks)
     - Folder: `Your Game Name`
  3. Click **Add**

  **Examples:**

  | Game | Folder | Type |
  |------|--------|------|
  | `*Sea of Thieves*` | Sea of Thieves | Matches Window Title |
  | `*New World*` | New World | Matches Window Title |
  | `*PUBG*` | PUBG | Matches Window Title |

  > 💡 **CRITICAL TIP:** When using `*pattern*`, you are matching the **WINDOW TITLE**, not the .exe name!
  >
  > - ❌ `*cs2*` → Won't work because the window is named "Counter-Strike 2" (doesn't contain "cs2").
  > - ✅ `*Counter-Strike*` → Works perfectly!
  > - ❌ `*FactoryGamesteam*` → Won't work because window is named "Satisfactory".
  > - ✅ `*Satisfactory*` → Works perfectly!

  The `*pattern*` mode matches the window title, which works even when anti-cheat blocks process detection!

  ---

### 🐧 Linux: Notifications not showing?

  Make sure `notify-send` is installed:

  ```bash
  which notify-send
  # If missing: sudo apt install libnotify-bin (Ubuntu) or sudo pacman -S libnotify (Arch)
  ```

### 🐧 Linux: Sound not playing?

  Make sure `paplay` or `pw-play` is available, and `notification_sound.wav` is in the same folder as the script.

### 🐧 Linux: FFmpeg thumbnails not working?

- Check that FFmpeg path is correct (`ffmpeg` for PATH or `/usr/bin/ffmpeg` for absolute)
- Enable **Debug Mode** in Tools & Debug and check the OBS Script Log for errors
- Check file permissions for the video files

  ---

## 🎞️ Video Thumbnails (FFmpeg)

  Enhance your clip library by embedding high-quality cover art into your videos. This allows Windows Explorer (and tools like [Icaros](https://www.majorgeeks.com/files/details/icaros.html)) to display a frame from your gameplay as the file icon instead of a generic media player logo.

### Windows Setup

  1. Go to [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) (recommended Windows builds).
  2. Download the `ffmpeg-release-essentials.zip`.
  3. Extract it to a permanent folder (e.g., `C:\Program Files\ffmpeg`).
  4. In script settings → **FFmpeg Thumbnails** → Enable and browse to `ffmpeg.exe` (inside the `bin` folder).

### 🐧 Linux Setup

  1. Install via your package manager: `sudo apt install ffmpeg` or `sudo pacman -S ffmpeg`
  2. In script settings → set FFmpeg Path to `ffmpeg` or `/usr/bin/ffmpeg`

### ✨ How It Works

- **MKV files** — thumbnail attached as Matroska attachment (best for Icaros on Windows)
- **MP4 files** — thumbnail embedded as attached picture stream
- **Silent & Invisible** — FFmpeg runs completely in the background without popups
- **No Quality Loss** — Metadata is embedded without re-encoding your video
- **Cross-Platform** — Proper shell quoting on both Windows and Linux

  ---

## 🔌 Replay Buffer Pro Support

  Smart Replay Mover is fully compatible with [Replay Buffer Pro](https://github.com/JoshuaPotter/replay-buffer-pro) — the plugin that saves your replay buffer at custom lengths (15s / 30s / 5min…) and trims the file in the background without re-encoding.

  **How it works together:** when a replay is saved, the script no longer moves it instantly. Each save goes into a **deferred move queue** — the script watches the original file and the plugin's `_trimmed` file, waits until trimming is finished, and only then organizes the final clip into your game folder (removing the `_trimmed` suffix by default). While Replay Buffer Pro mode is active, spam protection switches to path-based deduplication: rapid saves of different durations are all kept, and **no files are ever auto-deleted**.

  **Setup:** none. Install the plugin, restart OBS, and the script auto-detects it — the Script Log will show `Replay Buffer Pro integration: ACTIVE (mode: auto)`. If your setup doesn't show that line, set **🎬 REPLAY BUFFER PRO → Mode** to **Always On** in the script settings.

  > 💙 Built with the blessing of Replay Buffer Pro's author — see [JoshuaPotter/replay-buffer-pro#23](https://github.com/JoshuaPotter/replay-buffer-pro/issues/23). If the plugin's file naming ever changes, its author will open an issue here so compatibility can be maintained.

  ---

## 📋 Changelog

### v2.10.0 — 🔌 Replay Buffer Pro Compatibility

- **🔌 Replay Buffer Pro Integration** — Full compatibility with the [Replay Buffer Pro](https://github.com/JoshuaPotter/replay-buffer-pro) plugin, built with its author's blessing ([JoshuaPotter/replay-buffer-pro#23](https://github.com/JoshuaPotter/replay-buffer-pro/issues/23)). Replays now go through a **deferred move queue**: the script waits for the plugin's background trim to finish, then organizes the final clip. New **🎬 REPLAY BUFFER PRO** settings group (Mode: Auto-Detect / Always On / Off).
- **✂️ Clean Names** — The `_trimmed` suffix the plugin leaves on clips is removed during organizing (optional, on by default).
- **🛡️ Smarter Spam Protection** — In Replay Buffer Pro mode duplicates are detected by file path, so rapid saves of different durations (15s/30s/60s hotkeys) are all kept — and files are never auto-deleted.
- **🛡️ Collision-Safe Naming** — New clips get a `name (2).mp4` suffix instead of silently overwriting an existing file with the same name in the target folder.
- **🐛 Crash-Safety** — The recording `file_changed` signal handler is now `pcall`-guarded like every other callback.

### v2.9.5 — 🔔 Notification Toggle Fix

- **🔔 Popup Toggle Fixed** — The visual popup now respects the **Show visual popup** setting. Previously it appeared on every save even when disabled (the setting was read but never checked on the display path); the sound notification was unaffected. Sound stays independently controlled by **Play sound**, and the **Test** button follows the same toggle. (Thanks @Htwm5, [Issue #25](https://github.com/SlonickLab/Smart-Replay-Mover/issues/25))
- **🖼️ Wallpaper Engine Ignored** — Added `wallpaperui` to the ignore list so Wallpaper Engine's interface isn't mistaken for a game.

### v2.9.4 — 🌍 Multi-Language Folder Names

- **🌍 Any-Language Folders** — Games with Chinese, Japanese, Korean, or Cyrillic names now create correctly-named folders instead of garbled "mojibake" (e.g. `苍蓝彼端`, not `ç»åºé¶æ`). Process detection and folder lookups now use native **Wide (UTF-16) Win32 APIs** (`GetModuleBaseNameW`, `QueryFullProcessImageNameW`, `FindFirstFileW`), so names are lossless regardless of your Windows language. (Surfaced by @YxlaGyb, [PR #24](https://github.com/SlonickLab/Smart-Replay-Mover/pull/24))
- **🧹 Code Health** — Reorganized ~95 globals into namespaced tables (`WIN` / `STATE` / `NOTIF`) to clear LuaJIT's 200-local-per-chunk limit the script had reached (199 → 110), leaving headroom for future features. Purely structural — no behavior change, every `pcall` crash-guard preserved.

### v2.9.3 — 📂 Split Recording Organization Fix

- **📂 Split Recording Fix** — Fixed a critical Lua variable scoping bug where split recordings were not organized into game folders. The `on_recording_file_changed()` signal handler was accessing a global variable instead of the local `current_recording_file`, causing stale paths from previous sessions to persist ([Issue #23](https://github.com/SlonickLab/Smart-Replay-Mover/issues/23))
- **📁 Advanced Output Fallback** — Added fallback for initial recording file path via `obs_output_get_settings()` when `get_last_file` returns empty (common with `adv_file_output`)
- **🛡️ Safety Net** — Signal handler now recovers previous file path from output settings when `current_recording_file` was never initialized

### v2.9.2 — 🔄 Replay Buffer Auto-Restart Reliability Fix

- **🔄 Large File Fix** — Fixed a race condition where the Replay Buffer would stay off after saving very large clips (>1GB). The script now uses an **adaptive delay** scaled to the file size (2s for ~200MB up to 45s for ~4GB), giving OBS enough time to stabilize internally before restarting ([Issue #22](https://github.com/SlonickLab/Smart-Replay-Mover/issues/22))
- **✅ Start Verification** — After restarting, the script now verifies the buffer is actually active and retries up to 3 times if OBS silently ignored the start call
- **🛡️ Safety Timeout** — 5-second safety timeout force-restarts the buffer if the expected stop event never fires
- **📂 Restart Independence** — Auto-restart logic now runs regardless of file path detection

### v2.9.1 — 🔔 Windows 11 Notification Fix & Update Status Reset

- **🔔 Win11 Notification Fix** — Notification popups now properly re-assert TOPMOST Z-order on window reuse, fixing invisible notifications on Windows 11
- **📦 Stale Update Status Fix** — Update status resets to neutral on every OBS launch, preventing users from seeing an outdated "✅ Up to date" indefinitely
- **🐛 Debug Logging** — Added exclusive fullscreen detection state logging for easier diagnostics

### v2.9.0 — 🐧 Linux Support & Cross-Platform Architecture

- **🐧 Linux Support** — Full cross-platform support! Game detection via `xprop` (X11) and `gdbus` (KDE/Wayland), notifications via `notify-send`, audio via `paplay`/`pw-play`. (PR by @zxsleebu, [#19](https://github.com/SlonickLab/Smart-Replay-Mover/issues/19))
- **🖥️ OS Mode Selector** — New dropdown in Tools & Debug: Auto-Detect, Windows, or Linux. Windows-only features auto-hide on Linux.
- **🛡️ Crash Prevention** — Every platform-specific code path wrapped in `pcall()`. Script never crashes regardless of OS mode mismatch.
- **🔧 FFI Consolidation** — All Windows API definitions merged into a single guarded block for maximum stability.
- **🎮 Linux OBS Sources** — Scans `xcomposite_input`, `pipewire-window-capture-source`, `xshm_input` and more.
- **🎵 Linux Audio** — Notification sound playback via `paplay` (PulseAudio) or `pw-play` (PipeWire).
- **🖥️ Adaptive UI** — Windows-only settings (Scan Processes, Scale, Position, Update Checker) auto-hide on Linux.
- **🎬 FFmpeg Thumbnails on Linux** — Proper shell quoting, path validation, and error logging for cross-platform FFmpeg support.

### v2.8.2

- **🔍 Background Game Detection** — Added an option to scan all running processes for a game if the active window isn't one. This serves as a smart fallback if you alt-tabbed to Discord or the desktop before saving a clip! (Feature request: @EndCod3r)
- **🛡️ 100% Anti-Cheat Safe** — The implementation uses zero-overhead, read-only `Toolhelp32Snapshot` APIs, rendering it completely invisible to anti-cheat systems.
- **🐛 Alt-Tab Detection Fix** — Fixed a logic flaw where alt-tabbing to an ignored process (like OBS) would previously bypass OBS Game Capture checks.

### v2.8.1 (Hotfix)

- **🛡️ CRITICAL FIX** — Smart Save Hotkey no longer crashes or freezes OBS ([Discussion #16](https://github.com/SlonickLab/Smart-Replay-Mover/discussions/16))
- **🧵 Thread-Safe Notifications** — All notification calls now go through a safe queue processed exclusively on one thread, eliminating cross-thread Win32 GDI deadlocks
- **⚡ Smart Skip** — On fast systems (NVMe/SSD), the intermediate "Saving..." is automatically skipped in favor of "Clip Saved" when save completes instantly
- **🐛 Detection Fix** — Fixed double `detect_game()` call during replay buffer save that could cause wrong folder assignment

<details>
<summary>View older versions</summary>

### v2.8.0

- **⚡ Smart Save Hotkey** — New OBS hotkey "Smart Save Replay" shows instant "Saving..." notification before the file is written, then the usual "Clip Saved" when done (Idea by rambam1120, [Issue #14](https://github.com/SlonickLab/Smart-Replay-Mover/issues/14))
- **📂 No-Folder Mode** — Map a process to `/`, `\`, or `.` to keep files in OBS output root without creating a subfolder (Idea by lemenegg)
- **🌍 Community-Driven Database** — The massive built-in database of 1800+ games is now available as a separate `games_database.json` file in the GitHub repository, making it super easy for the community to add new games via Pull Requests
- **🧹 Code Quality** — Cleaned up duplicate `ffi.cdef` type declarations for better stability

### v2.7.9

- **🐛 Detection Fix** — Fixed `is_ignored()` false positives (`"obs"` no longer matches `"observer"`, `"code"` no longer matches `"barcode"`)
- **📍 Notification Position** — Choose popup corner: Top Right, Top Left, Bottom Right, Bottom Left
- **▶️ Auto-Start Buffer** — Option to automatically start Replay Buffer when OBS launches (Idea by ReiDaTecnologia, [Issue #11](https://github.com/SlonickLab/Smart-Replay-Mover/issues/11))
- **🔧 Dynamic Version** — Log message now uses `VERSION` variable instead of hardcoded string

### v2.7.8

- **🔄 Auto-Restart Buffer** — Option to automatically restart buffer after save to prevent overlapping clips (Idea by VoidNW)
- **🛡️ Safe Logic** — Uses event-driven system to ensure file safety before restart
- **🛠️ Buffer Control** — New settings section for buffer management

### v2.7.7

- **📏 Notification Scaling** — Resize popup (100-300%) for 4K/HiDPI monitors
- **🔊 Quiet Sound Option** — Toggle for alternative silent sound file
- **🔘 Test Button** — Preview notifications instantly from settings

### v2.7.6

- **🛡️ Anti-Cheat Compatibility** — Fixed detection for protected games (ARC Raiders, THE FINALS) using advanced API fallback
- **🎮 445+ New Games** — Massive database expansion from Discord's game list and community sources
- **📈 1,900+ Games** — Total database now covers over 1,900 games

### v2.7.5

- **🔄 Auto Update Check** — Script now checks for updates automatically on load
- **📍 Status at Top** — Update status displayed at the very top of script properties
- **📥 Download Button** — Clickable button opens releases page directly in browser
- **🔄 Refresh Button** — Manual refresh to display update status after check completes
- **💬 Clearer Messages** — Improved status text like "🆕 New version available: vX.X.X"
- **🔗 Credits Link** — Added clickable GitHub link in script description

### v2.7.4

- **🔄 Update Checker** — Added a "Check for Updates" button to quickly see if a new version is out
- **❄️ Freeze Fix** — Implemented window reuse to prevent OBS hangs during high-stress events
- **⚙️ CPU Optimization** — Redraw throttling ensures notifications only render once per state
- **🎬 Recording Stability** — Added 0.5s safety delay during recording start initialization
- **📸 Screenshot Cache** — Added detection cache & throttle to handle rapid photo bursts
- **🧹 Memory Leak Fix** — Fixed background brush leaks during script reloads
- **📦 Cleanup** — Added missing timer disposal on script unload to prevent log errors
  
### v2.7.3 (Pull Request by zxsleebu)

- **🛡️ Critical Crash Fix** — Fixed the `lua51.dll` crash by switching to native `DefWindowProcA`
- **🎨 Safe Rendering** — New timer-based drawing system for thread safety
  
### v2.7.2

- **🖼️ Video Thumbnails** — Added FFmpeg support for embedding cover art into replays
- **🤫 Background Processing** — FFmpeg operations are completely silent and invisible
- **🛠️ Stability & Performance** — Fixed crashes during rapid screenshots in Fullscreen mode
- **🛡️ Enhanced Logic** — Integrated `IsWindow` validation and cooldowns for thread safety
- **📂 Safe File Handling** — Files are verified before original is removed
- **🔧 Auto-Correction** — Improved path handling for spaces and incorrect exe selection
  
### v2.7.1

- **🔧 Window Reuse** — Redesigned notification system to reuse windows instead of constant destroy/create
- **🐛 Crash Fix** — Fixed critical access violations when spamming notifications
- **🛡️ Validation** — Added `IsWindow` checks to timer callbacks and FFI definitions
  
### v2.7.0

- 📦 **All-In-One Package** — Single file with embedded database (no external dependencies!)
- 🎮 **1800+ Games Database** — Massive built-in game library (~1876 games)
- 🛡️ **230+ Ignored Programs** — Expanded filter list for launchers, utilities, and system apps
- 🎨 **Polished UI** — Beautiful emoji icons throughout the interface
- ⚡ **Instant Loading** — No lazy-loading delays, database ready immediately
- 🔧 **Cleaner Code** — Optimized and consolidated codebase
- 🐛 **Fixed** Explorer folders with game names no longer confused with actual games

### v2.6.3

- 🐛 **Fixed** Telegram/Explorer creating wrong folders from window titles
- 📸 **Added** screenshot save notifications
- 🔤 **Added** Unicode/Cyrillic support in popups
  
### v2.6.2

- 🔔 **Notification System** — Visual popups + sound notifications
- 🎯 **Contains Matching** — New `*pattern*` mode for flexible matching
- 🐛 **Fixed** white background flash on popup
- 🛡️ **Expanded** ignore list to 80+ programs
- 📥 **Improved** import/export functionality

### v2.4.0

- 🎬 Full recording support (Start/Stop)
- ✂️ File splitting support for long recordings
- 🔧 Stability improvements

### v2.0.0

- 🎮 Custom names system with GUI
- 📦 Import/Export functionality
- 🛡️ Anti-spam protection

### v1.0.0

- 🚀 Initial release
- 🎯 Basic game detection
- 📁 Automatic folder creation

</details>

  ---

## 🤝 Contributing

  Contributions are welcome! Feel free to:

- 🐛 Report bugs via [Issues](https://github.com/SlonickLab/Smart-Replay-Mover/issues)
- 💡 Suggest features via [Discussions](https://github.com/SlonickLab/Smart-Replay-Mover/discussions)
- 🎮 Add game mappings to `games_database.json` via Pull Request
- 🌍 Help with translations

  ---

## 📜 License

  This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

  ---

  <div align="center">

  **Made with ❤️ by SlonickLab**

  [⬆ Back to Top](#-smart-replay-mover)

  </div>
