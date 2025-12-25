<div align="center">

  # 🎮 Smart Replay Mover

  ### The Ultimate Zero-Config Organizer for OBS

  **Automatically organize your Replay Buffer clips, Recordings, and Screenshots into game-specific folders.**

  [![Version](https://img.shields.io/badge/version-2.6.2-00d4aa.svg)](https://github.com/SlonickLab/Smart-Replay-Mover/releases)
  [![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6.svg)]()
  [![OBS](https://img.shields.io/badge/OBS-28.x+-302E31.svg)](https://obsproject.com/)

  [Features](#-features) • [Installation](#-installation) • [Configuration](#%EF%B8%8F-configuration) • [Custom Names](#-custom-names) • [Changelog](#-changelog)

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
  - **80+ Pre-configured Games** — CS2, Valorant, Dota 2, Elden Ring, and more
  - **Auto-Pattern Matching** — `minecraft_1.20.exe` → Saves to `Minecraft`
  - **99.9% Accuracy** — Smart fallback system ensures correct detection

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

  ### 🛡️ Quality of Life
  - **Anti-Spam Protection** — Deletes duplicate files from panic-pressing hotkeys
  - **Case-Insensitive** — Won't create duplicate folders with different cases
  - **Date Subfolders** — Optional monthly organization (2025-06/)
  - **80+ Ignored Programs** — Won't confuse Discord, Chrome, or utilities with games

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
  | Duration | How long popup stays visible (1-10 seconds) |

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
  Space Marine 2 > Space Marine 2
  Matches if text is found **anywhere** in process name or window title. Wrap in `*`.

  > 💡 **Pro Tip:** Contains mode is perfect for games with version numbers that change with updates!

  ### Examples

  | Custom Name | What It Matches |
  |-------------|-----------------|
  | `r5apex > Apex Legends` | Process `r5apex.exe` |
  | `+Warhammer Space > WH40K` | Any window containing both words |
  | `*Cyberpunk* > Cyberpunk 2077` | `Cyberpunk 2077 v2.1 Patch...` |

  ---

  ## 🔊 Custom Notification Sound

  1. Find a short sound file (1-2 seconds recommended)
  2. Convert to **WAV format** if needed
  3. Rename to `notification_sound.wav`
  4. Place in the same folder as the script:

  📁 Your Folder/
  ├── Smart Replay Mover.lua
  └── notification_sound.wav

  5. Reload the script — done!

  ---

  ## 📂 Output Structure

  The script creates this folder structure automatically:

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

  ---

  ## 📋 Changelog

  ### v2.6.2 (Latest)
  - 🔔 **Notification System** — Visual popups + sound notifications
  - 🎯 **Contains Matching** — New `*pattern*` mode for flexible matching
  - 🐛 **Fixed** white background flash on popup
  - 🛡️  **Expanded** ignore list to 80+ programs
  - 📥 **Improved** import/export functionality

  ### v2.4.0
  - 🎬 Full recording support (Start/Stop)
  - ✂️ File splitting support for long recordings
  - 🔧 Stability improvements

  <details>
  <summary>View older versions</summary>

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
