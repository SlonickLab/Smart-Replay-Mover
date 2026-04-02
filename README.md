<div align="center">

  # 🎮 Smart Replay Mover

  ### The Ultimate Zero-Config Organizer for OBS

  **Automatically organize your Replay Buffer clips, Recordings, and Screenshots into game-specific folders.**

  [![Version](https://img.shields.io/badge/version-2.8.1-00d4aa.svg)](https://github.com/SlonickLab/Smart-Replay-Mover/releases)
  [![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6.svg)]()
  [![OBS](https://img.shields.io/badge/OBS-28.x+-302E31.svg)](https://obsproject.com/)

  [Features](#-features) • [Installation](#-installation) • [Configuration](#%EF%B8%8F-configuration) • [Custom Names](#-custom-names)
  <br>
  [FFmpeg Setup](#%EF%B8%8F-video-thumbnails-ffmpeg) • [Troubleshooting](#-troubleshooting) • [Changelog](#-changelog)

  ---

  </div>

  ## ✨ Why Smart Replay Mover?

  Stop messing with Python installations, libraries, and version conflicts. Smart Replay Mover is a **native Lua script** designed for maximum performance and ease of use.

  Unlike other scripts that rely solely on OBS internal hooks, this tool uses **Windows API (via FFI)** to intelligently detect what you're actually playing. This ensures your clips land in the right folder every time—even with Display Capture, Borderless modes, or Anti-Cheat systems.

  <div align="center">

  | ❌ Before | ✅ After |
  |-----------|----------|
  | All clips in one messy folder | Organized by game automatically |
  | Manual sorting after each session | Set and forget |
  | No idea when clip was saved | Visual + sound notifications |

  </div>

  ---

  ## 🚀 Features

  ### 🎯 Intelligent Game Detection
  - **Windows API Detection** — Checks what Windows is focusing on, not just OBS
  - **1800+ Built-in Games** — Massive embedded database, no external files needed
  - **Auto-Pattern Matching** — `minecraft_1.20.exe` → Saves to `Minecraft`
  - **Anti-Cheat Compatible** — Window title fallback for protected games
  - **99.9% Accuracy** — Smart fallback chain ensures correct detection

  ### 🔔 Notification System
  - **Visual Popup** — ShadowPlay-style dark popup with smooth animations
  - **Smart Fullscreen Detection** — Popup in Borderless, sound-only in Exclusive Fullscreen
  - **Custom Sound** — Use your own notification sound
  - **Click-through** — Popup doesn't block your game

  ### 📁 Organization
  - **Replay Buffer** — Automatically organized
  - **Regular Recordings** — Start/Stop recording support
  - **Screenshots** — Optional organization
  - **File Splitting** — Handles long recording segments correctly
  - **🖼️ FFmpeg Thumbnails** — Optional cover art embedding for your clips


  ### 🛡️ Quality of Life
  - **Anti-Spam Protection** — Deletes duplicate files from panic-pressing hotkeys
  - **Case-Insensitive** — Won't create duplicate folders with different cases
  - **Date Subfolders** — Optional monthly organization (2025-06/)
  - **230+ Ignored Programs** — Won't confuse Discord, Chrome, launchers or utilities with games
  - **⚡ Smart Save Hotkey** — Instant "Saving..." notification when pressing your custom hotkey
  - **📂 No-Folder Mode** — Map a process to `/`, `\`, or `.` to keep files in OBS output root

  ---

  ## 📥 Installation

  1. **Download** the latest release from [Releases](https://github.com/SlonickLab/Smart-Replay-Mover/releases)

  2. **Extract** the ZIP archive
     > ⚠️ Do NOT load the .zip file directly into OBS

  3. **Move** `Smart Replay Mover.lua` to a permanent location (e.g., Documents)

  4. **Add to OBS:**
     - Open OBS Studio
     - Go to `Tools` → `Scripts`
     - Click `+` and select the `.lua` file

  5. **Done!** The script works immediately with default settings.

  ---

  ## ⚙️ Configuration

  Click on the script in OBS Scripts window to access settings:

  ### 📁 File Naming
  | Setting | Description |
  |---------|-------------|
  | Add game prefix | Adds game name to filename (e.g., `CS2 - Replay...`) |
  | Fallback folder | Folder name when no game detected (default: `Desktop`) |

  ### 🗂️ Organization
  | Setting | Description |
  |---------|-------------|
  | Monthly subfolders | Creates `YYYY-MM` subfolders |
  | Organize screenshots | Also sort screenshots |
  | Organize recordings | Sort regular recordings (not just replays) |

  ### 🛡️ Spam Protection
  | Setting | Description |
  |---------|-------------|
  | Cooldown | Seconds between saves (prevents duplicates) |
  | Auto-delete | Automatically remove duplicate files |

  ### 🔔 Notifications
  | Setting | Description |
  |---------|-------------|
  | Show popup | Visual notification (Borderless/Windowed only) |
  | Play sound | Audio notification (works in Fullscreen) |
  | Scale % | Resize popup for 4K/HiDPI monitors (100-300%) |
  | Position | Choose popup corner: Top Right, Top Left, Bottom Right, Bottom Left |
  | Duration | How long popup stays visible (1-10 seconds) |
  
  ### 🎥 Advanced (FFmpeg)
  | Setting | Description |
  |---------|-------------|
  | Enable Thumbnails | Embed frame from video as cover art |
  | FFmpeg Path | Path to your `ffmpeg.exe` |
  | Thumbnail Offset | Time (sec) to grab the frame from |


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
  | Smart Save Hotkey | Assign in OBS Settings → Hotkeys for instant "Saving..." feedback |

  ---

  ## 🎮 Custom Names

  Three powerful matching modes for any situation:

  ### Exact Match
  CS2 > Counter-Strike 2
  Maps process name directly to folder name.

  ### Keywords Mode
  +Warhammer Marine > Space Marine 2
  Matches if **all** keywords are present (AND logic). Prefix with `+`.

  ### Contains Mode
  `*Space Marine 2* > Space Marine 2`
  Matches if text is found **anywhere** in process name or window title. Wrap in `*`.

  > 💡 **Pro Tip:** Contains mode is perfect for games with version numbers that change with updates!

  ### Examples

  | Custom Name | What It Matches |
  |-------------|-----------------|
  | `r5apex > Apex Legends` | Process `r5apex.exe` |
  | `+Warhammer Space > WH40K` | Any window containing both words |
  | `*Cyberpunk* > Cyberpunk 2077` | `Cyberpunk 2077 v2.1 Patch...` |
  | `chrome > /` | Chrome clips stay in OBS output root (no subfolder). Also supports `\` and `.` |

  ---

  ## 🔊 Custom Notification Sound

  1. Find a short sound file (1-2 seconds recommended)
  2. Convert to **WAV format** if needed
  3. Rename to `notification_sound.wav`
  4. Place in the same folder as the script:

  ```
  📁 Your Folder/
  ├── Smart Replay Mover.lua
  └── notification_sound.wav
  ```

  5. Reload the script — done!

  ### 🔇 Quiet Sound Option (v2.7.7+)
  
  If the standard sound is too loud, you can use a separate "quiet" sound file:
  
  1. Prepare a quieter sound file.
  2. Name it `notification_sound_silent.wav`.
  3. Place it in the same folder.
  4. In script settings, check **"Use Quiet Sound"**.
  
  Now you can toggle between the Normal and Quiet versions instantly!

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
  └── 📁 Desktop/
      └── Desktop - 2025-06-17 09-00-00.mp4
  ```

  ---

  ## ❓ Troubleshooting

  ### 🛑 Nothing happens when I test?
  
  **IMPORTANT:** The script detects the **Active Window** (what you are currently looking at).
  
  - If you Alt-Tab to OBS to change settings -> The script sees "OBS Studio".
  - Since OBS is in the ignores list, the script does nothing.
  
  **How to Test Properly:**
  1. Set up your Custom Names.
  2. **Alt-Tab back into the game.**
  3. Wait 3-5 seconds.
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
  > - ❌ `*cs2*` -> Won't work because the window is named "Counter-Strike 2" (doesn't contain "cs2").
  > - ✅ `*Counter-Strike*` -> Works perfectly!
  > - ❌ `*FactoryGamesteam*` -> Won't work because window is named "Satisfactory".
  > - ✅ `*Satisfactory*` -> Works perfectly!

  The `*pattern*` mode matches the window title, which works even when anti-cheat blocks process detection!

  ---

  ## 🎞️ Video Thumbnails (FFmpeg)

  Enhance your clip library by embedding high-quality cover art into your videos. This allows Windows Explorer (and tools like [Icaros](https://www.majorgeeks.com/files/details/icaros.html)) to display a frame from your gameplay as the file icon instead of a generic media player logo.

  ### 📥 1. Download FFmpeg
  1. Go to [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) (recommended Windows builds).
  2. Download the `ffmpeg-release-essentials.zip`.
  3. Extract it to a permanent folder (e.g., `C:\Program Files\ffmpeg`).

  ### ⚙️ 2. Configuration in OBS
  1. Open OBS Studio → **Tools** → **Scripts**.
  2. Select **Smart Replay Mover**.
  3. Go to the **🎥 Advanced (FFmpeg)** section.
  4. Enable **"Enable Thumbnails"**.
  5. Click **Browse** for **FFmpeg Path** and select the `ffmpeg.exe` file (located inside the `bin` folder of your extraction).

  ### ✨ Benefits
  - **Silent & Invisible** — FFmpeg runs completely in the background without popups.
  - **No Quality Loss** — Metadata is embedded without re-encoding your video.
  - **Universal Compatibility** — Works with both MKV (attachments) and MP4 (tags).

  ---

  ## 📋 Changelog
  
  ### v2.8.1 (Hotfix)
  - **🛡️ CRITICAL FIX** — Smart Save Hotkey no longer crashes or freezes OBS ([Discussion #16](https://github.com/SlonickLab/Smart-Replay-Mover/discussions/16))
  - **🧵 Thread-Safe Notifications** — All notification calls now go through a safe queue processed exclusively on one thread, eliminating cross-thread Win32 GDI deadlocks
  - **⚡ Smart Skip** — On fast systems (NVMe/SSD), the intermediate "Saving..." is automatically skipped in favor of "Clip Saved" when save completes instantly
  - **🐛 Detection Fix** — Fixed double `detect_game()` call during replay buffer save that could cause wrong folder assignment

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
  
  <details>
  <summary>View older versions</summary>

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

  - 🐛 Report bugs
  - 💡 Suggest features
  - 🎮 Add game mappings
  - 🌍 Help with translations

  ---

  ## 📜 License

  This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

  ---

  <div align="center">

  **Made with ❤️ by SlonickLab**

  [⬆ Back to Top](#-smart-replay-mover)

  </div>
