-- ============================================================================
-- Smart Replay Mover v2.4.0
-- Simple, safe, and reliable replay buffer organizer for OBS
-- ============================================================================
--
-- Copyright (C) 2025-2026 MrRazzy
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
-- Source Code: https://github.com/MrRazzy/Smart-Replay-Mover
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

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    add_game_prefix = true,
    organize_screenshots = true,
    organize_recordings = true,  -- NEW: Support for regular recordings
    use_date_subfolders = false,
    fallback_folder = "Desktop",
    duplicate_cooldown = 5.0,
    delete_spam_files = true,
    debug_mode = false,
}

-- ============================================================================
-- IGNORE LIST (Programs to skip when detecting games)
-- ============================================================================

local IGNORE_LIST = {
    -- System
    "explorer", "searchapp", "taskmgr", "lockapp", "applicationframehost",
    "shellexperiencehost", "systemsettings", "textinputhost",

    -- OBS and streaming
    "obs64", "obs32", "obs", "streamlabs",

    -- Communication
    "discord", "telegram", "skype", "teams", "slack", "zoom", "viber",
    "whatsapp", "signal",

    -- Browsers
    "chrome", "firefox", "opera", "msedge", "brave", "vivaldi", "safari",
    "iexplore", "chromium",

    -- Media players
    "spotify", "vlc", "wmplayer", "groove", "itunes", "foobar2000",
    "musicbee", "winamp",

    -- Game launchers
    "steam", "steamwebhelper", "epicgameslauncher", "battle.net",
    "origin", "eadesktop", "gog", "ubisoft", "bethesda",
    "riot client", "riotclientservices",

    -- Editing software
    "photoshop", "lightroom", "gimp", "paint", "mspaint",
    "premiere", "aftereffects", "davinci", "resolve", "vegas",
    "audacity", "audition", "obs",

    -- Overlays
    "nvidia share", "geforce", "shadowplay", "overwolf", "medal",
    "playstv", "raptr", "amd", "radeon",

    -- Development
    "code", "vscode", "sublime", "notepad", "notepad++", "atom",
    "visual studio", "devenv", "idea", "pycharm", "webstorm",

    -- Utilities
    "7zfm", "winrar", "filezilla", "putty", "terminal", "powershell",
    "cmd", "conhost",

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
-- ============================================================================

local CUSTOM_NAMES = {}

-- Parse a single custom name entry
-- Supports formats:
--   "C:\path\to\game.exe > Custom Name"
--   "game.exe > Custom Name"
--   "game > Custom Name"
local function parse_custom_entry(entry)
    if not entry or entry == "" then return nil, nil end

    -- Split by " > " separator
    local path, name = string.match(entry, "^(.+)%s*>%s*(.+)$")
    if not path or not name then return nil, nil end

    -- Trim whitespace
    path = string.gsub(path, "^%s+", "")
    path = string.gsub(path, "%s+$", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    if path == "" or name == "" then return nil, nil end

    -- Extract just the executable name from full path
    -- Handle both forward and back slashes
    local exe = string.match(path, "([^/\\]+)$") or path
    -- Remove .exe extension if present
    exe = string.gsub(exe, "%.[eE][xX][eE]$", "")

    return string.lower(exe), name
end

-- Load custom names from OBS data array
local function load_custom_names(settings)
    CUSTOM_NAMES = {}

    local array = obs.obs_data_get_array(settings, "custom_names")
    if not array then return end

    local count = obs.obs_data_array_count(array)
    for i = 0, count - 1 do
        local item = obs.obs_data_array_item(array, i)
        local entry = obs.obs_data_get_string(item, "value")
        obs.obs_data_release(item)

        local exe, name = parse_custom_entry(entry)
        if exe and name then
            CUSTOM_NAMES[exe] = name
        end
    end

    obs.obs_data_array_release(array)
end

-- Check if a process matches any custom name (EXACT MATCH ONLY)
-- This prevents false positives like "obs" matching "roblox"
local function get_custom_name(process_name)
    if not process_name or process_name == "" then return nil end

    local lower = string.lower(process_name)
    -- Remove .exe if present
    lower = string.gsub(lower, "%.[eE][xX][eE]$", "")

    -- Exact match only - safest approach for user-defined names
    if CUSTOM_NAMES[lower] then
        return CUSTOM_NAMES[lower]
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
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")
local psapi = ffi.load("psapi")

local PROCESS_QUERY_INFORMATION = 0x0400
local PROCESS_VM_READ = 0x0010
local CP_UTF8 = 65001
local MAX_PATH = 260

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

local function log(msg)
    print("[Smart Replay] " .. msg)
end

local function debug(msg)
    if CONFIG.debug_mode then
        print("[Smart Replay DEBUG] " .. msg)
    end
end

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

local function get_game_folder(raw_name)
    if not raw_name or raw_name == "" then
        return CONFIG.fallback_folder
    end

    -- Check custom names first (highest priority)
    local custom = get_custom_name(raw_name)
    if custom then
        debug("Custom name match: " .. raw_name .. " -> " .. custom)
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
    if not sources then return nil end

    local found = nil

    for _, source in ipairs(sources) do
        local id = obs.obs_source_get_id(source)
        if id == "game_capture" then
            local settings = obs.obs_source_get_settings(source)
            local window = obs.obs_data_get_string(settings, "window")
            obs.obs_data_release(settings)

            if window and window ~= "" then
                local exe = string.match(window, "([^:]+)$")
                if exe then
                    found = string.gsub(exe, "%.[eE][xX][eE]$", "")
                    break
                end
            end
        end
    end

    obs.source_list_release(sources)
    return found
end

local function detect_game()
    -- Try process name first
    local process = get_active_process()
    if process and not is_ignored(process) then
        debug("Detected from process: " .. process)
        return process
    end

    -- Try window title
    local title = get_window_title()
    if title and not is_ignored(title) then
        debug("Detected from window: " .. title)
        return title
    end

    -- Try OBS game capture source
    local obs_game = find_game_in_obs()
    if obs_game and not is_ignored(obs_game) then
        debug("Detected from OBS: " .. obs_game)
        return obs_game
    end

    return nil
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
        debug("Windows delete failed, trying os.remove: " .. tostring(err))
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
        debug("File is very small (" .. file_size .. " bytes), might be incomplete")
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

    debug("Prefix check: add_game_prefix=" .. tostring(CONFIG.add_game_prefix) ..
          ", game_name=" .. tostring(game_name) ..
          ", fallback=" .. tostring(CONFIG.fallback_folder) ..
          ", will_add=" .. tostring(should_add_prefix))

    if should_add_prefix then
        local safe_game = clean_name(game_name)
        new_filename = safe_game .. " - " .. filename
        debug("Added prefix: " .. new_filename)
    end

    local target_path = target_dir .. "/" .. new_filename

    -- Validate path length and truncate filename if needed
    local valid, err = validate_path_length(target_path)
    if not valid then
        debug("Path too long, truncating filename: " .. err)
        -- Calculate max filename length based on directory length
        local max_filename_len = MAX_PATH - #target_dir - 2  -- -2 for "/" and null terminator
        if max_filename_len < 20 then
            log("ERROR: Directory path too long, cannot fit filename: " .. target_dir)
            return false
        end
        new_filename = truncate_filename(new_filename, max_filename_len)
        target_path = target_dir .. "/" .. new_filename
        debug("Truncated filename to: " .. new_filename)
    end

    -- Create directories with race condition protection
    local base_folder = dir .. "/" .. real_folder
    if not safe_mkdir(base_folder) then
        log("ERROR: Failed to create folder: " .. base_folder)
        return false
    end
    debug("Folder ready: " .. base_folder)

    if CONFIG.use_date_subfolders then
        if not safe_mkdir(target_dir) then
            log("ERROR: Failed to create date subfolder: " .. target_dir)
            return false
        end
        debug("Date subfolder ready: " .. target_dir)
    end

    -- Move file
    if obs.os_rename(src, target_path) then
        log("Moved: " .. new_filename)
        log("To: " .. target_dir)
        if file_size > 0 then
            debug("File size: " .. string.format("%.2f", file_size / 1024 / 1024) .. " MB")
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

    -- Detect game
    local raw_game = detect_game()
    local folder_name = get_game_folder(raw_game)

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

    debug("File split signal received, next_file: " .. tostring(prev_file))

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

-- Connect to recording output signals
local function connect_recording_signals()
    -- Disconnect any existing handler first
    disconnect_recording_signals()

    local recording = obs.obs_frontend_get_recording_output()
    if not recording then
        debug("No recording output available to connect signals")
        return false
    end

    local sh = obs.obs_output_get_signal_handler(recording)
    if not sh then
        debug("Could not get signal handler from recording output")
        obs.obs_output_release(recording)
        return false
    end

    -- Connect to file_changed signal for file splitting
    obs.signal_handler_connect(sh, "file_changed", on_recording_file_changed)

    -- Store reference to release later
    recording_output_ref = recording
    recording_signal_handler = sh

    debug("Connected to recording file_changed signal")
    return true
end

-- Disconnect recording signals
local function disconnect_recording_signals()
    if recording_signal_handler then
        obs.signal_handler_disconnect(recording_signal_handler, "file_changed", on_recording_file_changed)
        recording_signal_handler = nil
    end

    if recording_output_ref then
        obs.obs_output_release(recording_output_ref)
        recording_output_ref = nil
    end

    debug("Disconnected recording signals")
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
                debug("Now recording to: " .. current_file)
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
            process_file(path)
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
            local raw_game = detect_game()
            recording_game_name = raw_game
            recording_folder_name = get_game_folder(raw_game)
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
                        debug("Initial recording file: " .. current_recording_file)
                    end
                end
                obs.calldata_destroy(cd)
                obs.obs_output_release(recording)
            end

            -- Start timer to check for file splits (every 1 second)
            obs.timer_add(check_split_files, 1000)

            log("Recording started - monitoring for file splits")
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

                if path then
                    log("Recording stopped - organizing file")
                    -- Use cached game name if available, otherwise detect current
                    if recording_folder_name then
                        process_file_with_game(path, recording_folder_name, recording_game_name)
                    else
                        process_file(path)
                    end
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
    if path == "" then
        log("ERROR: Please specify a file path first using the Browse button")
        return false
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
<p style="color:#888;">Automatic Game Clip Organizer for OBS v2.4.0</p>
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
<p style="font-size:9px; color:#555;">© 2025-2026 MrRazzy | GPL v3 License | <a href="https://github.com/MrRazzy/Smart-Replay-Mover">GitHub</a></p>
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
        "Add a custom name mapping below:",
        obs.OBS_TEXT_INFO)

    obs.obs_properties_add_text(custom_group, "new_process_name",
        "🎯  Process name (from Task Manager)",
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
    obs.obs_data_set_default_bool(settings, "organize_recordings", true)  -- NEW
    obs.obs_data_set_default_bool(settings, "use_date_subfolders", false)
    obs.obs_data_set_default_string(settings, "fallback_folder", "Desktop")
    obs.obs_data_set_default_double(settings, "duplicate_cooldown", 5.0)
    obs.obs_data_set_default_bool(settings, "delete_spam_files", true)
    obs.obs_data_set_default_bool(settings, "debug_mode", false)
end

function script_update(settings)
    -- Store settings reference for import/export callbacks
    script_settings = settings

    CONFIG.add_game_prefix = obs.obs_data_get_bool(settings, "add_game_prefix")
    CONFIG.organize_screenshots = obs.obs_data_get_bool(settings, "organize_screenshots")
    CONFIG.organize_recordings = obs.obs_data_get_bool(settings, "organize_recordings")  -- NEW
    CONFIG.use_date_subfolders = obs.obs_data_get_bool(settings, "use_date_subfolders")
    CONFIG.fallback_folder = obs.obs_data_get_string(settings, "fallback_folder")
    CONFIG.duplicate_cooldown = obs.obs_data_get_double(settings, "duplicate_cooldown")
    CONFIG.delete_spam_files = obs.obs_data_get_bool(settings, "delete_spam_files")
    CONFIG.debug_mode = obs.obs_data_get_bool(settings, "debug_mode")

    if CONFIG.fallback_folder == "" then
        CONFIG.fallback_folder = "Desktop"
    end

    -- Load custom names from the editable list
    load_custom_names(settings)

    -- Debug: show loaded custom names count
    local count = 0
    for _ in pairs(CUSTOM_NAMES) do count = count + 1 end
    if count > 0 then
        debug("Loaded " .. count .. " custom name mapping(s)")
    end
end

function script_load(settings)
    -- Store settings reference for import/export callbacks
    script_settings = settings

    -- Load all settings first
    CONFIG.add_game_prefix = obs.obs_data_get_bool(settings, "add_game_prefix")
    CONFIG.organize_screenshots = obs.obs_data_get_bool(settings, "organize_screenshots")
    CONFIG.organize_recordings = obs.obs_data_get_bool(settings, "organize_recordings")  -- NEW
    CONFIG.use_date_subfolders = obs.obs_data_get_bool(settings, "use_date_subfolders")
    CONFIG.fallback_folder = obs.obs_data_get_string(settings, "fallback_folder")
    CONFIG.duplicate_cooldown = obs.obs_data_get_double(settings, "duplicate_cooldown")
    CONFIG.delete_spam_files = obs.obs_data_get_bool(settings, "delete_spam_files")
    CONFIG.debug_mode = obs.obs_data_get_bool(settings, "debug_mode")

    if CONFIG.fallback_folder == "" then
        CONFIG.fallback_folder = "Desktop"
    end

    -- Load custom names from the editable list
    load_custom_names(settings)

    obs.obs_frontend_add_event_callback(on_event)

    -- Count custom names for log
    local custom_count = 0
    for _ in pairs(CUSTOM_NAMES) do custom_count = custom_count + 1 end

    log("Smart Replay Mover v2.4.0 loaded (GPL v3 - github.com/MrRazzy/Smart-Replay-Mover)")
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

    log("Session: " .. files_moved .. " moved, " .. files_skipped .. " skipped")
end

-- ============================================================================
-- END OF SCRIPT v2.4.0
-- Copyright (C) 2025-2026 MrRazzy - Licensed under GPL v3
-- https://github.com/MrRazzy/Smart-Replay-Mover
-- ============================================================================
