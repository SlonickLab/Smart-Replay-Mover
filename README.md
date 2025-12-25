Smart Replay Mover v2.6.2 (Native Lua) - The Ultimate Zero-Config Organizer

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  The Ultimate "Zero-Config" Organizer for OBS Replays, Recordings & Screenshots.

  Stop messing with Python installations, libraries, and version conflicts.
  Smart Replay Mover is a native Lua script designed for maximum performance
  and ease of use. Just add it to OBS, and it works immediately.

  Unlike other scripts that rely solely on OBS internal hooks, this tool uses
  Windows API (via FFI) to intelligently detect what you are actually playing
  directly from the OS. This ensures your clips land in the right folder
  every time—even if you use Display Capture, Borderless modes, or play
  games with strict Anti-Cheat systems.

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🆕 WHAT'S NEW IN v2.6.2?
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🔔 NOTIFICATION SYSTEM
  • Visual popup notifications when clips are saved!
    - ShadowPlay-style dark popup in top-right corner
    - Smooth fade-in/fade-out animations
    - Click-through (doesn't block your game)
    - Shows game name and destination folder

  • Smart Fullscreen Detection
    - In Exclusive Fullscreen: only plays sound (popup can't show)
    - In Borderless/Windowed: shows popup + sound

  • Custom Sound Support
    - Place "notification_sound.wav" next to the script
    - Uses your custom sound instead of Windows default


  🎯 ADVANCED MATCHING MODES
  • Exact Match: process_name > Folder Name
  • Keywords Mode: +word1 word2 > Folder Name (all words must match)
  • Contains Mode: *partial text* > Folder Name (NEW!)
    - Perfect for games with version numbers in titles
    - Example: *Space Marine 2* > Space Marine 2
    - Works regardless of patches/updates!


  🛡️ EXPANDED IGNORE LIST
  • Now includes 80+ programs to prevent false detection
  • Windows 11 widgets, Xbox Game Bar
  • Hardware utilities: iCUE, Razer Synapse, Logitech G Hub
  • Recording tools: ShareX, Lightshot, Bandicam
  • Remote desktop: AnyDesk, TeamViewer, Parsec


  🐛 BUG FIXES
  • Fixed white background flash on notification popup
  • Import now uses default path when empty
  • Improved debug logging for troubleshooting


  ⚡ WHY CHOOSE THIS OVER PYTHON SCRIPTS?
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Zero Dependencies
     No Python. No Tkinter. No complex setup.

  ✅ Superior Detection
     Works flawlessly where standard "Game Capture" hooks fail.

  ✅ Native GUI
     Configure everything directly in OBS. No editing text files.

  ✅ Visual Notifications
     Know instantly when your clip is saved without alt-tabbing.

  ✅ Performance
     Runs natively inside OBS without external overhead.


  🎮 KEY FEATURES
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1️⃣ INTELLIGENT GAME DETECTION (Windows API)
     We don't just ask OBS what it's recording; we check what Windows
     is focusing on.

     • Works with: CS2, Valorant, FACEIT, Dota 2, Elden Ring, and 80+
       pre-configured games
     • Auto-Pattern Matching: "minecraft_1.20.exe" → Saves to "Minecraft"
     • Smart Fallback: Active Process → Window Title → OBS Hook
     • Result: 99.9% accuracy in sorting files


  2️⃣ FLEXIBLE CUSTOM NAME SYSTEM
     Three matching modes for any situation:

     ┌─────────────────────────────────────────────────────────────┐
     │  FORMAT                      │  DESCRIPTION                 │
     ├─────────────────────────────────────────────────────────────┤
     │  CS2 > Counter-Strike 2      │  Exact process match         │
     │  +Warhammer Marine > SM2     │  Keywords (AND logic)        │
     │  *Space Marine* > SM2        │  Contains (partial match)    │
     └─────────────────────────────────────────────────────────────┘

     • Import/Export your custom rules with one click
     • Share configurations with friends


  3️⃣ FULL RECORDING SUPPORT
     • Organizes Replay Buffer clips
     • Organizes regular recordings (Start/Stop)
     • Organizes screenshots
     • Handles file splitting for long recordings


  4️⃣ ANTI-SPAM & DUPLICATE CLEANUP
     Did you panic-press your save hotkey during a clutch moment?
     The script analyzes timestamps and automatically deletes duplicate
     files created within seconds of each other.


  5️⃣ ORGANIZATION & HYGIENE
     • Case-Insensitive: Won't create "Call of Duty" AND "call of duty"
     • Date Sorting: Optional monthly subfolders (2025-06/)
     • Safety Ignore List: 80+ non-game programs filtered
     • Unicode Support: Full support for non-English paths


  📁 EXAMPLE DIRECTORY STRUCTURE
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  The script automatically organizes your output folder:

  Code:
  📂 Videos
  ├── 📁 Counter-Strike 2
  │   ├── CS2 - 2025-06-15 14-30-01.mp4
  │   └── CS2 - 2025-06-15 14-35-22.png
  │
  ├── 📁 Valorant
  │   └── Valorant - 2025-06-16 20-10-55.mp4
  │
  ├── 📁 Warhammer 40K Space Marine 2
  │   └── Space Marine 2 - 2025-06-17 18-45-00.mp4
  │
  ├── 📁 Desktop (Fallback)
  │   └── Desktop - 2025-06-17 09-00-00.mp4
  │
  └── 📁 Minecraft
      └── 📁 2025-06 (Optional Date Subfolder)
          └── Minecraft - 2025-06-18 11-22-33.mp4


  📥 INSTALLATION
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Download the ZIP archive
  2. Extract the archive (Right-click → Extract All)
     ⚠️ Do NOT load the .zip file directly into OBS!
  3. Move "Smart Replay Mover.lua" to a safe folder (e.g., Documents)
  4. Open OBS → Tools → Scripts
  5. Click [ + ] and select the .lua file
  6. Done! ✅


  ⚙️ CONFIGURATION
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Click on "Smart Replay Mover.lua" in the Scripts list to see settings:

  📁 FILE NAMING
     ☑️ Add game name prefix to filename
     📂 Fallback folder name (default: Desktop)

  🎮 CUSTOM NAMES
     🎯 Process, +keywords, or *contains*
     📁 Folder name
     ➕ Add mapping

  🗂️ ORGANIZATION
     ☑️ Create monthly subfolders (YYYY-MM)
     ☑️ Organize screenshots
     ☑️ Organize recordings

  🛡️ SPAM PROTECTION
     ⏱️ Cooldown between saves (0-30 seconds)
     ☑️ Auto-delete duplicate files

  🔔 NOTIFICATIONS
     ☑️ Show visual popup (Borderless/Windowed only)
     ☑️ Play notification sound (works in Fullscreen too)
     ⏱️ Popup duration (1-10 seconds)


  🔊 CUSTOM NOTIFICATION SOUND
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Want your own notification sound?

  1. Find a short sound (1-2 seconds recommended)
  2. Convert to WAV format if needed
  3. Rename to: notification_sound.wav
  4. Place next to Smart Replay Mover.lua
  5. Reload the script - done!

  Code:
  📂 C:\obs-scripts\
  ├── Smart Replay Mover.lua
  └── notification_sound.wav  ← Your custom sound


  💡 USE CASE EXAMPLES
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🎮 PROBLEM: Game shows as "Warhammer 40,000 Space Marine 2 CLIENT v11.2.799056"
     and changes with every update

     ✅ SOLUTION: Add custom name: *Space Marine 2* > Space Marine 2
     Now all clips save to "Space Marine 2" folder regardless of version!


  🔔 PROBLEM: I want to know when clips are saved without alt-tabbing

     ✅ SOLUTION: Enable notifications in script settings!
     • Visual popup in Borderless/Windowed mode
     • Sound plays even in Exclusive Fullscreen


  📋 PROBLEM: I have many custom rules and want to share them

     ✅ SOLUTION: Use Export button to save rules to a text file
     Share with friends, they can Import with one click!


  📋 COMPATIBILITY
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • Windows 10 / 11
  • OBS Studio 28.x or newer
  • Tech: Pure Lua + Windows FFI (No external DLLs needed)


  📜 LICENSE & SOURCE
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GPL v3 License | Open Source
  GitHub: https://github.com/SlonickLab/Smart-Replay-Mover

  Made with ❤️ by SlonickLab
