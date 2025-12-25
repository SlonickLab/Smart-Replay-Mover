-- ============================================================================
-- Smart Replay Mover v2.6.2
-- Simple, safe, and reliable replay buffer organizer for OBS
-- ============================================================================
--
-- Copyright (C) 2025-2026 SlonickLab
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- Source Code: https://github.com/SlonickLab/Smart-Replay-Mover
--
-- NOTICE: This script is protected under GPL v3. Any distribution,
-- modification, or derivative work MUST:
--   1. Include this copyright notice and license
--   2. Disclose the source code
--   3. Use the same GPL v3 license
--   4. Document all changes made
--
-- Plagiarism or removal of this notice violates the license terms.
-- ============================================================================

local obs = obslua
local ffi = require("ffi")

-- Get script directory at load time (for custom sound file)
local SCRIPT_DIR = (function()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local source = info.source
        -- Remove @ prefix if present
        if source:sub(1, 1) == "@" then
            source = source:sub(2)
        end
        -- Extract directory path
        return source:match("^(.*[/\\])") or ""
    end
    return ""
end)()

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    add_game_prefix = true,
    organize_screenshots = true,
    organize_recordings = true,  -- Support for regular recordings
    use_date_subfolders = false,
    fallback_folder = "Desktop",
    duplicate_cooldown = 5.0,
    delete_spam_files = true,
    debug_mode = false,
    -- Notification settings
    show_notifications = true,      -- Visual popup (Borderless Windowed only)
    play_sound = false,             -- Sound notification (works in Fullscreen too)
    notification_duration = 3.0,    -- Duration in seconds
}

-- ============================================================================
-- IGNORE LIST (Programs to skip when detecting games)
-- ============================================================================

local IGNORE_LIST = {
    -- System
    "explorer", "searchapp", "taskmgr", "lockapp", "applicationframehost",
    "shellexperiencehost", "systemsettings", "textinputhost",

    -- Windows 11 / Xbox
    "widgets", "windowsterminal", "wt", "gamebarui", "gamebar",
    "xbox", "xboxapp", "gamingservices",

    -- OBS and streaming
    "obs64", "obs32", "obs", "streamlabs",

    -- Communication
    "discord", "telegram", "skype", "teams", "slack", "zoom", "viber",
    "whatsapp", "signal", "guilded", "element", "mumble", "teamspeak", "ventrilo",

    -- Browsers
    "chrome", "firefox", "opera", "msedge", "brave", "vivaldi", "safari",
    "iexplore", "chromium",

    -- Media players
    "spotify", "vlc", "wmplayer", "groove", "itunes", "foobar2000",
    "musicbee", "winamp", "deezer", "tidal", "amazonmusic",

    -- Game launchers
    "steam", "steamwebhelper", "epicgameslauncher", "battle.net",
    "origin", "eadesktop", "gog", "ubisoft", "bethesda",
    "riot client", "riotclientservices", "playnite", "gogalaxy",
    "rockstar", "socialclub", "amazongames", "primegaming",

    -- Editing software
    "photoshop", "lightroom", "gimp", "paint", "mspaint",
    "premiere", "aftereffects", "davinci", "resolve", "vegas",
    "audacity", "audition", "obs",

    -- Overlays and hardware utilities
    "nvidia share", "geforce", "shadowplay", "overwolf", "medal",
    "playstv", "raptr", "amd", "radeon",
    "corsair", "icue", "razer", "synapse", "logitech", "lghub",
    "steelseries", "msiafterburner", "afterburner", "rivatuner", "rtss",
    "nzxt", "hwinfo", "cpuz", "gpuz",

    -- Recording and screenshots
    "sharex", "lightshot", "greenshot", "bandicam", "fraps", "xsplit", "action",

    -- Remote desktop
    "anydesk", "teamviewer", "parsec",

    -- Development
    "code", "vscode", "sublime", "notepad", "notepad++", "atom",
    "visual studio", "devenv", "idea", "pycharm", "webstorm",

    -- Utilities
    "7zfm", "winrar", "filezilla", "putty", "terminal", "powershell",
    "cmd", "conhost",

    -- Cloud storage
    "dropbox", "onedrive", "icloud",

    -- Google apps
    "google", "googlecrashhandler", "googledrivesync", "backup",
}

-- ============================================================================
-- GAME NAME MAPPINGS
-- ============================================================================

local GAME_NAMES = {
    -- Exact matches (process name -> folder name)
    ["cs2"] = "Counter-Strike 2",
    ["csgo"] = "Counter-Strike GO",
    ["dota2"] = "Dota 2",
    ["r5apex"] = "Apex Legends",
    ["gta5"] = "Grand Theft Auto V",
    ["rdr2"] = "Red Dead Redemption 2",
    ["shootergame"] = "ARK Survival Evolved",
    ["shootergame_be"] = "ARK Survival Evolved",
    ["valorant-win64-shipping"] = "Valorant",
    ["fortnite"] = "Fortnite",
    -- Minecraft (Java edition)
    ["javaw"] = "Minecraft",
    ["java"] = "Minecraft",
    -- War Thunder
    ["aces"] = "War Thunder",
    -- Final Fantasy XIV
    ["ffxiv_dx11"] = "Final Fantasy XIV",
    ["ffxiv"] = "Final Fantasy XIV",
    -- World of Tanks
    ["worldoftanks"] = "World of Tanks",
    ["wotlauncher"] = "World of Tanks",
    -- Additional popular games
    ["sekiro"] = "Sekiro",
    ["re2"] = "Resident Evil 2",
    ["re3"] = "Resident Evil 3",
    ["re4"] = "Resident Evil 4",
    ["monsterhunterworld"] = "Monster Hunter World",
    ["monsterhunterrise"] = "Monster Hunter Rise",
    ["pathofexile"] = "Path of Exile",
    ["pathofexile_x64"] = "Path of Exile",
    ["lostark"] = "Lost Ark",
    ["newworld"] = "New World",
    ["warframe"] = "Warframe",
    ["warframe.x64"] = "Warframe",
}

local GAME_PATTERNS = {
    -- Pattern matches (keyword -> folder name)
    {"minecraft", "Minecraft"},
    {"roblox", "Roblox"},
    {"fortnite", "Fortnite"},
    {"valorant", "Valorant"},
    {"league", "League of Legends"},
    {"overwatch", "Overwatch 2"},
    {"warzone", "Call of Duty Warzone"},
    {"modernwarfare", "Call of Duty"},
    {"call of duty", "Call of Duty"},
    {"cod", "Call of Duty"},
    {"eurotrucks", "Euro Truck Simulator 2"},
    {"rocketleague", "Rocket League"},
    {"rustclient", "Rust"},
    {"pubg", "PUBG"},
    {"tslgame", "PUBG"},
    {"rainbowsix", "Rainbow Six Siege"},
    {"siege", "Rainbow Six Siege"},
    {"destiny2", "Destiny 2"},
    {"cyberpunk", "Cyberpunk 2077"},
    {"witcher", "The Witcher 3"},
    {"genshin", "Genshin Impact"},
    {"honkai", "Honkai Star Rail"},
    {"eldenring", "Elden Ring"},
    {"darksouls", "Dark Souls"},
    {"stardew", "Stardew Valley"},
    {"terraria", "Terraria"},
    {"amongus", "Among Us"},
    {"among us", "Among Us"},
    {"deadbydaylight", "Dead by Daylight"},
    {"hoi4", "Hearts of Iron IV"},
    {"factorio", "Factorio"},
    {"baldur", "Baldur's Gate 3"},
    {"bg3", "Baldur's Gate 3"},
    {"palworld", "Palworld"},
    {"phasmophobia", "Phasmophobia"},
    {"left4dead", "Left 4 Dead 2"},
    {"teamfortress", "Team Fortress 2"},
    {"tf2", "Team Fortress 2"},
    {"helldivers", "Helldivers 2"},
    {"starfield", "Starfield"},
    {"skyrim", "Skyrim"},
    {"fallout", "Fallout"},
    {"diablo", "Diablo"},
    {"wow", "World of Warcraft"},
    {"apex", "Apex Legends"},
    -- War Thunder
    {"warthunder", "War Thunder"},
    {"gaijin", "War Thunder"},
    -- Final Fantasy
    {"finalfantasy", "Final Fantasy XIV"},
    {"ffxiv", "Final Fantasy XIV"},
    {"ff14", "Final Fantasy XIV"},
    -- World of Tanks
    {"worldoftanks", "World of Tanks"},
    {"wot", "World of Tanks"},
    -- Additional games
    {"monsterhunter", "Monster Hunter"},
    {"residentevil", "Resident Evil"},
    {"pathofexile", "Path of Exile"},
    {"poe", "Path of Exile"},
    {"lostark", "Lost Ark"},
    {"newworld", "New World"},
    {"warframe", "Warframe"},
    {"sekiro", "Sekiro"},
    {"armored core", "Armored Core VI"},
    {"armoredcore", "Armored Core VI"},
    {"lies of p", "Lies of P"},
    {"liesofp", "Lies of P"},
    {"hogwarts", "Hogwarts Legacy"},
    {"satisfactory", "Satisfactory"},
    {"deeprock", "Deep Rock Galactic"},
    {"valheim", "Valheim"},
    {"no man", "No Man's Sky"},
    {"nomans", "No Man's Sky"},
    {"subnautica", "Subnautica"},
    {"sims", "The Sims 4"},
}

-- ============================================================================
-- CUSTOM NAMES (User-defined mappings from GUI)
-- Format: executable or path > Display Name
-- Keywords mode: +keyword1 keyword2 > Display Name (all words must match)
-- Contains mode: *text* > Display Name (partial match in window title)
-- ============================================================================

local CUSTOM_NAMES_EXACT = {}     -- {["process"] = "Folder Name"} for exact matches
local CUSTOM_NAMES_KEYWORDS = {}  -- {{keywords = {"word1", "word2"}, name = "Folder"}, ...}
local CUSTOM_NAMES_CONTAINS = {}  -- {{pattern = "text", name = "Folder"}, ...} for *pattern* mode

