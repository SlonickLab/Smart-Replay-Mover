[SIZE=6][B]Smart Replay Mover v2.6.2 (Native Lua) - The Ultimate Zero-Config Organizer[/B][/SIZE]

  [B]The Ultimate "Zero-Config" Organizer for OBS Replays, Recordings & Screenshots.[/B]

  Stop messing with Python installations, libraries, and version conflicts. Smart Replay Mover is a native Lua script designed for maximum performance and ease of use. Just add it to OBS, and it works immediately.

  Unlike other scripts that rely solely on OBS internal hooks, this tool uses Windows API (via FFI) to intelligently detect what you are actually playing directly from the OS. This ensures your clips land in the right folder every time—even if you use Display Capture, Borderless modes, or play games with strict Anti-Cheat systems.

  ---

  [SIZE=5][B]WHAT'S NEW IN v2.6.2?[/B][/SIZE]

  [B]NOTIFICATION SYSTEM (NEW!)[/B]
  [LIST]
  [*] Visual popup notifications when clips are saved!
    - ShadowPlay-style dark popup in top-right corner
    - Smooth fade-in/fade-out animations
    - Click-through (doesn't block your game)
    - Shows game name and destination folder

  [*] Smart Fullscreen Detection
    - In Exclusive Fullscreen: only plays sound (popup can't show)
    - In Borderless/Windowed: shows popup + sound

  [*] Custom Sound Support
    - Place "notification_sound.wav" next to the script
    - Uses your custom sound instead of Windows default
  [/LIST]

  [B]ADVANCED MATCHING MODES (NEW!)[/B]
  [LIST]
  [*] [B]Exact Match:[/B] process_name > Folder Name
  [*] [B]Keywords Mode:[/B] +word1 word2 > Folder Name (all words must match)
  [*] [B]Contains Mode:[/B] *partial text* > Folder Name
    - Perfect for games with version numbers in titles
    - Example: *Space Marine 2* > Space Marine 2
    - Works regardless of patches/updates!
  [/LIST]

  [B]EXPANDED IGNORE LIST[/B]
  [LIST]
  [*] Now includes 80+ programs to prevent false detection
  [*] Windows 11 widgets, Xbox Game Bar
  [*] Hardware utilities: iCUE, Razer Synapse, Logitech G Hub
  [*] Recording tools: ShareX, Lightshot, Bandicam
  [*] Remote desktop: AnyDesk, TeamViewer, Parsec
  [/LIST]

  [B]BUG FIXES[/B]
  [LIST]
  [*] Fixed white background flash on notification popup
  [*] Import now uses default path when empty
  [*] Improved debug logging for troubleshooting
  [/LIST]

  ---

  [SIZE=5][B]WHY CHOOSE THIS OVER PYTHON SCRIPTS?[/B][/SIZE]

  [LIST]
  [*] [B]Zero Dependencies[/B] - No Python. No Tkinter. No complex setup.
  [*] [B]Superior Detection[/B] - Works flawlessly where standard "Game Capture" hooks fail.
  [*] [B]Native GUI[/B] - Configure everything directly in OBS. No editing text files.
  [*] [B]Visual Notifications[/B] - Know instantly when your clip is saved without alt-tabbing.
  [*] [B]Performance[/B] - Runs natively inside OBS without external overhead.
  [/LIST]

  ---

  [SIZE=5][B]KEY FEATURES[/B][/SIZE]

  [B]1. INTELLIGENT GAME DETECTION (Windows API)[/B]
  We don't just ask OBS what it's recording; we check what Windows is focusing on.
  [LIST]
  [*] Works with: CS2, Valorant, FACEIT, Dota 2, Elden Ring, and 80+ pre-configured games
  [*] Auto-Pattern Matching: "minecraft_1.20.exe" -> Saves to "Minecraft"
  [*] Smart Fallback: Active Process -> Window Title -> OBS Hook
  [*] Result: 99.9% accuracy in sorting files
  [/LIST]

  [B]2. FLEXIBLE CUSTOM NAME SYSTEM[/B]
  Three matching modes for any situation:
  [CODE]
  FORMAT                        DESCRIPTION
  ---------------------------------------------------------
  CS2 > Counter-Strike 2        Exact process match
  +Warhammer Marine > SM2       Keywords (AND logic)
  *Space Marine* > SM2          Contains (partial match)
  [/CODE]
  [LIST]
  [*] Import/Export your custom rules with one click
  [*] Share configurations with friends
  [/LIST]

  [B]3. FULL RECORDING SUPPORT[/B]
  [LIST]
  [*] Organizes Replay Buffer clips
  [*] Organizes regular recordings (Start/Stop)
  [*] Organizes screenshots
  [*] Handles file splitting for long recordings
  [/LIST]

  [B]4. ANTI-SPAM & DUPLICATE CLEANUP[/B]
  Did you panic-press your save hotkey during a clutch moment? The script analyzes timestamps and automatically deletes duplicate files created within seconds of each other.

  [B]5. ORGANIZATION & HYGIENE[/B]
  [LIST]
  [*] [B]Case-Insensitive:[/B] Won't create "Call of Duty" AND "call of duty"
  [*] [B]Date Sorting:[/B] Optional monthly subfolders (2025-06/)
  [*] [B]Safety Ignore List:[/B] 80+ non-game programs filtered
  [*] [B]Unicode Support:[/B] Full support for non-English paths
  [/LIST]

  ---

  [SIZE=5][B]EXAMPLE DIRECTORY STRUCTURE[/B][/SIZE]

  The script automatically organizes your output folder:

  [CODE]
  Videos/
  |-- Counter-Strike 2/
  |   |-- CS2 - 2025-06-15 14-30-01.mp4
  |   +-- CS2 - 2025-06-15 14-35-22.png
  |
  |-- Valorant/
  |   +-- Valorant - 2025-06-16 20-10-55.mp4
  |
  |-- Warhammer 40K Space Marine 2/
  |   +-- Space Marine 2 - 2025-06-17 18-45-00.mp4
  |
  |-- Desktop/ (Fallback)
  |   +-- Desktop - 2025-06-17 09-00-00.mp4
  |
  +-- Minecraft/
      +-- 2025-06/ (Optional Date Subfolder)
          +-- Minecraft - 2025-06-18 11-22-33.mp4
  [/CODE]

  ---

  [SIZE=5][B]INSTALLATION[/B][/SIZE]

  [LIST=1]
  [*] Download the ZIP archive
  [*] Extract the archive (Right-click -> Extract All)
      [B]WARNING:[/B] Do NOT load the .zip file directly into OBS!
  [*] Move "Smart Replay Mover.lua" to a safe folder (e.g., Documents)
  [*] Open OBS -> Tools -> Scripts
  [*] Click [ + ] and select the .lua file
  [*] Done!
  [/LIST]

  ---

  [SIZE=5][B]CONFIGURATION[/B][/SIZE]

  Click on "Smart Replay Mover.lua" in the Scripts list to see settings:

  [B]FILE NAMING[/B]
  [LIST]
  [*] Add game name prefix to filename
  [*] Fallback folder name (default: Desktop)
  [/LIST]

  [B]CUSTOM NAMES[/B]
  [LIST]
  [*] Process, +keywords, or *contains*
  [*] Folder name
  [*] Add mapping button
  [/LIST]

  [B]ORGANIZATION[/B]
  [LIST]
  [*] Create monthly subfolders (YYYY-MM)
  [*] Organize screenshots
  [*] Organize recordings
  [/LIST]

  [B]SPAM PROTECTION[/B]
  [LIST]
  [*] Cooldown between saves (0-30 seconds)
  [*] Auto-delete duplicate files
  [/LIST]

  [B]NOTIFICATIONS[/B]
  [LIST]
  [*] Show visual popup (Borderless/Windowed only)
  [*] Play notification sound (works in Fullscreen too)
  [*] Popup duration (1-10 seconds)
  [/LIST]

  ---

  [SIZE=5][B]CUSTOM NOTIFICATION SOUND[/B][/SIZE]

  Want your own notification sound?

  [LIST=1]
  [*] Find a short sound (1-2 seconds recommended)
  [*] Convert to WAV format if needed
  [*] Rename to: [B]notification_sound.wav[/B]
  [*] Place next to Smart Replay Mover.lua
  [*] Reload the script - done!
  [/LIST]

  [CODE]
  C:\obs-scripts\
  |-- Smart Replay Mover.lua
  +-- notification_sound.wav  <-- Your custom sound
  [/CODE]

  ---

  [SIZE=5][B]USE CASE EXAMPLES[/B][/SIZE]

  [B]PROBLEM:[/B] Game shows as "Warhammer 40,000 Space Marine 2 CLIENT v11.2.799056" and changes with every update

  [B]SOLUTION:[/B] Add custom name: [B]*Space Marine 2* > Space Marine 2[/B]
  Now all clips save to "Space Marine 2" folder regardless of version!

  ---

  [B]PROBLEM:[/B] I want to know when clips are saved without alt-tabbing

  [B]SOLUTION:[/B] Enable notifications in script settings!
  [LIST]
  [*] Visual popup in Borderless/Windowed mode
  [*] Sound plays even in Exclusive Fullscreen
  [/LIST]

  ---

  [B]PROBLEM:[/B] I have many custom rules and want to share them

  [B]SOLUTION:[/B] Use Export button to save rules to a text file. Share with friends, they can Import with one click!

  ---

  [SIZE=5][B]COMPATIBILITY[/B][/SIZE]

  [LIST]
  [*] Windows 10 / 11
  [*] OBS Studio 28.x or newer
  [*] Tech: Pure Lua + Windows FFI (No external DLLs needed)
  [/LIST]

  ---

  [SIZE=5][B]LICENSE & SOURCE[/B][/SIZE]

  GPL v3 License | Open Source
  GitHub: [URL=https://github.com/SlonickLab/Smart-Replay-Mover]https://github.com/SlonickLab/Smart-Replay-Mover[/URL]

  [B]Made with love by SlonickLab[/B]