-- Parse a single custom name entry
-- Supports formats:
--   "C:\path\to\game.exe > Custom Name"  (exact match)
--   "game.exe > Custom Name"              (exact match)
--   "game > Custom Name"                  (exact match)
--   "+keyword1 keyword2 > Custom Name"    (keywords mode - all words must be present)
--   "*pattern* > Custom Name"             (contains mode - matches if text contains pattern)
-- Returns: result, name, mode
--   mode: "exact", "keywords", or "contains"
local function parse_custom_entry(entry)
    if not entry or entry == "" then return nil, nil, nil end

    -- Split by " > " separator
    local path, name = string.match(entry, "^(.+)%s*>%s*(.+)$")
    if not path or not name then return nil, nil, nil end

    -- Trim whitespace
    path = string.gsub(path, "^%s+", "")
    path = string.gsub(path, "%s+$", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    if path == "" or name == "" then return nil, nil, nil end

    -- Check for contains mode (wrapped in *...*)
    if string.sub(path, 1, 1) == "*" and string.sub(path, -1) == "*" and #path > 2 then
        local pattern = string.sub(path, 2, -2)  -- Remove * from both ends
        pattern = string.gsub(pattern, "^%s+", "")  -- Trim leading space
        pattern = string.gsub(pattern, "%s+$", "")  -- Trim trailing space

        if pattern ~= "" then
            return string.lower(pattern), name, "contains"
        else
            return nil, nil, nil
        end
    end

    -- Check for keywords mode (starts with + or ~)
    if string.sub(path, 1, 1) == "+" or string.sub(path, 1, 1) == "~" then
        local keywords_str = string.sub(path, 2)  -- Remove +/~ prefix
        keywords_str = string.gsub(keywords_str, "^%s+", "")  -- Trim leading space

        local keywords = {}
        for word in string.gmatch(keywords_str, "%S+") do
            table.insert(keywords, string.lower(word))
        end

        if #keywords > 0 then
            return keywords, name, "keywords"
        else
            return nil, nil, nil
        end
    end

    -- Exact match mode: extract just the executable name from full path
    -- Handle both forward and back slashes
    local exe = string.match(path, "([^/\\]+)$") or path
    -- Remove .exe extension if present
    exe = string.gsub(exe, "%.[eE][xX][eE]$", "")

    return string.lower(exe), name, "exact"
end

-- Load custom names from OBS data array
local function load_custom_names(settings)
    CUSTOM_NAMES_EXACT = {}
    CUSTOM_NAMES_KEYWORDS = {}
    CUSTOM_NAMES_CONTAINS = {}

    local array = obs.obs_data_get_array(settings, "custom_names")
    if not array then return end

    local count = obs.obs_data_array_count(array)
    for i = 0, count - 1 do
        local item = obs.obs_data_array_item(array, i)
        local entry = obs.obs_data_get_string(item, "value")
        obs.obs_data_release(item)

        local result, name, mode = parse_custom_entry(entry)
        if result and name and mode then
            if mode == "keywords" then
                -- Keywords mode: result is a table of keywords
                table.insert(CUSTOM_NAMES_KEYWORDS, {
                    keywords = result,
                    name = name
                })
            elseif mode == "contains" then
                -- Contains mode: result is a pattern string
                table.insert(CUSTOM_NAMES_CONTAINS, {
                    pattern = result,
                    name = name
                })
            else
                -- Exact match mode: result is a string (exe name)
                CUSTOM_NAMES_EXACT[result] = name
            end
        end
    end

    obs.obs_data_array_release(array)
end

-- Check if text contains all keywords (case-insensitive)
local function matches_keywords(text, keywords)
    local lower = string.lower(text)
    for _, keyword in ipairs(keywords) do
        if not string.find(lower, keyword, 1, true) then
            return false  -- Missing keyword
        end
    end
    return true  -- All keywords found
end

-- Check if text contains pattern (case-insensitive)
local function matches_contains(text, pattern)
    if not text or not pattern then return false end
    local lower_text = string.lower(text)
    return string.find(lower_text, pattern, 1, true) ~= nil
end

-- Check if a process/window matches any custom name
-- Supports exact match, keywords mode, and contains mode
-- window_title is optional - used for contains mode matching
local function get_custom_name(process_name, window_title)
    if not process_name or process_name == "" then return nil end

    local lower = string.lower(process_name)
    -- Remove .exe if present for exact matching
    local lower_no_ext = string.gsub(lower, "%.[eE][xX][eE]$", "")

    -- 1. Try exact match first (fast, highest priority)
    if CUSTOM_NAMES_EXACT[lower_no_ext] then
        return CUSTOM_NAMES_EXACT[lower_no_ext]
    end

    -- 2. Try contains matching (checks both process name AND window title)
    -- This is perfect for games with version numbers in window titles
    for _, entry in ipairs(CUSTOM_NAMES_CONTAINS) do
        -- Check process name first
        if matches_contains(process_name, entry.pattern) then
            return entry.name
        end
        -- Check window title if provided
        if window_title and matches_contains(window_title, entry.pattern) then
            return entry.name
        end
    end

    -- 3. Try keywords matching (check against original name with spaces/version info)
    for _, entry in ipairs(CUSTOM_NAMES_KEYWORDS) do
        if matches_keywords(process_name, entry.keywords) then
            return entry.name
        end
        -- Also check window title for keywords
        if window_title and matches_keywords(window_title, entry.keywords) then
            return entry.name
        end
    end

    return nil
end

-- ============================================================================
-- STATE
-- ============================================================================

local last_save_time = 0
local last_recording_time = 0  -- Separate cooldown for recordings
local files_moved = 0
local files_skipped = 0
local script_settings = nil  -- Store reference to settings for button callbacks

-- Recording signal handler state
local recording_signal_handler = nil
local recording_output_ref = nil

-- Store game name detected at recording start (for file splitting)
local recording_game_name = nil
local recording_folder_name = nil

-- Temporary storage for new custom name input
local new_process_name = ""
local new_folder_name = ""

-- Notification system state
local notification_hwnd = nil           -- Current notification window handle
local notification_class_registered = false
local notification_brush = nil          -- Background brush
local notification_font = nil           -- Text font
local notification_hinstance = nil      -- Module instance

-- ============================================================================
-- LOGGING (defined early for use in notification system)
-- ============================================================================

local function log(msg)
    print("[Smart Replay] " .. msg)
end

local function dbg(msg)
    if CONFIG.debug_mode then
        print("[Smart Replay DEBUG] " .. msg)
    end
end

-- ============================================================================
-- WINDOWS API
-- ============================================================================

ffi.cdef[[
    typedef unsigned long DWORD;
    typedef void* HANDLE;
    typedef void* HWND;
    typedef int BOOL;
    typedef const char* LPCSTR;
    typedef const unsigned short* LPCWSTR;
    typedef void* HINSTANCE;
    typedef void* HICON;
    typedef void* HCURSOR;
    typedef void* HBRUSH;
    typedef void* HDC;
    typedef void* HFONT;
    typedef void* HGDIOBJ;
    typedef unsigned int UINT;
    typedef long LONG;
    typedef int64_t LONG_PTR;
    typedef uint64_t UINT_PTR;
    typedef UINT_PTR WPARAM;
    typedef LONG_PTR LPARAM;
    typedef LONG_PTR LRESULT;
    typedef unsigned short WORD;
    typedef unsigned short ATOM;
    typedef unsigned char BYTE;
    typedef DWORD COLORREF;

    HWND GetForegroundWindow();
    DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
    BOOL CloseHandle(HANDLE hObject);
    DWORD GetModuleBaseNameA(HANDLE hProcess, void* hModule, char* lpBaseName, DWORD nSize);
    int GetWindowTextA(HWND hWnd, char* lpString, int nMaxCount);
    int GetWindowTextW(HWND hWnd, wchar_t* lpString, int nMaxCount);

    int MultiByteToWideChar(unsigned int CodePage, DWORD dwFlags, LPCSTR lpMultiByteStr, int cbMultiByte, LPCWSTR lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
    BOOL DeleteFileW(LPCWSTR lpFileName);

    typedef struct {
        DWORD dwFileAttributes;
        DWORD ftCreationTime_L; DWORD ftCreationTime_H;
        DWORD ftLastAccessTime_L; DWORD ftLastAccessTime_H;
        DWORD ftLastWriteTime_L; DWORD ftLastWriteTime_H;
        DWORD nFileSizeHigh;
        DWORD nFileSizeLow;
        DWORD dwReserved0;
        DWORD dwReserved1;
        char cFileName[260];
        char cAlternateFileName[14];
    } WIN32_FIND_DATAA;

    HANDLE FindFirstFileA(const char* lpFileName, WIN32_FIND_DATAA* lpFindFileData);
    BOOL FindClose(HANDLE hFindFile);

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION WINDOW API
    // ═══════════════════════════════════════════════════════════════

    typedef LRESULT (*WNDPROC)(HWND, UINT, WPARAM, LPARAM);

    typedef struct {
        UINT      cbSize;
        UINT      style;
        WNDPROC   lpfnWndProc;
        int       cbClsExtra;
        int       cbWndExtra;
        HINSTANCE hInstance;
        HICON     hIcon;
        HCURSOR   hCursor;
        HBRUSH    hbrBackground;
        LPCSTR    lpszMenuName;
        LPCSTR    lpszClassName;
        HICON     hIconSm;
    } WNDCLASSEXA;

    typedef struct {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

    // Window functions
    ATOM RegisterClassExA(const WNDCLASSEXA* lpwcx);
    BOOL UnregisterClassA(LPCSTR lpClassName, HINSTANCE hInstance);
    HWND CreateWindowExA(DWORD dwExStyle, LPCSTR lpClassName, LPCSTR lpWindowName,
                         DWORD dwStyle, int X, int Y, int nWidth, int nHeight,
                         HWND hWndParent, void* hMenu, HINSTANCE hInstance, void* lpParam);
    BOOL DestroyWindow(HWND hWnd);
    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    HWND FindWindowA(LPCSTR lpClassName, LPCSTR lpWindowName);
    BOOL UpdateWindow(HWND hWnd);
    BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags);
    BOOL SetLayeredWindowAttributes(HWND hwnd, COLORREF crKey, BYTE bAlpha, DWORD dwFlags);
    LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
    HINSTANCE GetModuleHandleA(LPCSTR lpModuleName);
    int GetSystemMetrics(int nIndex);
    BOOL InvalidateRect(HWND hWnd, const RECT* lpRect, BOOL bErase);

    // Paint structure for WM_PAINT
    typedef struct {
        HDC  hdc;
        BOOL fErase;
        RECT rcPaint;
        BOOL fRestore;
        BOOL fIncUpdate;
        BYTE rgbReserved[32];
    } PAINTSTRUCT;

    // GDI functions for drawing
    HDC GetDC(HWND hWnd);
    int ReleaseDC(HWND hWnd, HDC hDC);
    HDC BeginPaint(HWND hWnd, PAINTSTRUCT* lpPaint);
    BOOL EndPaint(HWND hWnd, const PAINTSTRUCT* lpPaint);
    HFONT CreateFontA(int cHeight, int cWidth, int cEscapement, int cOrientation,
                      int cWeight, DWORD bItalic, DWORD bUnderline, DWORD bStrikeOut,
                      DWORD iCharSet, DWORD iOutPrecision, DWORD iClipPrecision,
                      DWORD iQuality, DWORD iPitchAndFamily, LPCSTR pszFaceName);
    HGDIOBJ SelectObject(HDC hdc, HGDIOBJ h);
    BOOL DeleteObject(HGDIOBJ ho);
    int SetBkMode(HDC hdc, int mode);
    COLORREF SetTextColor(HDC hdc, COLORREF color);
    BOOL TextOutA(HDC hdc, int x, int y, LPCSTR lpString, int c);
    int DrawTextA(HDC hdc, LPCSTR lpchText, int cchText, RECT* lprc, UINT format);
    HBRUSH CreateSolidBrush(COLORREF color);
    int FillRect(HDC hDC, const RECT* lprc, HBRUSH hbr);
    BOOL GetClientRect(HWND hWnd, RECT* lpRect);

    // Sound function
    BOOL PlaySoundA(LPCSTR pszSound, HINSTANCE hmod, DWORD fdwSound);

    // Shell function for fullscreen detection
    // Returns: 0 = S_OK (success)
    // State values:
    //   1 = QUNS_NOT_PRESENT
    //   2 = QUNS_BUSY
    //   3 = QUNS_RUNNING_D3D_FULL_SCREEN (Exclusive Fullscreen!)
    //   4 = QUNS_PRESENTATION_MODE
    //   5 = QUNS_ACCEPTS_NOTIFICATIONS
    //   6 = QUNS_QUIET_TIME
    //   7 = QUNS_APP
    long SHQueryUserNotificationState(int* pquns);
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")
local psapi = ffi.load("psapi")
local gdi32 = ffi.load("gdi32")

-- Try to load optional libraries
local winmm = nil
pcall(function() winmm = ffi.load("winmm") end)

local shell32 = nil
pcall(function() shell32 = ffi.load("shell32") end)

local PROCESS_QUERY_INFORMATION = 0x0400
local PROCESS_VM_READ = 0x0010
local CP_UTF8 = 65001
local MAX_PATH = 260

-- Window style constants
local WS_POPUP = 0x80000000
local WS_VISIBLE = 0x10000000
local WS_EX_TOPMOST = 0x00000008
local WS_EX_TRANSPARENT = 0x00000020
local WS_EX_LAYERED = 0x00080000
local WS_EX_TOOLWINDOW = 0x00000080
local WS_EX_NOACTIVATE = 0x08000000

-- Other constants
local SW_HIDE = 0
local SW_SHOWNOACTIVATE = 4
local LWA_ALPHA = 0x00000002
local SM_CXSCREEN = 0
local SM_CYSCREEN = 1
local TRANSPARENT = 1
local FW_BOLD = 700
local DEFAULT_CHARSET = 1
local OUT_DEFAULT_PRECIS = 0
local CLIP_DEFAULT_PRECIS = 0
local CLEARTYPE_QUALITY = 5
local DEFAULT_PITCH = 0
local DT_CENTER = 0x00000001
local DT_VCENTER = 0x00000004
local DT_SINGLELINE = 0x00000020

-- Sound constants
local SND_ASYNC = 0x0001
local SND_ALIAS = 0x00010000
local SND_FILENAME = 0x00020000  -- Play from file
local SND_NODEFAULT = 0x0002     -- Don't play default sound if file not found

-- Fullscreen detection constants (SHQueryUserNotificationState)
local QUNS_RUNNING_D3D_FULL_SCREEN = 3  -- Exclusive fullscreen mode

-- Window message constants
local WM_PAINT = 0x000F
local WM_ERASEBKGND = 0x0014
local WM_DESTROY = 0x0002
local CS_HREDRAW = 0x0002
local CS_VREDRAW = 0x0001

-- Colors (BGR format for Windows)
local COLOR_BG = 0x00252525        -- Dark gray background
local COLOR_TEXT = 0x00FFFFFF      -- White text
local COLOR_ACCENT = 0x0000D4AA    -- Green accent (your theme color)

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

-- Notification window dimensions and identity
local NOTIFICATION_WIDTH = 300
local NOTIFICATION_HEIGHT = 70
local NOTIFICATION_MARGIN = 20
local NOTIFICATION_WINDOW_TITLE = "SmartReplayMoverNotification"

-- Animation settings
local FADE_STEP = 25           -- Alpha change per tick (higher = faster)
local FADE_MAX_ALPHA = 230     -- Maximum opacity (90%)
local FADE_INTERVAL = 20       -- Timer interval in ms (50 FPS)

-- Notification state
local notification_end_time = 0
local notification_title = ""
local notification_message = ""
local notification_alpha = 0
local notification_fade_state = "none"  -- "in", "visible", "out", "none"
local notification_window_shown = false  -- Track if ShowWindow was called

-- Custom window class (to avoid white background flash from Static class)
local NOTIFICATION_CLASS_NAME = "SmartReplayNotificationClass"
local notification_wndproc = nil  -- Must keep reference to prevent GC
local notification_class_atom = nil

-- Check if app is in exclusive fullscreen mode
local function is_exclusive_fullscreen()
    if shell32 == nil then return false end

    local ok, result = pcall(function()
        local state = ffi.new("int[1]")
        local hr = shell32.SHQueryUserNotificationState(state)
        if hr == 0 then  -- S_OK
            return state[0] == QUNS_RUNNING_D3D_FULL_SCREEN
        end
        return false
    end)

    return ok and result or false
end

-- Find and destroy any orphaned notification windows
local function destroy_orphaned_notifications()
    pcall(function()
        -- Check for orphaned windows from our custom class
        for i = 1, 10 do
            local orphan = user32.FindWindowA(NOTIFICATION_CLASS_NAME, NOTIFICATION_WINDOW_TITLE)
            if orphan == nil or orphan == ffi.cast("HWND", 0) then
                break
            end
            user32.ShowWindow(orphan, SW_HIDE)
            user32.DestroyWindow(orphan)
            dbg("Destroyed orphaned notification window (custom class)")
        end

        -- Also check for old "Static" class windows (from previous versions)
        for i = 1, 10 do
            local orphan = user32.FindWindowA("Static", NOTIFICATION_WINDOW_TITLE)
            if orphan == nil or orphan == ffi.cast("HWND", 0) then
                break
            end
            user32.ShowWindow(orphan, SW_HIDE)
            user32.DestroyWindow(orphan)
            dbg("Destroyed orphaned notification window (Static class)")
        end
    end)
end

-- Hide current notification (immediate)
local function hide_notification()
    if notification_hwnd ~= nil then
        local hwnd = notification_hwnd
        notification_hwnd = nil
        notification_fade_state = "none"
        notification_alpha = 0
        notification_window_shown = false
        pcall(function()
            user32.ShowWindow(hwnd, SW_HIDE)
            user32.DestroyWindow(hwnd)
        end)
        dbg("Notification hidden")
    end
    destroy_orphaned_notifications()
end

-- Draw notification content to a given HDC
local function draw_notification_to_hdc(hdc, hwnd)
    if hdc == nil or hwnd == nil then return end

    local rect = ffi.new("RECT")
    user32.GetClientRect(hwnd, rect)

    -- Background (dark gray)
    local bg_brush = gdi32.CreateSolidBrush(COLOR_BG)
    user32.FillRect(hdc, rect, bg_brush)
    gdi32.DeleteObject(bg_brush)

    -- Accent line (green bar on left)
    local accent_brush = gdi32.CreateSolidBrush(COLOR_ACCENT)
    local accent_rect = ffi.new("RECT", {0, 0, 4, rect.bottom})
    user32.FillRect(hdc, accent_rect, accent_brush)
    gdi32.DeleteObject(accent_brush)

    -- Title font (bold)
    local title_font = gdi32.CreateFontA(
        -15, 0, 0, 0, FW_BOLD, 0, 0, 0,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH, "Segoe UI"
    )

    local old_font = gdi32.SelectObject(hdc, title_font)
    gdi32.SetBkMode(hdc, TRANSPARENT)
    gdi32.SetTextColor(hdc, COLOR_TEXT)

    -- Draw title
    local title_rect = ffi.new("RECT", {12, 10, rect.right - 10, 30})
    user32.DrawTextA(hdc, notification_title, -1, title_rect, 0)

    -- Message font (smaller)
    local msg_font = gdi32.CreateFontA(
        -13, 0, 0, 0, 400, 0, 0, 0,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH, "Segoe UI"
    )
    gdi32.SelectObject(hdc, msg_font)
    gdi32.SetTextColor(hdc, 0x00BBBBBB)

    -- Draw message
    local msg_rect = ffi.new("RECT", {12, 34, rect.right - 10, rect.bottom - 8})
    user32.DrawTextA(hdc, notification_message, -1, msg_rect, 0)

    -- Cleanup
    gdi32.SelectObject(hdc, old_font)
    gdi32.DeleteObject(title_font)
    gdi32.DeleteObject(msg_font)
end

-- Draw notification content (wrapper for compatibility)
local function draw_notification_content()
    if notification_hwnd == nil then return end

    pcall(function()
        local hdc = user32.GetDC(notification_hwnd)
        if hdc == nil then return end
        draw_notification_to_hdc(hdc, notification_hwnd)
        user32.ReleaseDC(notification_hwnd, hdc)
    end)
end

-- Window procedure for our custom notification class
local function notification_wndproc_handler(hwnd, msg, wparam, lparam)
    -- Handle WM_PAINT - draw our content instead of default white
    if msg == WM_PAINT then
        local ps = ffi.new("PAINTSTRUCT")
        local hdc = user32.BeginPaint(hwnd, ps)
        if hdc ~= nil then
            draw_notification_to_hdc(hdc, hwnd)
            user32.EndPaint(hwnd, ps)
        end
        return 0
    end

    -- Handle WM_ERASEBKGND - prevent default erase (we draw everything in WM_PAINT)
    if msg == WM_ERASEBKGND then
        return 1  -- Tell Windows we handled it
    end

    -- Default processing for other messages
    return user32.DefWindowProcA(hwnd, msg, wparam, lparam)
end

-- Register our custom notification window class
local function register_notification_class()
    if notification_class_atom ~= nil then
        return true  -- Already registered
    end

    local ok, result = pcall(function()
        if notification_hinstance == nil then
            notification_hinstance = kernel32.GetModuleHandleA(nil)
        end

        -- Create callback (must store reference to prevent garbage collection!)
        notification_wndproc = ffi.cast("WNDPROC", notification_wndproc_handler)

        -- Create dark background brush
        local bg_brush = gdi32.CreateSolidBrush(COLOR_BG)

        -- Fill window class structure
        local wc = ffi.new("WNDCLASSEXA")
        wc.cbSize = ffi.sizeof("WNDCLASSEXA")
        wc.style = CS_HREDRAW + CS_VREDRAW
        wc.lpfnWndProc = notification_wndproc
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = notification_hinstance
        wc.hIcon = nil
        wc.hCursor = nil
        wc.hbrBackground = bg_brush  -- Dark background (prevents white flash!)
        wc.lpszMenuName = nil
        wc.lpszClassName = NOTIFICATION_CLASS_NAME
        wc.hIconSm = nil

        -- Register the class
        notification_class_atom = user32.RegisterClassExA(wc)

        if notification_class_atom == 0 then
            dbg("Failed to register notification class")
            gdi32.DeleteObject(bg_brush)
            return false
        end

        -- Store brush for cleanup (it's now owned by the class)
        notification_brush = bg_brush

        dbg("Registered custom notification class")
        return true
    end)

    return ok and result or false
end

-- Unregister our custom notification window class
local function unregister_notification_class()
    if notification_class_atom ~= nil then
        pcall(function()
            user32.UnregisterClassA(NOTIFICATION_CLASS_NAME, notification_hinstance)
        end)
        notification_class_atom = nil
    end

    if notification_brush ~= nil then
        pcall(function()
            gdi32.DeleteObject(notification_brush)
        end)
        notification_brush = nil
    end

    -- Release callback reference
    if notification_wndproc ~= nil then
        notification_wndproc:free()
        notification_wndproc = nil
    end

    dbg("Unregistered notification class")
end

-- Animation timer callback
local function notification_timer_callback()
    if notification_hwnd == nil then
        obs.timer_remove(notification_timer_callback)
        notification_fade_state = "none"
        return
    end

    -- Handle fade states
    if notification_fade_state == "in" then
        -- Fade in animation
        notification_alpha = notification_alpha + FADE_STEP
        if notification_alpha >= FADE_MAX_ALPHA then
            notification_alpha = FADE_MAX_ALPHA
            notification_fade_state = "visible"
        end

        -- Set alpha BEFORE showing window (prevents flash)
        user32.SetLayeredWindowAttributes(notification_hwnd, 0, notification_alpha, LWA_ALPHA)

        -- Show window only after first fade step
        if not notification_window_shown then
            -- Trigger WM_PAINT to draw content with our dark background
            user32.InvalidateRect(notification_hwnd, nil, 0)
            user32.ShowWindow(notification_hwnd, SW_SHOWNOACTIVATE)
            notification_window_shown = true
        end

    elseif notification_fade_state == "visible" then
        -- Check if it's time to start fading out
        if os.time() >= notification_end_time then
            notification_fade_state = "out"
        end
        -- Trigger repaint via WM_PAINT (our custom class handles it properly)
        user32.InvalidateRect(notification_hwnd, nil, 0)

    elseif notification_fade_state == "out" then
        -- Fade out animation
        notification_alpha = notification_alpha - FADE_STEP
        if notification_alpha <= 0 then
            notification_alpha = 0
            hide_notification()
            obs.timer_remove(notification_timer_callback)
            dbg("Notification fade-out complete")
            return
        end
        user32.SetLayeredWindowAttributes(notification_hwnd, 0, notification_alpha, LWA_ALPHA)
    end
end

-- Show notification popup
local function show_notification(title, message)
    if not CONFIG.show_notifications then return end

    -- Check if in exclusive fullscreen - skip popup, only sound
    if is_exclusive_fullscreen() then
        dbg("Exclusive fullscreen detected - skipping popup")
        return
    end

    -- Hide existing notification first
    hide_notification()
    obs.timer_remove(notification_timer_callback)

    -- Store for redrawing
    notification_title = title or "Notification"
    notification_message = message or ""
    notification_end_time = os.time() + math.ceil(CONFIG.notification_duration)
    notification_alpha = 0
    notification_fade_state = "in"
    notification_window_shown = false

    local ok, err = pcall(function()
        if notification_hinstance == nil then
            notification_hinstance = kernel32.GetModuleHandleA(nil)
        end

        -- Register our custom window class (once)
        if not register_notification_class() then
            dbg("Failed to register notification class, cannot show popup")
            return
        end

        -- Position (top-right corner)
        local screen_width = user32.GetSystemMetrics(SM_CXSCREEN)
        local x = screen_width - NOTIFICATION_WIDTH - NOTIFICATION_MARGIN
        local y = NOTIFICATION_MARGIN

        -- Window styles
        local ex_style = WS_EX_TOPMOST + WS_EX_TOOLWINDOW + WS_EX_NOACTIVATE + WS_EX_LAYERED + WS_EX_TRANSPARENT

        destroy_orphaned_notifications()

        -- Create window using our custom class (dark background, no white flash!)
        notification_hwnd = user32.CreateWindowExA(
            ex_style,
            NOTIFICATION_CLASS_NAME,  -- Our custom class instead of "Static"
            NOTIFICATION_WINDOW_TITLE,
            WS_POPUP,
            x, y,
            NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT,
            nil, nil,
            notification_hinstance,
            nil
        )

        if notification_hwnd == nil then
            dbg("CreateWindowExA failed")
            return
        end

        -- Start fully transparent (for fade-in)
        user32.SetLayeredWindowAttributes(notification_hwnd, 0, 0, LWA_ALPHA)

        -- Start animation timer (fast for smooth fade)
        -- WM_PAINT will handle drawing with our dark background
        obs.timer_add(notification_timer_callback, FADE_INTERVAL)

        dbg("Notification shown: " .. title .. " | " .. message)
    end)

    if not ok then
        dbg("Failed to show notification: " .. tostring(err))
    end
end

-- Play notification sound (from file or system)
local function play_notification_sound()
    if not CONFIG.play_sound then return end
    if winmm == nil then return end

    pcall(function()
        -- Try custom sound file first (in same directory as script)
        if SCRIPT_DIR and SCRIPT_DIR ~= "" then
            local sound_file = SCRIPT_DIR .. "notification_sound.wav"
            -- Try to play from file (SND_NODEFAULT = don't play if file not found)
            local result = winmm.PlaySoundA(sound_file, nil, SND_FILENAME + SND_ASYNC + SND_NODEFAULT)
            if result ~= 0 then
                dbg("Playing custom sound: " .. sound_file)
                return
            end
        end

        -- Fallback to system sound
        winmm.PlaySoundA("SystemNotification", nil, SND_ALIAS + SND_ASYNC)
        dbg("Playing system notification sound")
    end)
end

-- Combined notification function
local function notify(title, message)
    -- Always try to play sound (works in fullscreen too)
    play_notification_sound()
    -- Show popup (will be skipped if exclusive fullscreen)
    show_notification(title, message)
end

-- Cleanup notification resources
local function cleanup_notifications()
    obs.timer_remove(notification_timer_callback)
    hide_notification()
    -- Unregister our custom window class
    unregister_notification_class()
end

-- ============================================================================
-- HELPER FUNCTIONS (Handle validation)
-- ============================================================================

-- Helper to check if a handle is invalid (INVALID_HANDLE_VALUE = -1)
local function is_invalid_handle(handle)
    if handle == nil then return true end
    -- Cast to number for reliable comparison
    local handle_val = tonumber(ffi.cast("intptr_t", handle))
    return handle_val == -1 or handle_val == 0
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function clean_name(str)
    if not str or str == "" then return "Unknown" end
    str = string.gsub(str, '[<>:"/\\|?*]', "")
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    if str == "" then return "Unknown" end
    return str
end

-- Truncate filename to fit within MAX_PATH limit
-- Preserves file extension and adds ellipsis indicator
local function truncate_filename(filename, max_len)
    if not filename or #filename <= max_len then
        return filename
    end

    -- Extract extension
    local name, ext = string.match(filename, "^(.+)(%.%w+)$")
    if not name then
        name = filename
        ext = ""
    end

    -- Calculate how much we can keep (reserve space for "..." and extension)
    local keep_len = max_len - 3 - #ext
    if keep_len < 10 then
        keep_len = 10  -- Minimum meaningful name length
    end

    return string.sub(name, 1, keep_len) .. "..." .. ext
end

-- Validate that path length is within Windows limits
local function validate_path_length(path)
    if not path then return false, "Path is nil" end
    if #path > MAX_PATH then
        return false, "Path exceeds MAX_PATH (" .. MAX_PATH .. "): " .. #path .. " chars"
    end
    return true, nil
end

local function is_ignored(name)
    if not name or name == "" then return true end
    local lower = string.lower(name)
    for _, ignored in ipairs(IGNORE_LIST) do
        if string.find(lower, ignored, 1, true) then
            return true
        end
    end
    return false
end

local function get_game_folder(raw_name, window_title)
    if not raw_name or raw_name == "" then
        return CONFIG.fallback_folder
    end

    -- Check custom names first (highest priority)
    -- Pass both process name and window title for contains/keywords matching
    local custom = get_custom_name(raw_name, window_title)
    if custom then
        dbg("Custom name match: " .. raw_name .. " -> " .. custom)
        return custom
    end

    local lower = string.lower(raw_name)

    -- Check exact matches
    if GAME_NAMES[lower] then
        return GAME_NAMES[lower]
    end

    -- Check patterns
    for _, pattern in ipairs(GAME_PATTERNS) do
        if string.find(lower, pattern[1], 1, true) then
            return pattern[2]
        end
    end

    -- Use raw name if no match
    return clean_name(raw_name)
end

-- ============================================================================
-- GAME DETECTION
-- ============================================================================

local function get_active_process()
    local ok, result = pcall(function()
        local hwnd = user32.GetForegroundWindow()
        if not hwnd then return nil end

        local pid = ffi.new("DWORD[1]")
        user32.GetWindowThreadProcessId(hwnd, pid)

        local process = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION + PROCESS_VM_READ, 0, pid[0])
        if is_invalid_handle(process) then return nil end

        local buffer = ffi.new("char[260]")
        local len = psapi.GetModuleBaseNameA(process, nil, buffer, 260)
        kernel32.CloseHandle(process)

        if len > 0 then
            local name = ffi.string(buffer)
            return string.gsub(name, "%.[eE][xX][eE]$", "")
        end
        return nil
    end)

    return ok and result or nil
end

-- Helper to convert UTF-16 (wide string) to UTF-8
local function wide_to_utf8(wide_buffer, wide_len)
    if wide_len <= 0 then return nil end

    -- First call: get required buffer size
    local size_needed = kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_buffer, wide_len, nil, 0, nil, nil)
    if size_needed <= 0 then return nil end

    -- Second call: perform conversion
    local utf8_buffer = ffi.new("char[?]", size_needed + 1)
    local result = kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_buffer, wide_len, utf8_buffer, size_needed, nil, nil)

    if result > 0 then
        return ffi.string(utf8_buffer, result)
    end
    return nil
end

local function get_window_title()
    local ok, result = pcall(function()
        local hwnd = user32.GetForegroundWindow()
        if not hwnd then return nil end

        -- Use wide (Unicode) version for proper international character support
        local wide_buffer = ffi.new("wchar_t[256]")
        local len = user32.GetWindowTextW(hwnd, wide_buffer, 256)

        if len > 0 then
            return wide_to_utf8(wide_buffer, len)
        end
        return nil
    end)

    return ok and result or nil
end

local function find_game_in_obs()
    local sources = obs.obs_enum_sources()
    if not sources then
        dbg("find_game_in_obs: No sources found")
        return nil
    end

    local found = nil

    for _, source in ipairs(sources) do
        local id = obs.obs_source_get_id(source)
        local name = obs.obs_source_get_name(source)

        -- Check game_capture sources
        if id == "game_capture" then
            local settings = obs.obs_source_get_settings(source)
            local window = obs.obs_data_get_string(settings, "window")
            local mode = obs.obs_data_get_string(settings, "capture_mode")
            local active_window = obs.obs_data_get_string(settings, "active_window")
            obs.obs_data_release(settings)

            dbg("Game Capture '" .. (name or "?") .. "': mode=" .. (mode or "nil") .. ", window=" .. (window or "nil"))

            -- Try window field first (for "Capture specific window" mode)
            if window and window ~= "" then
                local exe = string.match(window, "([^:]+)$")
                if exe then
                    found = string.gsub(exe, "%.[eE][xX][eE]$", "")
                    dbg("Found game from window field: " .. found)
                    break
                end
            end

            -- For "Capture any fullscreen application" mode, we need to check if source is active
            -- and try to get the hooked executable name from the source properties
            if not found then
                -- Try to get the currently captured window from the source's private data
                local proc_handler = obs.obs_source_get_proc_handler(source)
                if proc_handler then
                    local cd = obs.calldata_create()
                    -- Try to call get_hooked_process (if available)
                    if obs.proc_handler_call(proc_handler, "get_hooked", cd) then
                        local hooked = obs.calldata_string(cd, "hooked_exe")
                        if hooked and hooked ~= "" then
                            found = string.gsub(hooked, "%.[eE][xX][eE]$", "")
                            dbg("Found game from hooked process: " .. found)
                        end
                    end
                    obs.calldata_destroy(cd)
                end
            end
        end
    end

    obs.source_list_release(sources)

    if not found then
        dbg("find_game_in_obs: No game found in any Game Capture source")
    end

    return found
end

-- Detect active game
-- Returns: process_or_game_name, window_title (both can be nil)
-- The window_title is always returned separately for wildcard matching
local function detect_game()
    local process = get_active_process()
    local title = get_window_title()
    local window_title_for_matching = title

    -- 1. Try active window process first
    if process and not is_ignored(process) then
        dbg("Detected from active process: " .. process)
        if title then
            dbg("Window title available: " .. title)
        end
        return process, window_title_for_matching
    end

    -- 2. Try window title as identifier
    if title and not is_ignored(title) then
        dbg("Detected from window title: " .. title)
        return title, window_title_for_matching
    end

    -- 3. Try OBS game capture source (fallback - works when "Capture specific window" mode)
    local obs_game = find_game_in_obs()
    if obs_game and not is_ignored(obs_game) then
        dbg("Detected from OBS Game Capture: " .. obs_game)
        return obs_game, window_title_for_matching
    end

    return nil, window_title_for_matching
end

-- ============================================================================
-- FILE OPERATIONS
-- ============================================================================

local function get_existing_folder(root, name)
    local ok, result = pcall(function()
        local search = root .. "/" .. name
        search = string.gsub(search, "/", "\\")

        local data = ffi.new("WIN32_FIND_DATAA")
        local handle = kernel32.FindFirstFileA(search, data)

        if not is_invalid_handle(handle) then
            local real = ffi.string(data.cFileName)
            kernel32.FindClose(handle)
            if real ~= "." and real ~= ".." then
                return real
            end
        end
        return name
    end)

    return ok and result or name
end

local function delete_file(path)
    local ok, err = pcall(function()
        path = string.gsub(path, "/", "\\")
        local len = kernel32.MultiByteToWideChar(CP_UTF8, 0, path, -1, nil, 0)
        if len > 0 and len <= MAX_PATH then
            local wpath = ffi.new("unsigned short[?]", len)
            kernel32.MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, len)
            local result = kernel32.DeleteFileW(wpath)
            if result == 0 then
                error("DeleteFileW failed")
            end
        elseif len > MAX_PATH then
            error("Path exceeds MAX_PATH limit: " .. len .. " chars")
        end
    end)

    if not ok then
        dbg("Windows delete failed, trying os.remove: " .. tostring(err))
        os.remove(path)
    end
end

-- Create directory with race condition protection
local function safe_mkdir(path)
    -- Check if already exists
    if obs.os_file_exists(path) then
        return true
    end

    -- Try to create it
    local result = obs.os_mkdir(path)

    -- Double-check it exists (handles race condition where another process created it)
    if obs.os_file_exists(path) then
        return true
    end

    return result
end

-- Get file size (returns 0 if file doesn't exist or error)
local function get_file_size(path)
    local ok, result = pcall(function()
        path = string.gsub(path, "/", "\\")
        local data = ffi.new("WIN32_FIND_DATAA")
        local handle = kernel32.FindFirstFileA(path, data)

        if not is_invalid_handle(handle) then
            kernel32.FindClose(handle)
            -- Combine high and low parts for full size
            local size = data.nFileSizeHigh * 4294967296 + data.nFileSizeLow
            return size
        end
        return 0
    end)
    return ok and result or 0
end

local function move_file(src, folder_name, game_name)
    src = string.gsub(src, "\\", "/")

    local dir, filename = string.match(src, "^(.*)/(.*)$")
    if not dir or not filename then
        log("ERROR: Cannot parse source path - invalid format: " .. tostring(src))
        return false
    end

    -- Check source file exists
    if not obs.os_file_exists(src) then
        log("ERROR: Source file does not exist: " .. src)
        return false
    end

    -- Check file size (prevent moving incomplete/corrupted files)
    local file_size = get_file_size(src)
    if file_size == 0 then
        log("WARNING: Source file appears empty or inaccessible: " .. src)
        -- Continue anyway - file might just be very small
    elseif file_size < 1024 then
        dbg("File is very small (" .. file_size .. " bytes), might be incomplete")
    end

    -- Get real folder name (case-sensitive check)
    local safe_folder = clean_name(folder_name)
    local real_folder = get_existing_folder(dir, safe_folder)
    local target_dir = dir .. "/" .. real_folder

    -- Add date subfolder if enabled
    if CONFIG.use_date_subfolders then
        target_dir = target_dir .. "/" .. os.date("%Y-%m")
    end

    -- Create new filename with game prefix
    local new_filename = filename
    local should_add_prefix = CONFIG.add_game_prefix and game_name and game_name ~= "" and game_name ~= CONFIG.fallback_folder

    dbg("Prefix check: add_game_prefix=" .. tostring(CONFIG.add_game_prefix) ..
          ", game_name=" .. tostring(game_name) ..
          ", fallback=" .. tostring(CONFIG.fallback_folder) ..
          ", will_add=" .. tostring(should_add_prefix))

    if should_add_prefix then
        local safe_game = clean_name(game_name)
        new_filename = safe_game .. " - " .. filename
        dbg("Added prefix: " .. new_filename)
    end

    local target_path = target_dir .. "/" .. new_filename

    -- Validate path length and truncate filename if needed
    local valid, err = validate_path_length(target_path)
    if not valid then
        dbg("Path too long, truncating filename: " .. err)
        -- Calculate max filename length based on directory length
        local max_filename_len = MAX_PATH - #target_dir - 2  -- -2 for "/" and null terminator
        if max_filename_len < 20 then
            log("ERROR: Directory path too long, cannot fit filename: " .. target_dir)
            return false
        end
        new_filename = truncate_filename(new_filename, max_filename_len)
        target_path = target_dir .. "/" .. new_filename
        dbg("Truncated filename to: " .. new_filename)
    end

    -- Create directories with race condition protection
    local base_folder = dir .. "/" .. real_folder
    if not safe_mkdir(base_folder) then
        log("ERROR: Failed to create folder: " .. base_folder)
        return false
    end
    dbg("Folder ready: " .. base_folder)

    if CONFIG.use_date_subfolders then
        if not safe_mkdir(target_dir) then
            log("ERROR: Failed to create date subfolder: " .. target_dir)
            return false
        end
        dbg("Date subfolder ready: " .. target_dir)
    end

    -- Move file
    if obs.os_rename(src, target_path) then
        log("Moved: " .. new_filename)
        log("To: " .. target_dir)
        if file_size > 0 then
            dbg("File size: " .. string.format("%.2f", file_size / 1024 / 1024) .. " MB")
        end
        files_moved = files_moved + 1
        return true
    end

    log("ERROR: Failed to move file")
    log("  From: " .. src)
    log("  To: " .. target_path)
    return false
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function get_replay_path()
    local replay = obs.obs_frontend_get_replay_buffer_output()
    if not replay then return nil end

    local cd = obs.calldata_create()
    local ph = obs.obs_output_get_proc_handler(replay)
    obs.proc_handler_call(ph, "get_last_replay", cd)
    local path = obs.calldata_string(cd, "path")
    obs.calldata_destroy(cd)
    obs.obs_output_release(replay)

    return path
end

-- Get the last recording file path
local function get_recording_path()
    local path = obs.obs_frontend_get_last_recording()
    return path
end

local function process_file(path)
    if not path or path == "" then
        log("ERROR: No file path provided")
        return
    end

    -- Detect game (now returns both process name and window title)
    local raw_game, window_title = detect_game()
    local folder_name = get_game_folder(raw_game, window_title)

    if raw_game then
        log("Game: " .. raw_game .. " -> " .. folder_name)
    else
        log("No game detected, using: " .. folder_name)
    end

    -- Move file (pass folder_name as game_name for prefix)
    move_file(path, folder_name, folder_name)
end

-- Process file with pre-detected game info (for file splitting during recording)
local function process_file_with_game(path, folder_name, game_name)
    if not path or path == "" then
        log("ERROR: No file path provided")
        return
    end

    if not folder_name then
        -- Fallback to current detection if no cached game info
        process_file(path)
        return
    end

    log("Using cached game: " .. folder_name)
    move_file(path, folder_name, game_name or folder_name)
end

-- ============================================================================
-- RECORDING SIGNAL HANDLERS (for file splitting support)
-- ============================================================================

-- Callback for "file_changed" signal (file splitting)
local function on_recording_file_changed(calldata)
    if not CONFIG.organize_recordings then
        return
    end

    -- Get the previous (completed) file path from signal
    local prev_file = obs.calldata_string(calldata, "next_file")
    -- Note: OBS sends the "next_file" parameter, but we want to move the OLD file
    -- The old file path is not directly provided, so we use last_recording

    -- Actually, we need to get the file that just finished
    -- In file splitting, the signal fires AFTER the split happens
    -- The "next_file" is the NEW file being written to

    dbg("File split signal received, next_file: " .. tostring(prev_file))

    -- We need to track the previous file ourselves
    -- For now, we'll use a small delay and check for the file
    -- This is handled by storing the current recording path when recording starts

    -- Use the cached game name from when recording started
    if recording_folder_name then
        -- Get the recording output to find the previous file
        local recording = obs.obs_frontend_get_recording_output()
        if recording then
            -- The "next_file" is the new file, we need the previous segment
            -- OBS doesn't directly provide the old file in the signal
            -- We'll rely on OBS_FRONTEND_EVENT_RECORDING_STOPPED for final file
            -- and handle splits via a timer-based approach
            obs.obs_output_release(recording)
        end

        log("File split detected - using cached game: " .. recording_folder_name)
    end
end

-- Disconnect recording signals
-- NOTE: This function MUST be defined BEFORE connect_recording_signals()
-- because connect calls disconnect to clean up any existing handlers first
local function disconnect_recording_signals()
    if recording_signal_handler then
        obs.signal_handler_disconnect(recording_signal_handler, "file_changed", on_recording_file_changed)
        recording_signal_handler = nil
    end

    if recording_output_ref then
        obs.obs_output_release(recording_output_ref)
        recording_output_ref = nil
    end

    dbg("Disconnected recording signals")
end

-- Connect to recording output signals
local function connect_recording_signals()
    -- Disconnect any existing handler first
    disconnect_recording_signals()

    local recording = obs.obs_frontend_get_recording_output()
    if not recording then
        dbg("No recording output available to connect signals")
        return false
    end

    local sh = obs.obs_output_get_signal_handler(recording)
    if not sh then
        dbg("Could not get signal handler from recording output")
        obs.obs_output_release(recording)
        return false
    end

    -- Connect to file_changed signal for file splitting
    obs.signal_handler_connect(sh, "file_changed", on_recording_file_changed)

    -- Store reference to release later
    recording_output_ref = recording
    recording_signal_handler = sh

    dbg("Connected to recording file_changed signal")
    return true
end

-- ============================================================================
-- SPLIT FILE TRACKING
-- ============================================================================

-- Table to track split files during recording
local split_files = {}
local current_recording_file = nil

-- Timer callback to check for new split files
local function check_split_files()
    if not CONFIG.organize_recordings then
        return
    end

    local recording = obs.obs_frontend_get_recording_output()
    if not recording then
        return
    end

    -- Get current recording file
    local cd = obs.calldata_create()
    local ph = obs.obs_output_get_proc_handler(recording)

    if ph then
        -- Try to get the current file being recorded
        local success = obs.proc_handler_call(ph, "get_last_file", cd)
        if success then
            local current_file = obs.calldata_string(cd, "path")
            if current_file and current_file ~= "" and current_file ~= current_recording_file then
                -- File changed! Move the previous one
                if current_recording_file and obs.os_file_exists(current_recording_file) then
                    log("Split detected: moving previous segment")
                    process_file_with_game(current_recording_file, recording_folder_name, recording_game_name)
                end
                current_recording_file = current_file
                dbg("Now recording to: " .. current_file)
            end
        end
    end

    obs.calldata_destroy(cd)
    obs.obs_output_release(recording)
end

-- ============================================================================
-- FRONTEND EVENT HANDLER
-- ============================================================================

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        local now = os.time()
        local diff = now - last_save_time

        local path = get_replay_path()

        -- Spam protection
        if diff < CONFIG.duplicate_cooldown then
            log("Spam detected (" .. string.format("%.1f", diff) .. "s)")
            if CONFIG.delete_spam_files and path then
                delete_file(path)
                log("Duplicate deleted")
            end
            files_skipped = files_skipped + 1
            return
        end

        last_save_time = now

        if path then
            -- Detect game for notification before processing
            local raw_game, window_title = detect_game()
            local folder_name = get_game_folder(raw_game, window_title)

            process_file(path)

            -- Show notification
            notify("Clip Saved", "Moved to: " .. folder_name)
        end

    elseif event == obs.OBS_FRONTEND_EVENT_SCREENSHOT_TAKEN then
        if CONFIG.organize_screenshots then
            local path = obs.obs_frontend_get_last_screenshot()
            if path then
                process_file(path)
            end
        end

    -- ═══════════════════════════════════════════════════════════════
    -- NEW: Recording support
    -- ═══════════════════════════════════════════════════════════════

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTING then
        -- Cache current game when recording starts (for file splitting)
        if CONFIG.organize_recordings then
            local raw_game, window_title = detect_game()
            recording_game_name = raw_game
            recording_folder_name = get_game_folder(raw_game, window_title)
            current_recording_file = nil

            if raw_game then
                log("Recording starting - Game detected: " .. raw_game .. " -> " .. recording_folder_name)
            else
                log("Recording starting - No game detected, using: " .. recording_folder_name)
            end

            -- Connect to file splitting signals
            -- Note: We do this in RECORDING_STARTED instead because output may not be ready yet
        end

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        if CONFIG.organize_recordings then
            -- Try to connect to recording signals for file splitting
            connect_recording_signals()

            -- Get initial recording file path and store it
            local recording = obs.obs_frontend_get_recording_output()
            if recording then
                -- Try to get the initial file path
                local cd = obs.calldata_create()
                local ph = obs.obs_output_get_proc_handler(recording)
                if ph then
                    obs.proc_handler_call(ph, "get_last_file", cd)
                    current_recording_file = obs.calldata_string(cd, "path")
                    if current_recording_file and current_recording_file ~= "" then
                        dbg("Initial recording file: " .. current_recording_file)
                    end
                end
                obs.calldata_destroy(cd)
                obs.obs_output_release(recording)
            end

            -- Start timer to check for file splits (every 1 second)
            obs.timer_add(check_split_files, 1000)

            log("Recording started - monitoring for file splits")

            -- Show notification
            local game_info = recording_folder_name or CONFIG.fallback_folder
            notify("Recording Started", "Game: " .. game_info)
        end

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        if CONFIG.organize_recordings then
            -- Stop the file split checking timer FIRST
            obs.timer_remove(check_split_files)

            local now = os.time()
            local diff = now - last_recording_time

            local path = get_recording_path()

            -- Spam protection for recordings
            if diff < CONFIG.duplicate_cooldown then
                log("Recording spam detected (" .. string.format("%.1f", diff) .. "s)")
                if CONFIG.delete_spam_files and path then
                    delete_file(path)
                    log("Duplicate recording deleted")
                end
                files_skipped = files_skipped + 1
            else
                last_recording_time = now

                -- Store folder name before clearing for notification
                local saved_folder = recording_folder_name or CONFIG.fallback_folder

                if path then
                    log("Recording stopped - organizing file")
                    -- Use cached game name if available, otherwise detect current
                    if recording_folder_name then
                        process_file_with_game(path, recording_folder_name, recording_game_name)
                    else
                        process_file(path)
                    end

                    -- Show notification
                    notify("Recording Saved", "Moved to: " .. saved_folder)
                end
            end

            -- Disconnect signals
            disconnect_recording_signals()

            -- Clear cached game info
            recording_game_name = nil
            recording_folder_name = nil
            current_recording_file = nil
        end
    end
end

-- ============================================================================
-- IMPORT/EXPORT AND ADD MAPPING FUNCTIONS
-- ============================================================================

-- Add a new custom name mapping from the two input fields
local function add_custom_mapping(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end

    -- Get values from the input fields
    local process = obs.obs_data_get_string(script_settings, "new_process_name")
    local folder = obs.obs_data_get_string(script_settings, "new_folder_name")

    -- Trim whitespace
    process = string.gsub(process or "", "^%s+", "")
    process = string.gsub(process, "%s+$", "")
    folder = string.gsub(folder or "", "^%s+", "")
    folder = string.gsub(folder, "%s+$", "")

    -- Validate input
    if process == "" then
        log("ERROR: Please enter a process name (from Task Manager)")
        return false
    end
    if folder == "" then
        log("ERROR: Please enter a folder name")
        return false
    end

    -- Create the entry in the format: process > folder
    local entry = process .. " > " .. folder

    -- Get existing array or create new one
    local array = obs.obs_data_get_array(script_settings, "custom_names")
    if not array then
        array = obs.obs_data_array_create()
    end

    -- Add new entry
    local item = obs.obs_data_create()
    obs.obs_data_set_string(item, "value", entry)
    obs.obs_data_array_push_back(array, item)
    obs.obs_data_release(item)

    obs.obs_data_set_array(script_settings, "custom_names", array)
    obs.obs_data_array_release(array)

    -- Clear the input fields
    obs.obs_data_set_string(script_settings, "new_process_name", "")
    obs.obs_data_set_string(script_settings, "new_folder_name", "")

    -- Reload custom names
    load_custom_names(script_settings)

    log("Added custom mapping: " .. process .. " -> " .. folder)
    return true  -- Refresh properties to show new entry
end

-- Get default export path
local function get_default_export_path()
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "C:"
    return home .. "\\smart_replay_custom_names.txt"
end

-- Export custom names to a text file
local function export_custom_names(path)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end

    -- Use default path if none specified
    if not path or path == "" then
        path = get_default_export_path()
        log("Using default export path: " .. path)
    end

    local file, err = io.open(path, "w")
    if not file then
        log("ERROR: Cannot open file for export: " .. tostring(err))
        log("Try specifying a different path or check write permissions")
        return false
    end

    -- Write header
    file:write("# Smart Replay Mover - Custom Names Export\n")
    file:write("# Format: process_name > Folder Name\n")
    file:write("# Lines starting with # are comments\n\n")

    -- Write each custom name entry
    local count = 0
    local array = obs.obs_data_get_array(script_settings, "custom_names")
    if array then
        local arr_count = obs.obs_data_array_count(array)
        for i = 0, arr_count - 1 do
            local item = obs.obs_data_array_item(array, i)
            local entry = obs.obs_data_get_string(item, "value")
            obs.obs_data_release(item)

            if entry and entry ~= "" then
                file:write(entry .. "\n")
                count = count + 1
            end
        end
        obs.obs_data_array_release(array)
    end

    file:close()

    if count > 0 then
        log("Exported " .. count .. " custom name(s) to: " .. path)
    else
        log("No custom names to export. File created at: " .. path)
    end
    return true
end

-- Import custom names from a text file
local function import_custom_names(path, props)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end

    if not path or path == "" then
        log("ERROR: Please specify a file path to import from")
        return false
    end

    local file, err = io.open(path, "r")
    if not file then
        log("ERROR: Cannot open file for import: " .. tostring(err))
        return false
    end

    local entries = {}
    local count = 0

    for line in file:lines() do
        -- Skip empty lines and comments
        local trimmed = string.gsub(line, "^%s+", "")
        trimmed = string.gsub(trimmed, "%s+$", "")

        if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
            -- Validate format
            local exe, name = parse_custom_entry(trimmed)
            if exe and name then
                table.insert(entries, trimmed)
                count = count + 1
            else
                log("WARNING: Skipping invalid line: " .. trimmed)
            end
        end
    end

    file:close()

    -- Add entries to settings
    if count > 0 then
        -- Get existing array or create new one
        local array = obs.obs_data_get_array(script_settings, "custom_names")
        if not array then
            array = obs.obs_data_array_create()
        end

        -- Add new entries
        for _, entry in ipairs(entries) do
            local item = obs.obs_data_create()
            obs.obs_data_set_string(item, "value", entry)
            obs.obs_data_array_push_back(array, item)
            obs.obs_data_release(item)
        end

        obs.obs_data_set_array(script_settings, "custom_names", array)
        obs.obs_data_array_release(array)

        -- Reload custom names
        load_custom_names(script_settings)
        log("Imported " .. count .. " custom name(s) from: " .. path)
    else
        log("No valid entries found in file")
    end

    return true
end

-- Button callback for export
local function on_export_clicked(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end
    local path = obs.obs_data_get_string(script_settings, "import_export_path")
    export_custom_names(path)
    return false
end

-- Button callback for import
local function on_import_clicked(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end
    local path = obs.obs_data_get_string(script_settings, "import_export_path")
    -- If no path specified, use default export location
    if path == "" then
        path = get_default_export_path()
        log("No path specified, using default: " .. path)
    end
    import_custom_names(path, props)
    return true  -- Refresh properties to show new entries
end

-- ============================================================================
-- OBS INTERFACE
-- ============================================================================

function script_description()
    return [[
<center>
<p style="font-size:24px; font-weight:bold; color:#00d4aa;">SMART REPLAY MOVER</p>
<p style="color:#888;">Automatic Game Clip Organizer for OBS v2.6.2</p>
</center>

<hr style="border-color:#333;">

<table width="100%">
<tr><td width="50%" valign="top">
<p style="color:#00d4aa; font-weight:bold;">AUTOMATIC DETECTION</p>
<p style="font-size:11px;">
Detects active game from process<br>
Supports 80+ popular games<br>
Smart ignore list for non-games
</p>
</td><td width="50%" valign="top">
<p style="color:#ff6b6b; font-weight:bold;">SMART ORGANIZATION</p>
<p style="font-size:11px;">
Creates game-named folders<br>
Adds game prefix to filenames<br>
Optional date subfolders
</p>
</td></tr>
<tr><td width="50%" valign="top">
<p style="color:#ffd93d; font-weight:bold;">RECORDINGS & REPLAYS</p>
<p style="font-size:11px;">
Organizes replay buffer clips<br>
<b>NEW:</b> Supports regular recordings<br>
<b>NEW:</b> File splitting support
</p>
</td><td width="50%" valign="top">
<p style="color:#6bcfff; font-weight:bold;">SPAM PROTECTION</p>
<p style="font-size:11px;">
Prevents duplicate saves<br>
Configurable cooldown timer<br>
Auto-delete spam files
</p>
</td></tr>
</table>

<hr style="border-color:#333;">
<center>
<p style="font-size:10px; color:#666;">Save replay/recording + Game detected = Organized clips</p>
<p style="font-size:9px; color:#555;">© 2025-2026 SlonickLab | GPL v3 License | <a href="https://github.com/SlonickLab/Smart-Replay-Mover">GitHub</a></p>
</center>
]]
end

function script_properties()
    local props = obs.obs_properties_create()

    -- ═══════════════════════════════════════════════════════════════
    -- 📁 FILE NAMING GROUP
    -- ═══════════════════════════════════════════════════════════════
    local naming_group = obs.obs_properties_create()

    obs.obs_properties_add_bool(naming_group, "add_game_prefix",
        "✏️  Add game name prefix to filename")

    obs.obs_properties_add_text(naming_group, "fallback_folder",
        "📂  Fallback folder name",
        obs.OBS_TEXT_DEFAULT)

    obs.obs_properties_add_group(props, "naming_section",
        "📁  FILE NAMING", obs.OBS_GROUP_NORMAL, naming_group)

    -- ═══════════════════════════════════════════════════════════════
    -- 🎮 CUSTOM NAMES GROUP
    -- ═══════════════════════════════════════════════════════════════
    local custom_group = obs.obs_properties_create()

    -- Easy add section - two separate fields
    obs.obs_properties_add_text(custom_group, "custom_names_help",
        "Exact: process > Folder | Keywords: +word1 word2 > Folder | Contains: *text* > Folder",
        obs.OBS_TEXT_INFO)

    obs.obs_properties_add_text(custom_group, "new_process_name",
        "🎯  Process, +keywords, or *contains*",
        obs.OBS_TEXT_DEFAULT)

    obs.obs_properties_add_text(custom_group, "new_folder_name",
        "📁  Folder name (your custom name)",
        obs.OBS_TEXT_DEFAULT)

    obs.obs_properties_add_button(custom_group, "add_mapping_btn",
        "➕  Add mapping", add_custom_mapping)

    -- Separator info
    obs.obs_properties_add_text(custom_group, "custom_names_list_info",
        "Your custom mappings (you can edit or delete below):",
        obs.OBS_TEXT_INFO)

    -- The editable list for viewing/managing existing entries
    obs.obs_properties_add_editable_list(custom_group, "custom_names",
        "Custom name mappings",
        obs.OBS_EDITABLE_LIST_TYPE_STRINGS,
        nil,
        nil)

    -- Import/Export section
    obs.obs_properties_add_path(custom_group, "import_export_path",
        "📄  Import/Export file path",
        obs.OBS_PATH_FILE_SAVE,
        "Text files (*.txt)",
        nil)

    obs.obs_properties_add_button(custom_group, "import_btn",
        "📥  Import custom names", on_import_clicked)

    obs.obs_properties_add_button(custom_group, "export_btn",
        "📤  Export custom names", on_export_clicked)

    obs.obs_properties_add_group(props, "custom_section",
        "🎮  CUSTOM NAMES", obs.OBS_GROUP_NORMAL, custom_group)

    -- ═══════════════════════════════════════════════════════════════
    -- 🗂️ ORGANIZATION GROUP
    -- ═══════════════════════════════════════════════════════════════
    local folder_group = obs.obs_properties_create()

    obs.obs_properties_add_bool(folder_group, "use_date_subfolders",
        "📅  Create monthly subfolders (YYYY-MM)")

    obs.obs_properties_add_bool(folder_group, "organize_screenshots",
        "📸  Also organize screenshots")

    obs.obs_properties_add_bool(folder_group, "organize_recordings",
        "🎬  Organize recordings (Start/Stop Recording)")

    obs.obs_properties_add_group(props, "folder_section",
        "🗂️  ORGANIZATION", obs.OBS_GROUP_NORMAL, folder_group)

    -- ═══════════════════════════════════════════════════════════════
    -- 🛡️ SPAM PROTECTION GROUP
    -- ═══════════════════════════════════════════════════════════════
    local spam_group = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(spam_group, "duplicate_cooldown",
        "⏱️  Cooldown between saves (seconds)",
        0, 30, 0.5)

    obs.obs_properties_add_bool(spam_group, "delete_spam_files",
        "🗑️  Auto-delete duplicate files")

    obs.obs_properties_add_group(props, "spam_section",
        "🛡️  SPAM PROTECTION", obs.OBS_GROUP_NORMAL, spam_group)

    -- ═══════════════════════════════════════════════════════════════
    -- 🔔 NOTIFICATIONS GROUP
    -- ═══════════════════════════════════════════════════════════════
    local notify_group = obs.obs_properties_create()

    obs.obs_properties_add_text(notify_group, "notify_help",
        "Visual popup works only in Borderless Windowed games!",
        obs.OBS_TEXT_INFO)

    obs.obs_properties_add_bool(notify_group, "show_notifications",
        "🖼️  Show visual popup (Borderless Windowed only)")

    obs.obs_properties_add_bool(notify_group, "play_sound",
        "🔊  Play notification sound (works in Fullscreen too)")

    obs.obs_properties_add_float_slider(notify_group, "notification_duration",
        "⏱️  Popup duration (seconds)",
        1.0, 10.0, 0.5)

    obs.obs_properties_add_group(props, "notify_section",
        "🔔  NOTIFICATIONS", obs.OBS_GROUP_NORMAL, notify_group)

    -- ═══════════════════════════════════════════════════════════════
    -- 🔧 TOOLS GROUP
    -- ═══════════════════════════════════════════════════════════════
    local tools_group = obs.obs_properties_create()

    obs.obs_properties_add_bool(tools_group, "debug_mode",
        "🐛  Show debug messages in console")

    obs.obs_properties_add_group(props, "tools_section",
        "🔧  TOOLS & DEBUG", obs.OBS_GROUP_NORMAL, tools_group)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "add_game_prefix", true)
    obs.obs_data_set_default_bool(settings, "organize_screenshots", true)
    obs.obs_data_set_default_bool(settings, "organize_recordings", true)
    obs.obs_data_set_default_bool(settings, "use_date_subfolders", false)
    obs.obs_data_set_default_string(settings, "fallback_folder", "Desktop")
    obs.obs_data_set_default_double(settings, "duplicate_cooldown", 5.0)
    obs.obs_data_set_default_bool(settings, "delete_spam_files", true)
    obs.obs_data_set_default_bool(settings, "debug_mode", false)
    -- Notification defaults
    obs.obs_data_set_default_bool(settings, "show_notifications", true)
    obs.obs_data_set_default_bool(settings, "play_sound", false)
    obs.obs_data_set_default_double(settings, "notification_duration", 3.0)
end

function script_update(settings)
    -- Store settings reference for import/export callbacks
    script_settings = settings

    CONFIG.add_game_prefix = obs.obs_data_get_bool(settings, "add_game_prefix")
    CONFIG.organize_screenshots = obs.obs_data_get_bool(settings, "organize_screenshots")
    CONFIG.organize_recordings = obs.obs_data_get_bool(settings, "organize_recordings")
    CONFIG.use_date_subfolders = obs.obs_data_get_bool(settings, "use_date_subfolders")
    CONFIG.fallback_folder = obs.obs_data_get_string(settings, "fallback_folder")
    CONFIG.duplicate_cooldown = obs.obs_data_get_double(settings, "duplicate_cooldown")
    CONFIG.delete_spam_files = obs.obs_data_get_bool(settings, "delete_spam_files")
    CONFIG.debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
    -- Notification settings
    CONFIG.show_notifications = obs.obs_data_get_bool(settings, "show_notifications")
    CONFIG.play_sound = obs.obs_data_get_bool(settings, "play_sound")
    CONFIG.notification_duration = obs.obs_data_get_double(settings, "notification_duration")

    if CONFIG.fallback_folder == "" then
        CONFIG.fallback_folder = "Desktop"
    end

    -- Load custom names from the editable list
    load_custom_names(settings)

    -- Debug: show loaded custom names count
    local exact_count = 0
    for _ in pairs(CUSTOM_NAMES_EXACT) do exact_count = exact_count + 1 end
    local keywords_count = #CUSTOM_NAMES_KEYWORDS
    local contains_count = #CUSTOM_NAMES_CONTAINS
    local total_count = exact_count + keywords_count + contains_count
    if total_count > 0 then
        dbg("Loaded " .. total_count .. " custom name mapping(s) (" .. exact_count .. " exact, " .. keywords_count .. " keywords, " .. contains_count .. " contains)")
    end
end

function script_load(settings)
    -- Clean up any orphaned notification windows from previous script runs
    destroy_orphaned_notifications()

    -- Store settings reference for import/export callbacks
    script_settings = settings

    -- Load all settings first
    CONFIG.add_game_prefix = obs.obs_data_get_bool(settings, "add_game_prefix")
    CONFIG.organize_screenshots = obs.obs_data_get_bool(settings, "organize_screenshots")
    CONFIG.organize_recordings = obs.obs_data_get_bool(settings, "organize_recordings")
    CONFIG.use_date_subfolders = obs.obs_data_get_bool(settings, "use_date_subfolders")
    CONFIG.fallback_folder = obs.obs_data_get_string(settings, "fallback_folder")
    CONFIG.duplicate_cooldown = obs.obs_data_get_double(settings, "duplicate_cooldown")
    CONFIG.delete_spam_files = obs.obs_data_get_bool(settings, "delete_spam_files")
    CONFIG.debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
    -- Notification settings
    CONFIG.show_notifications = obs.obs_data_get_bool(settings, "show_notifications")
    CONFIG.play_sound = obs.obs_data_get_bool(settings, "play_sound")
    CONFIG.notification_duration = obs.obs_data_get_double(settings, "notification_duration")

    if CONFIG.fallback_folder == "" then
        CONFIG.fallback_folder = "Desktop"
    end

    -- Load custom names from the editable list
    load_custom_names(settings)

    obs.obs_frontend_add_event_callback(on_event)

    -- Count custom names for log
    local exact_count = 0
    for _ in pairs(CUSTOM_NAMES_EXACT) do exact_count = exact_count + 1 end
    local custom_count = exact_count + #CUSTOM_NAMES_KEYWORDS + #CUSTOM_NAMES_CONTAINS

    log("Smart Replay Mover v2.6.2 loaded (GPL v3 - github.com/SlonickLab/Smart-Replay-Mover)")
    log("Prefix: " .. (CONFIG.add_game_prefix and "ON" or "OFF") ..
        " | Recordings: " .. (CONFIG.organize_recordings and "ON" or "OFF") ..
        " | Fallback: " .. CONFIG.fallback_folder)
    if custom_count > 0 then
        log("Custom names: " .. custom_count .. " mapping(s) loaded")
    end
end

function script_unload()
    -- Clean up timer if still running
    obs.timer_remove(check_split_files)

    -- Clean up recording signal handler
    disconnect_recording_signals()

    -- Clean up notification system
    cleanup_notifications()

    log("Session: " .. files_moved .. " moved, " .. files_skipped .. " skipped")
end

-- ============================================================================
-- END OF SCRIPT v2.6.2
-- Copyright (C) 2025-2026 SlonickLab - Licensed under GPL v3
-- https://github.com/SlonickLab/Smart-Replay-Mover
-- ============================================================================
