-- Smart Replay Mover v2.8.1
-- Simple, safe, and reliable replay buffer organizer for OBS
-- ============================================================================
local VERSION = "2.8.1"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/SlonickLab/Smart-Replay-Mover/main/Smart%20Replay%20Mover.lua"
local GITHUB_RELEASES_URL = "https://github.com/SlonickLab/Smart-Replay-Mover/releases"
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
--
-- ============================================================================
-- CHANGELOG v2.8.1 (HOTFIX):
--   - CRITICAL FIX: Smart Save Hotkey no longer crashes/freezes OBS
--   - Root cause: cross-thread Win32 GDI calls from hotkey/UI/graphics threads
--   - Solution: thread-safe notification queue (notify() pushes to queue,
--     single graphics-thread timer processes all Win32/GDI operations)
--   - Fixed double detect_game() call in replay buffer save handler
--   - Smart skip: if save is fast, "Saving..." is skipped in favor of "Clip Saved"
--
-- CHANGELOG v2.8.0:
--   - Added "No Folder" mode: map process to "." to keep files in OBS output root
--   - Added Smart Save Hotkey with instant "Saving..." notification feedback
--   - Cleaned up duplicate ffi.cdef type declarations (code quality)
--
-- CHANGELOG v2.7.9:
--   - Fixed is_ignored() false positives ("obs" no longer matches "observer")
--   - Converted process ignore check to exact-match hash set (O(1) lookup)
--   - Added Notification Position option (Top Right/Left, Bottom Right/Left)
--   - Added "Auto-start Replay Buffer on OBS Launch" option
--   - Fixed version string mismatches
--
-- CHANGELOG v2.7.8:
--   - Added "Auto-restart Replay Buffer" option (prevents overlapping clips)
--   - Implemented Event-Driven restart logic (safe & synchronous)
--   - Added new "BUFFER CONTROL" settings section
--
-- CHANGELOG v2.7.7:
--   - Added Notification Scaling (100-300%) for 4K/HiDPI monitors
--   - Added "Test Notification" button to settings
--   - Added "Use Quiet Sound" option (switches to notification_sound_silent.wav)
--   - Improved Notification Window drawing with dynamic scaling
--
-- CHANGELOG v2.7.6:
--   - Critical: Fixed detection for games with Anti-Cheat (ARC Raiders, THE FINALS)
--   - Added fallback to QueryFullProcessImageNameA when OpenProcess is blocked
--   - Improved robustness of process detection logic
--
-- CHANGELOG v2.7.4:
--   - Critical: Fixed OBS freeze by implementing Notification Window Reuse
--   - Optimized redraw throttling (CPU efficiency)
--   - Added 0.5s safety delay for recording start initialization
--   - Added screenshot detection cache & throttle for burst captures
--   - Fixed GDI memory leak in window class background brush
--   - Removed obsolete CALLBACK_ANCHOR cleanup logic
--
-- CHANGELOG v2.7.3 (Pull Request by zxsleebu):
--   - Critical stability fix for Notification System (lua51.dll crash)
--   - Replaced Lua WNDPROC with native DefWindowProcA
--   - Manual render-on-timer logic implemented
--   - Added window validation (IsWindow) checks
--
-- CHANGELOG v2.7.2:
--   - Added FFmpeg Thumbnail support (embeds cover art into videos)
--   - New "Advanced" settings tab for FFmpeg configuration
--   - Safer file move operations with fallbacks
--
-- CHANGELOG v2.7.0:
--   - Merged all files into single unified script
--   - Embedded game database (1876 games) - no external file loading
--   - Custom names have ABSOLUTE priority over all detection
--   - Added ~40 new launcher entries to IGNORE_LIST
--   - Removed dofile() dependency - more stable loading
--   - Enhanced crash protection
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
    organize_recordings = true,
    use_date_subfolders = false,
    fallback_folder = "Desktop",
    duplicate_cooldown = 5.0,
    delete_spam_files = true,
    debug_mode = false,
    -- Notification settings
    show_notifications = true,
    play_sound = false,
    notification_duration = 3.0,
    -- FFmpeg settings
    enable_thumbnails = false,
    thumbnail_offset = 10.0,
    ffmpeg_path = "",
    -- Notification position
    notification_position = "top_right",
    -- Buffer Control
    restart_buffer_after_save = false,
    auto_start_buffer = false,
    -- Process scan detection
    scan_all_processes = false,
}

-- State tracking for buffer restart
local restarting_buffer_active = false

local GAME_DATABASE = {
    ["000: dawn of war - dark crusade"] = "Warhammer 40",
    ["000: dawn of war - game of the year edition"] = "Warhammer 40",
    ["000: dawn of war - soulstorm"] = "Warhammer 40",
    ["000: dawn of war iii"] = "Warhammer 40",
    ["000: inquisitor - martyr"] = "Warhammer 40",
    ["000: space marine"] = "Warhammer 40",
    ["100orange"] = "100% Orange Juice",
    ["140"] = "140",
    ["1914-1918 series"] = "Verdun",
    ["2000  to 1 a space felony"] = "2000:1: A Space Felony",
    ["20xx"] = "20XX",
    ["3dfxcarm"] = "Carmageddon",
    ["60seconds"] = "60 Seconds!",
    ["6kinoko"] = "New Super Marisa Land",
    ["7daystodie"] = "7 Days to Die",
    ["7daystodie_eac"] = "7 Days to Die",
    ["8bitboy"] = "8BitBoy",
    ["911"] = "911 Operator",
    ["aagame"] = "America's Army: Proving Grounds",
    ["aamfp"] = "Amnesia: A Machine for Pigs",
    ["abewin"] = "Oddworld: Abe's Oddysee",
    ["absolutedrift"] = "Absolute Drift",
    ["absolver-win64-shipping"] = "Absolver",
    ["ac3lhd_32"] = "Assassin's Creed Liberation HD",
    ["ac3mp"] = "Assassin's Creed 3 Multiplayer",
    ["ac3sp"] = "Assassin's Creed 3",
    ["ac4bfmp"] = "Assassin's Creed IV: Black Flag",
    ["ac4bfsp"] = "Assassin's Creed IV: Black Flag",
    ["acbmp"] = "Assassin's Creed: Brotherhood",
    ["acbsp"] = "Assassin's Creed: Brotherhood",
    ["acc"] = "Assassin's Creed Rogue",
    ["accgame-win32-shipping"] = "Assassin's Creed® Chronicles: India",
    ["acclient"] = "Asheron's Call",
    ["ace combat_ah"] = "Ace Combat Assault Horizon",
    ["aces"] = "WarThunder",
    ["acfc"] = "Assassin's Creed Freedom Cry",
    ["acrmp"] = "Assassin's Creed Revelations Multiplayer",
    ["acrsp"] = "Assassin's Creed Revelations",
    ["acs"] = "Assassin's Creed Syndicate",
    ["acu"] = "Assassin's Creed Unity",
    ["adventure-capitalist"] = "AdVenture Capitalist",
    ["adventure-communist"] = "AdVenture Communist",
    ["advhd"] = "If My Heart Had Wings",
    ["aer"] = "AER Memories of Old",
    ["afterfx"] = "Adobe After Effects",
    ["age"] = "Kamidori Alchemy Meister",
    ["age2_x1"] = "Age of Empires II: The Conquerors",
    ["age3y"] = "Age of Empires® III: Complete Collection",
    ["ageofconan"] = "Age of Conan",
    ["aim hero"] = "Aim Hero",
    ["aimtastic"] = "Aimtastic",
    ["aion.bin"] = "Aion",
    ["airmech"] = "AirMech Strike",
    ["aiwar"] = "AI War",
    ["alan_wakes_american_nightmare"] = "Alan Wake's American Nightmare",
    ["alanwake"] = "Alan Wake",
    ["albion-online"] = "Albion Online",
    ["alicemadnessreturns"] = "Alice: Madness Returns",
    ["alienbreed-impact"] = "Alien Breed Impact",
    ["alienbreed2assault"] = "Alien Breed 2: Assault",
    ["alphaprime"] = "Alpha Prime",
    ["altitude"] = "Alltitude",
    ["amnesia"] = "Amnesia: The Dark Descent",
    ["amorous.game.windows"] = "Amorous",
    ["amtrucks"] = "American Truck Simulator",
    ["anarchy"] = "Anarchy Online",
    ["anb"] = "A New Beginning - Final Cut",
    ["anna"] = "Anna's Quest",
    ["anno2205"] = "Anno 2205",
    ["anno5"] = "ANNO 2070",
    ["anowor"] = "Another World",
    ["anthemdemo"] = "Anthem",
    ["antihero"] = "Antihero",
    ["aok hd"] = "Age Of Empires 2",
    ["aom_release_final"] = "Agents of Mayhem",
    ["apb"] = "APB Reloaded",
    ["apgame"] = "Alpha Protocol",
    ["appdata"] = "Tropico 5",
    ["application-steam-x64"] = "Banished",
    ["aq3d"] = "AdventureQuest 3D",
    ["aragami"] = "Aragami",
    ["arcania"] = "ArcaniA",
    ["archeage"] = "ArcheAge",
    ["arena"] = "Total War Arena",
    ["argo"] = "Argo",
    ["argo_x64"] = "Argo",
    ["arizonasunshine"] = "Arizona Sunshine",
    ["arkhamvr"] = "Batman: Arkham VR",
    ["arma2"] = "Arma 2",
    ["arma2oa"] = "Arma 2: DayZ Mod",
    ["arma2oa_be"] = "Arma 2: Operation Arrowhead",
    ["arma3"] = "Arma 3",
    ["armello"] = "Armello",
    ["armikrog"] = "Armikrog",
    ["armoredwarfare"] = "Armored Warfare",
    ["arpiel"] = "Arpiel Online",
    ["asamu-win32-shipping"] = "A Story About My Uncle",
    ["asn_app_pcdx9_final"] = "Sonic & All-Stars Racing Transformed",
    ["assassinscreed_dx10"] = "Assasin's Creed DX10",
    ["assassinscreed_dx9"] = "Assasin's Creed DX9",
    ["assassinscreed_game"] = "Assassin's Creed",
    ["assassinscreediigame"] = "Assasin's Creed II",
    ["assettocorsa"] = "Assetto Corsa",
    ["astro-win64-shipping"] = "ASTRONEER",
    ["astronautsgame-win64-shipping"] = "The Vanishing of Ethan Carter",
    ["atilla"] = "Total War: Atilla",
    ["atlasreactor"] = "Atlas Reactor",
    ["attila"] = "Total War: Attila",
    ["audiosurf"] = "Audiosurf",
    ["audiosurf2"] = "Audiosurf 2",
    ["autostarter"] = "Lost Horizon",
    ["ava"] = "Alliance of Valiant Arms",
    ["avalonlords"] = "Avalon Lords",
    ["avgame-win64-shipping"] = "Vampyr",
    ["avorion"] = "Avorion",
    ["avp"] = "Aliens vs Predator",
    ["avp3"] = "Alien Vs Predator",
    ["avp_dx11"] = "Aliens vs Predator",
    ["awesomenauts"] = "Awesomenauts",
    ["axiomverge"] = "Axiom Verge",
    ["b1-win64-shipping"] = "Black Myth: Wukong",
    ["backtobed"] = "Back to Bed",
    ["badnorth"] = "Bad North",
    ["baldur"] = "Baldur's Gate",
    ["ball 3d"] = "Ball 3D: Soccer Online",
    ["ballisticoverkill"] = "Ballistic Overkill",
    ["bangbangracing"] = "Bang Bang Racing",
    ["barkleyv120"] = "Charles Barkley: Shut Up and Jam Gaiden",
    ["base"] = "The Ultimate DOOM",
    ["bastion"] = "Bastion",
    ["batalj beta"] = "BATALJ",
    ["batim"] = "Bendy and the Ink Machine",
    ["batmanac"] = "Batman: Arkham City",
    ["batmanak"] = "Batman Arkham Knight",
    ["batmanorigins"] = "Batman: Arkham Origins",
    ["battleblocktheater"] = "BattleBlock Theater",
    ["battlefront"] = "Star Wars Battlefront",
    ["battlefrontii"] = "Star Wars Battlefront II",
    ["battlerite"] = "Battlerite",
    ["battleroyaletrainer-win64-shipping"] = "Battle Royale Trainer",
    ["battles-win"] = "Bloons TD Battles",
    ["battletech"] = "BATTLETECH",
    ["battlevschess"] = "Battle vs Chess",
    ["battleworldskronos"] = "Battle Worlds: Kronos",
    ["bayonetta"] = "Bayonetta",
    ["bbcse"] = "BlazBlue Continuum Shift Extend",
    ["bbtag"] = "BlazBlue Cross Tag Battle",
    ["bc"] = "Battle Chasers: Nightwar",
    ["beamng.drive.x64"] = "BeamNG.drive",
    ["beat saber"] = "Beat Saber",
    ["beathazard"] = "Beat Hazard",
    ["beathazardclassic"] = "Beat Hazard Classic",
    ["beginnersguide"] = "The Beginner's Guide",
    ["beholder"] = "Beholder",
    ["bejblitz"] = "Bejeweled Blitz",
    ["bejeweled3"] = "Bejeweled 3",
    ["berimbau"] = "Blade Symphony",
    ["besiege"] = "Besiege",
    ["bf1"] = "Battlefield 1",
    ["bf2"] = "Battlefield 2",
    ["bf2042"] = "Battlefield 2042",
    ["bf3"] = "Battlefield 3",
    ["bf4"] = "Battlefield 4",
    ["bf4cte"] = "Battlefiled 4 CTE",
    ["bfbc2game"] = "Battlefield: Bad Company 2",
    ["bfh"] = "Battlefield™ Hardline",
    ["bfvob"] = "Battlefield 5",
    ["bf6"] = "Battlefield 6",
    ["bge"] = "Beyond Good and Evil",
    ["bgi"] = "Go! Go! Nippon! ~My First Trip to Japan~",
    ["bgt"] = "Bloody Good Time",
    ["bh6"] = "Resident Evil 6",
    ["bhd"] = "Resident Evil 4HD Remaster",
    ["bia"] = "Brothers in Arms: Road to Hill 30",
    ["binding_of_isaac"] = "The Binding of Isaac",
    ["bio4"] = "resident evil 4 / biohazard 4",
    ["bioshock"] = "Bioshock",
    ["bioshock2"] = "BioShock II",
    ["bioshock2hd"] = "BioShock 2 Remastered",
    ["bioshockhd"] = "BioShock Remastered",
    ["bioshockinfinite"] = "BioShock Infinite",
    ["bit heroes"] = "Bit Heroes",
    ["blackdesert32"] = "Black Desert Online",
    ["blackdesert64"] = "Black Desert Online",
    ["blackdesertpatcher32.pae"] = "Black Desert Online Turkiye and MENA",
    ["blackguards"] = "Blackguards",
    ["blackguards 2"] = "Blackguards 2",
    ["blacklist_dx11_game"] = "Splinter Cell: Blacklist",
    ["blacklist_game"] = "Splinter Cell: Blacklist",
    ["blackmirror"] = "Black Mirror",
    ["blackops3"] = "Call of Duty: Black Ops III",
    ["blackopsmp"] = "Call of Duty: Black Ops",
    ["blackshot"] = "Blackshot SEA",
    ["blacksurvival"] = "Black Survival",
    ["blackwake"] = "Blackwake",
    ["blackxchg.aes"] = "Counter-Strike Nexon: Zombies",
    ["bladekitten"] = "Blade Kitten",
    ["blobby"] = "Blobby Volley 2",
    ["blocknload"] = "Block N Load",
    ["bloodandbacon"] = "Blood and Bacon",
    ["bloodbowl2"] = "Blood Bowl 2",
    ["bloodbowl2_dx_32"] = "Blood Bowl 2",
    ["bloodbowl2_gl_32"] = "Blood Bowl 2",
    ["bloodlinechampions"] = "Bloodline Champions",
    ["bloody trapland"] = "Bloody Trapland",
    ["blr"] = "Blacklight: Retribution",
    ["bms"] = "Black Mesa",
    ["boid"] = "Boid",
    ["bombercrew"] = "Bomber Crew",
    ["bombtag"] = "BombTag",
    ["bootggxrd"] = "Guilty Gear Xrd -SIGN-",
    ["borderlands"] = "Borderlands",
    ["borderlands2"] = "Borderlands 2",
    ["borderlandspresequel"] = "Borderlands: the Pre-Sequel",
    ["boringmangame"] = "Boring Man - Online Tactical Stickman Combat",
    ["bout2"] = "The Book of Unwritten Tales 2",
    ["braid"] = "Braid",
    ["brawlhalla"] = "Brawlhalla",
    ["breach"] = "Into the Breach",
    ["breach-win64-shipping"] = "Breach",
    ["brickrigs-win64-shipping"] = "Brick Rigs",
    ["bridge_constructor_medieval"] = "Bridge Constructor Medieval",
    ["bridge_constructor_portal"] = "Bridge Constructor Portal",
    ["bridgeconstructor"] = "Bridge Constructor",
    ["bridgeconstructorplayground"] = "Bridge Constructor Playground",
    ["broforce_beta"] = "Broforce",
    ["brokeprotocol"] = "BROKE PROTOCOL: Online City RPG",
    ["brothers"] = "Brothers - A Tale of Two Sons",
    ["brutallegend"] = "Brutal Legend",
    ["btd5-win"] = "Bloons TD5",
    ["bugs"] = "BBLiT",
    ["bully"] = "Bully: Scholarship Edition",
    ["burnoutparadise"] = "Burnout Paradise",
    ["businesstour"] = "Business Tour - Online Multiplayer Board Game",
    ["cabal2main"] = "Cabal 2",
    ["cabalmain"] = "Cabal Online",
    ["cactus"] = "Assault Android Cactus",
    ["caggameserver"] = "Grav",
    ["call of war"] = "Call of War",
    ["call_to_arms"] = "Call to Arms",
    ["captainspirit-win64-shipping"] = "The Awesome Adventures of Captain Spirit",
    ["cardhunter"] = "Card Hunter",
    ["cargocommander"] = "Cargo Commander",
    ["carma"] = "Carmageddon",
    ["carmag"] = "Carmageddon",
    ["carmageddon_max_damage"] = "Carmageddon: Max Damage",
    ["carmageddon_reincarnation"] = "Carmageddon Reincarnation",
    ["carmagv"] = "Carmageddon",
    ["carmav"] = "Carmageddon",
    ["carriedaway"] = "Carried Away",
    ["carrier"] = "Carrier Command: Gaea Mission",
    ["castle"] = "Castle Crashers",
    ["castleminerz"] = "CastleMiner Z",
    ["cataclysm-tiles"] = "Cataclysm: Dark Days Ahead",
    ["cave"] = "The Cave",
    ["cavestory+"] = "Cave Story+",
    ["celebritypoker"] = "Poker Night at the Inventory",
    ["celeste"] = "Celeste",
    ["childoflight"] = "Child of Light",
    ["chronicle"] = "Chronicle - Runescape Legends",
    ["cities"] = "Cities: Skylines",
    ["citra-qt"] = "Citra",
    ["civ3conquests"] = "Sid Meier's Civilization III: Complete",
    ["civilizationbe_dx11"] = "Sid Meier's Civilization: Beyond Earth",
    ["civilizationbe_mantle"] = "Sid Meier's Civilization: Beyond Earth",
    ["civilizationv"] = "Sid Meier's Civilization V",
    ["civilizationv_dx11"] = "Sid Meier's Civilization V",
    ["civilizationv_tablet"] = "Sid Meier's Civilization V",
    ["civilizationvi"] = "Sid Meier's Civilization VI",
    ["ck2game"] = "Crusader Kings II",
    ["ckan"] = "CKAN",
    ["clicker heroes"] = "Clicker Heroes",
    ["client_tos"] = "Tree of Savior",
    ["clientpatcher"] = "Secret World Legends",
    ["climb"] = "Climb",
    ["clone drone in the danger zone"] = "Clone Drone in the Danger Zone",
    ["clonk"] = "Clonk Rage",
    ["cloudsandsheep2"] = "Clouds & Sheep 2",
    ["clragexe"] = "Ragnarok Online Classic",
    ["clustertruck"] = "Clustertruck",
    ["cm black sea"] = "Combat Mission: Black Sea",
    ["cm shock force"] = "Combat Mission: Shock Force",
    ["cm3"] = "Crazy Machines 3",
    ["cms2015"] = "Car Mechanic Simulator 2015",
    ["cms2018"] = "Car Mechanic Simulator 2018",
    ["cmw"] = "Chivalry: Medieval",
    ["cod"] = "Call of Duty: Warzone",
    ["cod2mp_s"] = "Call of Duty 2",
    ["cod2sp_s"] = "Call of Duty 2",
    ["codsp_s"] = "Call of Duty 2:",
    ["codwaw"] = "Call of Duty: World at War",
    ["codwawmp"] = "Call of Duty: World at War",
    ["coflaunchapp"] = "Cry of Fear",
    ["coj"] = "Call of Juarez",
    ["cojbibgame_x86"] = "Call of Juarez: Bound in Blood",
    ["cojgunslinger"] = "Call of Juarez: Gunslinger",
    ["colonyclient"] = "Colony Survival",
    ["comedy night"] = "Comedy Night",
    ["command"] = "Command: Modern Air/Naval Operations",
    ["conansandbox_be"] = "Conan Exiles",
    ["consim2015"] = "Construction Simulator 2015",
    ["consortium"] = "Consortium",
    ["contagion"] = "Contagion",
    ["conviction_game"] = "Tom Clancy's Splinter Cell Conviction",
    ["cortex command"] = "Cortex Command",
    ["cosmic"] = "Cosmic Break",
    ["cosmicbreak2"] = "Cosmic Break 2",
    ["cosmicleague"] = "Cosmic League",
    ["cossacks"] = "Cossacks 3",
    ["crawl"] = "Crawl",
    ["creativerse"] = "Creativerse",
    ["creeper world 2"] = "Creeper World 2: Redemption",
    ["critterchronicles"] = "The Book of Unwritten Tales: The Critter Chronicles",
    ["crookz"] = "Crookz - The Big Heist",
    ["crossfire"] = "CrossFire",
    ["crowfallclient"] = "Crowfall",
    ["crusader2"] = "Stronghold Crusader 2",
    ["crushcrush"] = "Crush Crush",
    ["cryptark"] = "CRYPTARK",
    ["crysis"] = "Crysis",
    ["crysis2"] = "Crysis 2",
    ["crysis3"] = "Crysis 3",
    ["crysis64"] = "Crysis",
    ["cs2d"] = "CS2D",
    ["csdsteambuild"] = "Cook, Serve, Delicious!",
    ["csgo"] = "Counter-Strike: Global Offensive",
    ["cube"] = "Cube World",
    ["cuphead"] = "Cuphead",
    ["cure"] = "Codename CURE",
    ["cw"] = "Closers Dimension Conflict",
    ["cw3"] = "Creeper World 3: Arc Eternal",
    ["cyberdrome-win64-shipping"] = "Cyberdrome",
    ["cyphers"] = "Cyphers",
    ["dandara"] = "Dandara",
    ["daorigins"] = "Dragon Age: Origins",
    ["daou_updateaddinsxml_steam"] = "Dragon Age: Origins - Ultimate Edition",
    ["darkapp"] = "Dark",
    ["darkcrusade"] = "Warhammer 40,000: Dawn of War - Dark Crusade",
    ["darknessii"] = "Darkness 2",
    ["darksiders1"] = "Darksiders Warmastered Edition",
    ["darksiders2"] = "Darksiders 2",
    ["darksiderspc"] = "Darksiders",
    ["darksouls"] = "Dark Souls",
    ["darksoulsii"] = "Dark Souls 2",
    ["darksoulsiii"] = "DARK SOULS III",
    ["darksoulsremastered"] = "DARK SOULS™: REMASTERED",
    ["darkstarone"] = "DarkStar One",
    ["darwin"] = "Darwin Project",
    ["darwin-win64-shipping"] = "Darwin Project - Open Beta",
    ["darwinia"] = "Darwinia",
    ["data"] = "Dark Souls",
    ["dauntless-win64-shipping"] = "Dauntless",
    ["dave"] = "Dangerous Dave",
    ["dayofinfamy_be"] = "Day of Infamy",
    ["dayz"] = "Day Z",
    ["dayz_x64"] = "DayZ",
    ["dbfighterz"] = "DRAGON BALL FighterZ",
    ["dbxv"] = "Dragon Ball XenoVerse",
    ["dbxv2"] = "Dragon Ball Xenoverse 2",
    ["dcgame"] = "DC Universe Online",
    ["dcs"] = "DCS World",
    ["ddadds"] = "Dream Daddy: A Dad Dating Simulator",
    ["ddda"] = "Dragon's Dogma: Dark Arisen",
    ["ddo"] = "Dragon's Dogma Online",
    ["dead space"] = "Dead Space™",
    ["deadage"] = "Dead Age",
    ["deadbydaylight-win64-shipping"] = "Dead by Daylight",
    ["deadcells"] = "Dead Cells",
    ["deadeffect"] = "Dead Effect",
    ["deadfrontier2"] = "Dead Frontier 2",
    ["deadislandgame"] = "Dead Island",
    ["deadislandgame_x86_rwdi"] = "Dead Island Riptide",
    ["deadislandriptidegame"] = "Dead Island Riptide Definitive Edition",
    ["deadlock"] = "Deadlock",
    ["deadly30"] = "Deadly 30",
    ["deadmaze"] = "Dead Maze",
    ["deadrising2"] = "Dead Rising 2",
    ["deadrising3"] = "Dead Rising 3",
    ["deadspace2"] = "Dead Space 2",
    ["dearesther"] = "Dear Esther",
    ["deathspank"] = "DeathSpank",
    ["deathspanktov"] = "DeathSpank - Thongs of Virtue",
    ["deblob"] = "de Blob",
    ["deblob2"] = "de Blob 2",
    ["deceit"] = "Deceit",
    ["deep space waifu"] = "DEEP SPACE WAIFU",
    ["defensegrid2_release"] = "Defense Grid 2",
    ["deltaforceclient-win64-shipping"] = "Delta Force",
    ["democracy3"] = "Democracy 3",
    ["deponia"] = "Deponia: The Complete Journey",
    ["deponia2"] = "Chaos on Deponia",
    ["depressionquest"] = "Depression Quest",
    ["depthgame"] = "Depth",
    ["descenders"] = "Descenders",
    ["descent"] = "Descent Underground",
    ["desertsofkharak32"] = "Desert of Kharak",
    ["desertsofkharak64"] = "Desert of Kharak",
    ["destiny2"] = "Destiny 2",
    ["detection"] = "Assassin's Creed",
    ["deusex"] = "Deus Ex",
    ["deusex_steam"] = "Deus Ex: The Fall",
    ["devenv"] = "Visual Studio",
    ["devilmaycry4_dx10"] = "Devil May Cry 4",
    ["devilmaycry4_dx9"] = "Devil May Cry 4",
    ["devilmaycry4specialedition"] = "Devil May Cry 4",
    ["devimaycry4"] = "Devil May Cry 4",
    ["devimaycry5"] = "Devil May Cry 5",
    ["df"] = "Delta Force 1",
    ["dfbhd"] = "Delta Force: Black Hawk Down",
    ["dflw"] = "Delta Force: Land Warrior",
    ["dfo"] = "Dungeon Fighter Online",
    ["dftfd"] = "Delta Force: Task Force Dagger",
    ["dfubg"] = "S.K.I.L.L. - Special Force 2",
    ["dfuw"] = "Darkfall: Unholy Wars",
    ["diablo"] = "Diablo",
    ["diablo ii"] = "Diablo II",
    ["diablo iii"] = "Diablo 3",
    ["diablo iii64"] = "Diablo III",
    ["diadraempty"] = "Diadra Empty",
    ["diadraempty154lw"] = "Diadra Empty",
    ["diadraempty154plus"] = "Diadra Empty",
    ["dinodday"] = "Dino D-Day",
    ["dinohordegame"] = "ORION: Prelude",
    ["directus3d"] = "Directus",
    ["dirt2_game"] = "DiRT 2",
    ["dirt3"] = "Dirt 3",
    ["dirt3_game"] = "DiRT 3 Complete Edition",
    ["dirt4"] = "DiRT 4",
    ["disasm"] = "World of Guns: Gun Disassembly",
    ["disco dodgeball"] = "Robot Roller-Derby Disco Dodgeball",
    ["dishonored"] = "Dishonored",
    ["dishonored2"] = "Dishonored 2",
    ["disneyinfinity2"] = "Disney Infinity",
    ["disneyinfinity3"] = "Disney Infinity",
    ["dividebysheep"] = "Divide By Sheep",
    ["dlpc"] = "Yu-Gi-Oh! Duel Links",
    ["dmc-devilmaycry"] = "DmC - Devil May Cry",
    ["dndclient"] = "Dungeons & Dragons Online",
    ["dnf"] = "Dungeon & Fighter",
    ["dnl"] = "Dark and Light",
    ["dofus"] = "Dofus",
    ["dom"] = "Dawn of Midgard",
    ["domina"] = "Domina",
    ["dominions4"] = "Dominions 4",
    ["dontstarve_steam"] = "Don't Starve",
    ["donttouchanything"] = "Please, Don't Touch Anything",
    ["donutcounty"] = "Donut County",
    ["doom"] = "Doom 3",
    ["doomx64"] = "DOOM 2016",
    ["doomx64vk"] = "DOOM 2016",
    ["doorkickers"] = "Door Kickers",
    ["dota"] = "DOTA",
    ["dota2"] = "Dota 2",
    ["dotp_d14"] = "Magic the Gathering 2014",
    ["doubledragon"] = "Double Dragon Neon",
    ["dow2"] = "Warhammer 40,000: Dawn of War 2",
    ["downwell"] = "Downwell",
    ["dqxgame"] = "Dragon Quest X: Mezameshi Itsutsu no Shuzoku Online",
    ["dragonage2"] = "Dragon Age 2",
    ["dragonageinquisition"] = "Dragon Age: Inquisition",
    ["dragonfall"] = "Shadowrun: Dragonfall",
    ["dragonfinsoup"] = "Dragon Fin Soup",
    ["dragonnest"] = "Dragon Nest",
    ["dreadgame-win64-shipping"] = "Dreadnought",
    ["dreamfall chapters"] = "Dreamfall Chapters: The Longest Journey",
    ["drift racing online"] = "CarX Drift Racing Online",
    ["drlangeskov"] = "Dr Langeskov, The Tiger, and The Terribly Cursed Emerald: A Whirlwind Heist",
    ["drt"] = "DiRT Rally",
    ["dubdash"] = "Dub Dash",
    ["duckgame"] = "Duck Game",
    ["ducktales"] = "DuckTales Remastered",
    ["duelyst"] = "Duelyst",
    ["duke3d"] = "Duke Nukem 3D",
    ["dukeforever"] = "Duke Nukem Forever",
    ["dundefgame"] = "Dungeon Defenders 2",
    ["dungeon"] = "Soda Dungeon",
    ["dungeon siege iii"] = "Dungeon Siege 3",
    ["dungeoneering"] = "Guild of Dungeoneering",
    ["dungeonland"] = "Dungeonland",
    ["dungeonoftheendless"] = "Dungeon of the Endless",
    ["dungeons2"] = "Dungeons 2",
    ["dungeonsiege"] = "Dungeon Siege",
    ["dungeonsiege2"] = "Dungeon Siege 2",
    ["dungreed"] = "Dungreed",
    ["dustaet"] = "Dust: An Elysian Tail",
    ["dustforce"] = "Dustforce",
    ["dwarves"] = "The Dwarves",
    ["dxb"] = "Deus Ex: Breach",
    ["dxhr"] = "Deus Ex: Human Revolution",
    ["dxhrdc"] = "Deus Ex: Human Revolution",
    ["dxmd"] = "Deus Ex: Mankind Divided™",
    ["dyinglightgame"] = "Dying Light",
    ["earth"] = "Google Earth VR",
    ["eco"] = "Eco",
    ["ed6_win"] = "The Legend of Heroes: Trails in the Sky",
    ["ed6_win2"] = "Trails in the Sky SC",
    ["edf41"] = "EARTH DEFENSE FORCE 4.1  The Shadow of New Despair",
    ["edlaunch"] = "Elite: Dangerous",
    ["edna"] = "Edna & Harvey: The Breakout",
    ["eee"] = "Ed, Edd n Eddy: The Mis-Edventures",
    ["electronicobserver"] = "Kantai Collection",
    ["elex"] = "ELEX",
    ["elitedangerous32"] = "Elite: Dangerous",
    ["elitedangerous64"] = "Elite: Dangerous",
    ["elsword"] = "Elsword",
    ["emily is away"] = "Emily is Away",
    ["empire"] = "Empire: Total War",
    ["empires2"] = "Age of Empires 2",
    ["empyrion"] = "Empyrion - Galactic Survival",
    ["endlesslegend"] = "Endless Legend",
    ["endlessspace2"] = "Endless Space 2",
    ["engine"] = "F.E.A.R.",
    ["enslaved"] = "Enslaved:Odyssey to the West",
    ["entropia"] = "Entropia Universe",
    ["eocapp"] = "Divinity: Original Sin",
    ["eqgame"] = "EverQuest",
    ["escapedeadisland"] = "Escape Dead Island",
    ["escapefromtarkov"] = "Escape from Tarkov",
    ["eseaclient"] = "ESEA",
    ["eso"] = "The Elder Scrolls Online",
    ["eso64"] = "The Elder Scrolls Online",
    ["essteam"] = "Elsword",
    ["et"] = "Wolfenstein: Enemy Territory",
    ["eternal"] = "Eternal Card Game",
    ["eternalcrusadeclient"] = "Warhammer 40,000: Eternal Crusade",
    ["etg"] = "Enter the Gungeon",
    ["ethancarter-win64-shipping"] = "The Vanishing of Ethan Carter Redux",
    ["eu4"] = "Europa Universalis IV",
    ["europa1400gold_tl"] = "The Guild Gold Edition",
    ["eurotrucks2"] = "Euro Truck Simulator 2",
    ["event0"] = "Event[0]",
    ["everlasting summer"] = "Everlasting Summer",
    ["everquest2"] = "EverQuest 2",
    ["evilwithin"] = "The Evil Within",
    ["evoland2"] = "Evoland 2",
    ["evolve"] = "Evolve Stage 2",
    ["execpubg"] = "PUBG: Test Server",
    ["exefile"] = "Eve Online",
    ["expendabros"] = "The Expendabros",
    ["eye"] = "E.Y.E.: Divine Cybermancy",
    ["ezquake-gl"] = "EZ Quake",
    ["f.e.a.r. 3"] = "F.E.A.R. 3",
    ["f13"] = "Friday the 13th: Killer Puzzle",
    ["f1_2015"] = "F1 2015",
    ["f1_2016"] = "F1 2016",
    ["f1_2017"] = "F1 2017",
    ["fable"] = "Fable: The Lost Chapters",
    ["fable anniversary"] = "Fable Anniversary",
    ["factorio"] = "Factorio",
    ["factorygame"] = "Satisfactory",
    ["factorygame-win64-shipping"] = "Satisfactory",
    ["satisfactory"] = "Satisfactory",
    ["faeria"] = "Faeria",
    ["fairyfencer"] = "Fairy Fencer F",
    ["fallout2"] = "Fallout 2",
    ["fallout2hr"] = "Fallout 2",
    ["fallout3"] = "Fallout 3",
    ["fallout4"] = "Fallout 4",
    ["fallout4vr"] = "Fallout 4 VR",
    ["falloutnv"] = "Fallout: New Vegas",
    ["falloutshelter"] = "Fallout Shelter",
    ["falloutw"] = "Fallout",
    ["fancy_skulls"] = "Fancy Skulls",
    ["farcry2"] = "Far Cry 2",
    ["farcry3"] = "Far Cry 3",
    ["farcry3_d3d11"] = "Far Cry® 3",
    ["farcry4"] = "Far Cry 4",
    ["farcry5"] = "Far Cry 5",
    ["farmingsimulator2015game"] = "Farming Simulator 15",
    ["farmingsimulator2017game"] = "Farming Simulator 17",
    ["farmtogether"] = "Farm Together",
    ["fc3_blooddragon_d3d11_b"] = "Far Cry 3 Blood Dragon",
    ["fceux"] = "Nintendo Emulator",
    ["fcsplash"] = "Far Cry Primal",
    ["fear"] = "F.E.A.R.",
    ["fear2"] = "F.E.A.R. 2: Project Origin",
    ["fearxp"] = "F.E.A.R.",
    ["feed and grow"] = "Feed and Grow: Fish",
    ["fenris-win64-shipping"] = "Fortified",
    ["fez"] = "FEZ",
    ["ff6"] = "FINAL FANTASY VI",
    ["ff7_en"] = "Final Fantasy VII",
    ["ff8_en"] = "Final Fantasy VIII",
    ["ffr"] = "Flash Flash Revolution",
    ["ffv_game"] = "Final Fantasy V",
    ["ffx"] = "Final Fantasy X",
    ["ffx-2"] = "Final Fantasy X-2",
    ["ffxiii2"] = "Final Fantasy XIII-2",
    ["ffxiiiimg"] = "Final Fantasy XIII",
    ["ffxiv"] = "FINAL FANTASY XIV",
    ["ffxiv_dx11"] = "FINAL FANTASY XIV",
    ["ffxv_s"] = "FINAL FANTASY XV WINDOWS EDITION",
    ["fifa"] = "FIFA 11 and 12",
    ["fifa10"] = "FIFA 10",
    ["fifa13"] = "FIFA 13",
    ["fifa14"] = "FIFA 14",
    ["fifa15"] = "FIFA 15",
    ["fifa16"] = "FIFA 16",
    ["fifa17"] = "FIFA 17",
    ["fifa18"] = "FIFA 18",
    ["final_exam"] = "Final Exam",
    ["firefallclient"] = "Firefall",
    ["firewatch"] = "Firewatch",
    ["fishingplanet"] = "Fishing Planet",
    ["fivenightsatfreddys"] = "Five Nights at Freddy's",
    ["fivenightsatfreddys2"] = "Five Nights at Freddy's 2",
    ["flagac4bfsp"] = "Assassin's Creed IV: Black Flag",
    ["flamebreak"] = "Flamebreak",
    ["flexdemorelease"] = "FLEX",
    ["fm"] = "Football Manager 2018",
    ["forgettabledungeon"] = "The Forgettable Dungeon",
    ["forhonor"] = "For Honor",
    ["fortify"] = "FORTIFY",
    ["fortniteclient-win64-shipping"] = "Fortnite",
    ["fortniteclient-win64-shipping_be"] = "Fortnite",
    ["forts"] = "Forts",
    ["fouc"] = "FlatOut Ultimate Carnage",
    ["foxgame-win32-shipping"] = "Blacklight: Retribution",
    ["foxgame-win32-shipping_be"] = "Blacklight: Retribution",
    ["fp"] = "Freedom Planet",
    ["fractured space"] = "Fractured Space",
    ["freeman guerrilla warfare"] = "Freeman: Guerrilla Warfare",
    ["freestyle2"] = "Freestyle Basketball 2",
    ["from_dust"] = "From Dust",
    ["from_the_depths"] = "From The Depths",
    ["frontend"] = "Tiger Knight",
    ["frontmissionevolved"] = "Front Mission Evolved",
    ["frostpunk"] = "Frostpunk",
    ["frostrunner-win64-shipping"] = "FrostRunner",
    ["fsasgame"] = "Secret Files 3",
    ["fsd-win64-shipping"] = "Deep Rock Galactic",
    ["fsw2"] = "Full Spectrum Warrior: Ten Hammers",
    ["fsx"] = "Microsoft Flight Simulator X: Steam Edition",
    ["ftk"] = "For The King",
    ["ftlgame"] = "FTL: Faster Than Light",
    ["funnyfarm"] = "Toontown's Funny Farm",
    ["furi"] = "Furi",
    ["fusion"] = "Kega Fusion",
    ["future soldier"] = "Tom Clancy's Ghost Recon: Future Solider",
    ["future soldier dx11"] = "Tom Clancy's Ghost Recon Future Soldier",
    ["futurewars"] = "Future Wars",
    ["gahkthun"] = "Gahkthun of the Golden Lightning",
    ["galciv2"] = "Galactic Civilization 2",
    ["galciv3"] = "Galactic Civilization 3",
    ["game"] = "The Red Solstice",
    ["gameclient"] = "Horizon Source",
    ["gameguard.des"] = "Metin2",
    ["gamemd"] = "Command & Conquer: Red Alert 2",
    ["gameroyale2"] = "Game Royale 2 - The Secret of Jannis Island",
    ["gamewin32retailsteam"] = "Riptide GP2",
    ["gang beasts"] = "Gang Beasts",
    ["garden"] = "Garden",
    ["gc2twilightofthearnor"] = "Galactic Civilizations II: Ultimate Edition",
    ["ge"] = "Granado Espada",
    ["ge2rb"] = "GOD EATER 2 Rage Burst",
    ["generals"] = "Command & Conquer™: Generals and Zero Hour",
    ["genitaljousting"] = "Genital Jousting",
    ["geometrydash"] = "Geometry Dash",
    ["geometrywars"] = "Geometry Wars",
    ["gettingoverit"] = "Getting Over It with Bennett Foddy",
    ["getwrecked"] = "Wrecked",
    ["ggxxacpr_win"] = "Guilty Gear XX Accent Core Plus R",
    ["gh3"] = "Guitar Hero III: Legends of Rock",
    ["ghostrecon"] = "Tom Clancy's Ghost Recon",
    ["ghwt"] = "Guitar Hero World Tour",
    ["gizmo_game-win64-shipping"] = "Gizmo",
    ["gjl"] = "Galactic Junk League",
    ["glquake"] = "Quake",
    ["glyphclientapp"] = "Trove",
    ["gn_enbu"] = "Touhou Puppet Dance Performance",
    ["goatgame-win32-shipping"] = "Goat Simulator",
    ["godmode"] = "God Mode",
    ["goldrushthegame"] = "Gold Rush: The Game",
    ["golf with your friends"] = "Golf With Your Friends",
    ["golfit-win64-shipping"] = "Golf It!",
    ["gonner"] = "GoNNER",
    ["goog"] = "Grey Goo",
    ["gop3"] = "Governor of Poker 3",
    ["gorn"] = "GORN",
    ["gp5"] = "Guitar Pro 5",
    ["grandia2"] = "Grandia 2",
    ["graveyard keeper"] = "Graveyard Keeper",
    ["grb"] = "Tom Clancy's Ghost Recon Breakpoint",
    ["greed"] = "Greed: Black Border",
    ["grickle101"] = "Puzzle Agent",
    ["grickle102"] = "Puzzle Agent 2",
    ["grid"] = "Grid",
    ["grid2"] = "Grid 2",
    ["grid2_avx"] = "GRID 2",
    ["gridautosport_avx"] = "GRID: Autosport",
    ["grim dawn"] = "Grim Dawn",
    ["grimfandango"] = "Grim Fandango",
    ["grip-win64-shipping"] = "GRIP",
    ["grisaia"] = "Grisaia no Kajitsu",
    ["growhome"] = "Grow Home",
    ["grw"] = "Tom Clancy's Ghost Recon Wildlands",
    ["gta--vc"] = "Grand Theft Auto: Vice City",
    ["gta-sa"] = "Grand Theft Auto San Andreas",
    ["gta-vc"] = "Grand Theft Auto: Vice City",
    ["gta3"] = "Grand Theft Auto III",
    ["gta5"] = "Grand Theft Auto V",
    ["gta_sa"] = "Grand Theft Auto: San Andreas",
    ["gtaiv"] = "Grand Theft Auto IV",
    ["guac"] = "Guacamelee",
    ["guild-quest"] = "Guild Quest",
    ["guild3"] = "The Guild 3",
    ["guildii"] = "The Guild II",
    ["guiltygearxrd"] = "Guilty Gear Xrd -SIGN-",
    ["guitarpro"] = "Guitar Pro 6",
    ["guitarpro7"] = "Guitar Pro 7",
    ["gunpoint"] = "Gunpoint",
    ["guns up"] = "GUNS UP!",
    ["gunsnboxes"] = "Guns N' Boxes",
    ["gunsoficarusonline"] = "Guns of Icarus - Online",
    ["gunz2_steam"] = "GunZ 2: The Second duel",
    ["gw"] = "Guild Wars",
    ["gw2"] = "Guild Wars 2",
    ["gw2-64"] = "Guild Wars 2",
    ["gw2.main_win64_retail"] = "Plants vs Zombies GW2",
    ["gw3"] = "Geometry Wars 3",
    ["gwent"] = "Gwent",
    ["gzdoom - play brutal doom"] = "Brutal Doom",
    ["gzwclientsteam-win64-shipping"] = "Gray Zone Warfare",
    ["h1z1"] = "H1Z1",
    ["h5_game"] = "Might and Magic - Heroes V",
    ["hackerevolution"] = "Hacker Evolution",
    ["hacknet"] = "Hacknet",
    ["halfdead"] = "Half dead",
    ["halo_online"] = "Halo Online",
    ["hammerwatch"] = "Hammerwatch",
    ["hand simulator"] = "Hand Simulator",
    ["happrentice"] = "Houdini",
    ["harry2"] = "LEGO Harry Potter: Years 5-7",
    ["harvey"] = "Edna & Harvey: Harvey's New Eyes",
    ["hatintimegame"] = "A Hat in Time",
    ["hatoful"] = "Hatoful Boyfriend",
    ["hawkengame-win32-shipping"] = "Hawken",
    ["hawx"] = "Tom Clancy's H.A.W.X",
    ["hawx2"] = "Tom Clancy's H.A.W.X 2",
    ["hawx2_dx11"] = "Tom Clancy's H.A.W.X 2",
    ["hawx_dx10"] = "Tom Clancy's H.A.W.X DX10",
    ["hcb"] = "Hyper Color Ball",
    ["hearthstone"] = "Hearthstone",
    ["heat_signature"] = "Heat Signature",
    ["heavyweapon"] = "Heavy Weapon",
    ["hellbladegame"] = "Hellblade: Senua's Sacrifice",
    ["hellbladegame-win64-shipping"] = "Hellblade: Senua's Sacrifice",
    ["hellbound-win64-shipping"] = "Hellbound: Survival Mode",
    ["helldivers"] = "HELLDIVERS™",
    ["hellion"] = "HELLION",
    ["herald"] = "Herald: An Interactive Period Drama",
    ["hero_siege"] = "Hero Siege",
    ["heroes"] = "마비노기 영웅전",
    ["heroesandgeneralsdesktop"] = "Heroes & Generals",
    ["heroesofthestorm"] = "Heroes of the Storm",
    ["heroesofthestorm_x64"] = "Heroes of the Storm",
    ["hex"] = "Hex: Shards of Fate",
    ["hexpatch"] = "Hex: Shards of Fate",
    ["hhfirstride_09_02_2018_17_28"] = "Hitchhiker",
    ["hideandshriek-win64-shipping"] = "Hide and Shriek",
    ["highoctanedrift"] = "High Octane Drift",
    ["hillclimbracing.windows"] = "Hill Climb Racing",
    ["hindie"] = "Houdini",
    ["hiveswap-act1"] = "HIVESWAP: ACT 1",
    ["hkship"] = "Sleeping Dogs",
    ["hl"] = "Half-Life: C.A.G.E.D.",
    ["hl2"] = "Team Fortress 2",
    ["hl2hl2"] = "Half Life 2",
    ["hl2p"] = "Portal",
    ["hl2tf"] = "Team Fortress 2",
    ["hma"] = "Hitman: Absolution",
    ["hmm"] = "Heavy Metal Machines",
    ["hng"] = "Heroes and Generals",
    ["hoi4"] = "Hearts of Iron IV",
    ["holdfast naw"] = "Holdfast: Nations At War",
    ["hollow_knight"] = "Hollow Knight",
    ["holodrive"] = "Holodrive",
    ["holyavatarvs"] = "Holy Avatar vs. Maidens of the Dead",
    ["hom"] = "Hero of Many",
    ["homefront"] = "Homefront",
    ["homefront2_release"] = "Homefront: The Revolution",
    ["hon"] = "Heroes of Newerth",
    ["horizonforbiddenwest"] = "Horizon Forbidde West",
    ["horseshoes & hand grenades"] = "Hot Dogs",
    ["hotlava"] = "Hot Lava",
    ["hotlinegl"] = "Hotline Miami",
    ["hotlinemiami"] = "Hotline Miami",
    ["hotlinemiami2"] = "Hotline Miami 2: Wrong Number",
    ["houseflipper"] = "House Flipper",
    ["houseparty"] = "House Party",
    ["howtosurvive"] = "How to survive",
    ["howtosurvive2"] = "How to Survive 2",
    ["human"] = "Human: Fall Flat",
    ["hungerdungeon"] = "Hunger Dungeon",
    ["huniecamstudio"] = "HunieCam Studio",
    ["huniepop"] = "HuniePop",
    ["hunt"] = "Hunt: Showdown",
    ["huntgame"] = "Hunt: Showdown",
    ["hurtworld"] = "Hurtworld",
    ["hurtworldclient"] = "Hurtworld",
    ["hwr"] = "Heroes of Hammerwatch",
    ["hydropc"] = "Hydrophobia: Prophecy",
    ["hyperlightdrifter"] = "Hyper Light Drifter",
    ["iamalive_game"] = "I Am Alive",
    ["iamweaponrevival"] = "I am weapon: Revival",
    ["ibbobb"] = "ibb & obb",
    ["ic"] = "Impossible Creatures",
    ["icarus-win64-shipping"] = "Icarus",
    ["idledragons"] = "Idle Champions of the Forgotten Realms",
    ["ige_wpf64"] = "Far Cry 4",
    ["impossiblegame"] = "The Impossible Game",
    ["in between"] = "In Between",
    ["infantry"] = "Infantry",
    ["injustice"] = "Injustice: Gods Among Us Ultimate Edition",
    ["injustice2"] = "Injustice 2",
    ["insanity-win32-shipping"] = "Afterfall Insanity:Extended Edition",
    ["inside"] = "Inside",
    ["insulam-win64-shipping"] = "Estranged: Act II",
    ["insurgency"] = "Insurgency",
    ["insurgencyclient-win64-shipping"] = "Insurgency: Sandstorm",
    ["invisibleinc"] = "Invisible Inc.",
    ["ionbranch_be"] = "Islands of Nyne: Battle Royale",
    ["iracingsim"] = "iRacing",
    ["iracingsim64"] = "iRacing",
    ["ironsnout"] = "Iron Snout",
    ["isaac"] = "The Binding of Isaac",
    ["isaac-ng"] = "The Binding of Isaac: Rebirth",
    ["istrolid"] = "Istrolid",
    ["iw3mp"] = "Call of Duty: Modern Warfare",
    ["iw3sp"] = "Call of Duty: Modern Warfare",
    ["iw4mp"] = "Call of Duty: Modern Warfare 2 - Multiplayer",
    ["iw4sp"] = "Call of Duty: Modern Warfare 2",
    ["iw5mp"] = "Call of Duty: Modern Warfare 3 - Multiplayer",
    ["iw5sp"] = "Call of Duty: Modern Warfare 3",
    ["iw6mp64_ship"] = "Call of Duty Ghosts: Multiplayer",
    ["iw6sp64_ship"] = "Call of Duty: Ghosts",
    ["iw7_ship"] = "Call of Duty: Infinite Warfare",
    ["iwbtgbeta(fs)"] = "I Wanna Be The Guy",
    ["iwbtgbeta(slomo)"] = "I Wanna Be The Guy",
    ["jalopy"] = "Jalopy",
    ["jamp"] = "Star Wars Jedi Knight",
    ["jasp"] = "STAR WARS™ Jedi Knight: Jedi Academy™",
    ["javaw"] = "Minecraft",
    ["jd2017"] = "Just Dance 2017",
    ["jk2mp"] = "Star Wars Jedi Knight II",
    ["jk2mvmp_x64"] = "Star Wars Jedi Knight II",
    ["jk2mvmp_x86"] = "Star Wars Jedi Knight II",
    ["joar"] = "Journey of a Roach",
    ["joshua"] = "SuperPower 2",
    ["jurassicpark100"] = "Jurassic Park: The Game",
    ["justcause"] = "Just Cause",
    ["justcause2"] = "Just Cause 2",
    ["justcause3"] = "Just Cause 3",
    ["justfishing"] = "Just Fishing",
    ["justice_league_vr_the_complete_experience-1.0.1-htcvive-release"] = "Justice League VR: The Complete Experience",
    ["jwe"] = "Jurassic World Evolution",
    ["kag"] = "King Arthur's Gold",
    ["kancolleviewer"] = "KanColle",
    ["kaneandlynch"] = "Kane and Lynch: Dead Men",
    ["kathyrain"] = "Kathy Rain",
    ["kenshi_x64"] = "Kenshi",
    ["keystonepublic.x64"] = "Keystone",
    ["kfgame"] = "Killing Floor 2",
    ["kidgame"] = "Killer Is Dead - Nightmare Edition",
    ["killingfloor"] = "Killing Floor",
    ["king's quest 1 sci"] = "King's Quest I",
    ["king's quest 2"] = "King's Quest II",
    ["king's quest 3"] = "King's Quest III",
    ["king's quest 4"] = "King's Quest IV",
    ["king's quest 5"] = "King's Quest V",
    ["king's quest 6 win"] = "King's Quest VI",
    ["king's quest 7"] = "King's Quest VII",
    ["kingdom"] = "Kingdom: New Lands",
    ["kingdomcome"] = "Kingdom Come: Deliverance",
    ["kingdomsandcastles"] = "Kingdoms and Castles",
    ["kingoffighters2002um"] = "The King Of Fighters 2002 Unlimited Match",
    ["kofxiii"] = "The King of Fighters XIII",
    ["kopp2"] = "Knights of Pen & Paper II",
    ["kritika_client"] = "Kritika Online",
    ["kshootmania"] = "K-Shoot Mania",
    ["ksp"] = "Kerbal Space Program",
    ["ksp_x64"] = "Kerbal Space Program",
    ["ktane"] = "Keep Talking and Nobody Explodes",
    ["l2"] = "Lineage II",
    ["landmark64"] = "Landmark",
    ["lanoire"] = "L.A. Noire",
    ["lanpatcher"] = "L.A. Noire",
    ["launchgtaiv"] = "Grand Theft Auto IV",
    ["launchpad"] = "Just Survive",
    ["lawbreakers"] = "LawBreakers",
    ["layers of fear"] = "Layers of Fear",
    ["lcgol"] = "Lara Croft and the Guardian of Light",
    ["leagueclientux"] = "League of Legends",
    ["learn to fly 3"] = "Learn to Fly 3",
    ["left4dead"] = "Left 4 Dead",
    ["left4dead2"] = "Left 4 Dead 2",
    ["lego_worlds_dx11"] = "LEGO® Worlds",
    ["legobatman"] = "LEGO Batman",
    ["legobatman2"] = "LEGO® Batman 2 DC Super Heroes™",
    ["legoemmet"] = "The LEGO® Movie - Videogame",
    ["legoharrypotter"] = "LEGO Harry Potter: Years 1-4",
    ["legohobbit"] = "LEGO: The Hobbit",
    ["legohobbit_dx11"] = "LEGO: The Hobbit",
    ["legoindy"] = "LEGO Indiana Jones: The Original Adventures",
    ["legojurassicworld_dx11"] = "LEGO® Jurassic World",
    ["legomarvel"] = "LEGO® MARVEL Super Heroes",
    ["legomarvelavengers_dx11"] = "LEGO® MARVEL's Avengers",
    ["legoninjago_dx11"] = "The LEGO® NINJAGO® Movie Video Game",
    ["legopirates"] = "LEGO Pirates of the Caribbean: The Video Game",
    ["legostarwarssaga"] = "LEGO® Star Wars™: The Complete Saga",
    ["legoswtfa_dx11"] = "LEGO® STAR WARS™: The Force Awakens",
    ["lethalleague"] = "Lethal League",
    ["letthemcome"] = "Let Them Come",
    ["life is strange - before the storm"] = "Life is Strange: Before the Storm",
    ["lifeisstrange"] = "Life Is Strange",
    ["lightroom"] = "Adobe Lightroom",
    ["limbo"] = "Limbo",
    ["lineage"] = "Lineage",
    ["lineageii"] = "Lineage II",
    ["lisa"] = "LISA",
    ["littlenightmares"] = "Little Nightmares",
    ["llo_beta2"] = "Love Live Online",
    ["lms"] = "Last Man Standing",
    ["loadout"] = "Loadout",
    ["locksquest"] = "Lock's Quest",
    ["lol"] = "League of Legends",
    ["lolclient"] = "League of Legends",
    ["long live santa"] = "Long Live Santa!",
    ["longlivethequeen"] = "Long Live The Queen",
    ["looterkings"] = "Looterkings",
    ["lordsofthefallen"] = "Lords of the Fallen",
    ["lost_castle"] = "Lost Castle",
    ["losthorizon2"] = "Lost Horizon 2",
    ["lostsaga"] = "Lost Saga",
    ["lotdgame"] = "Deadlight",
    ["lotroclient"] = "Lord of the Rings Online",
    ["love"] = "Move or Die",
    ["lovelyplanet"] = "Lovely Planet",
    ["loversinadangerousspacetime"] = "Lovers in a Dangerous Spacetime",
    ["lr2"] = "Lunatic Rave 2",
    ["lr2body"] = "Lunatic Rave 2",
    ["lrff13"] = "LIGHTNING RETURNS: FINAL FANTASY XIII",
    ["lro"] = "Limit Ragnarok Online",
    ["lsgame_be"] = "Line of Sight",
    ["lss"] = "Loading Screen Simulator",
    ["lumini_win64"] = "Lumini",
    ["lyne"] = "LYNE",
    ["m1-win64-shipping"] = "The First Descendant",
    ["mabinogi"] = "Mabinogi",
    ["madmachines"] = "Mad Machines",
    ["madmax"] = "Mad Max",
    ["mafia2"] = "Mafia 2",
    ["mafia3"] = "Mafia III",
    ["magicduels"] = "Magic Duels",
    ["magicite"] = "Magicite",
    ["magicka"] = "Magicka",
    ["magicka2"] = "Magicka 2",
    ["main"] = "BLOCKADE 3D",
    ["maniaplanet"] = "TrackMania² Stadium",
    ["maplestory"] = "MapleStory",
    ["maplestory2"] = "MapleStory 2",
    ["marssteam"] = "Surviving Mars",
    ["marvel-win64-shipping"] = "Marvel Rivals",
    ["marvelheroes2015"] = "Marvel Heroes 2015",
    ["marvelheroes2016"] = "Marvel Heroes 2016",
    ["masseffect"] = "Mass Effect",
    ["masseffect2"] = "Mass Effect 2",
    ["masseffect3"] = "Mass Effect 3",
    ["masseffect3demo"] = "Mass Effect 3",
    ["masseffectandromeda"] = "Mass Effect™: Andromeda",
    ["masterreboot"] = "Master Reboot",
    ["maxpayne3"] = "Max Payne 3",
    ["maya"] = "Autodesk Maya",
    ["mb_warband"] = "Mount & Blade: Warband",
    ["mb_wfas"] = "Mount & Blade: With Fire and Sword",
    ["mba"] = "Magical Battle Arena",
    ["mbaa"] = "Melty Blood Actress Again: Current Code",
    ["mban_f"] = "Magical Battle Arena NEXT",
    ["mban_m"] = "Magical Battle Arena NEXT",
    ["mcengine"] = "McOsu",
    ["me2game"] = "Mass Effect™ 2",
    ["mechwarrioronline"] = "MechWarrior Online",
    ["mechwarrioronline.exe"] = "Mech Warrior Online",
    ["medieval2"] = "Medieval II: Total War",
    ["medievalengineers"] = "Medieval Engineers",
    ["memoria"] = "Memoria",
    ["menofvalor"] = "Men of Valor",
    ["meridian - new world"] = "Meridian: New World",
    ["metal gear rising revengeance"] = "Metal Gear Rising: Revengeance",
    ["meteor60seconds"] = "Meteor 60 Seconds!",
    ["metro"] = "Metro Redux",
    ["metro2033"] = "Metro 2033",
    ["metroconflict"] = "Metro Conflict: The Origin",
    ["metroexodus"] = "Metro Exodus",
    ["metroll"] = "Metro Last Light",
    ["metronomicon"] = "The Metronomicon: Slay The Dance Floor",
    ["mgs2_sse"] = "Metal Gear Solid 2: Substance",
    ["mgsgroundzeroes"] = "Metal Gear Solid V: Ground Zeroes",
    ["mgsi"] = "Metal Gear Solid",
    ["mgsvmgo"] = "Metal Gear Online 3",
    ["mgsvtpp"] = "METAL GEAR SOLID V: THE PHANTOM PAIN",
    ["mgv"] = "METAL GEAR SURVIVE BETA",
    ["mhf"] = "Monster Hunter Frontier",
    ["mhoclient"] = "Monster Hunter Online",
    ["micromachines"] = "Micro Machines World Series",
    ["microsimulator"] = "Microtransaction Simulator",
    ["midair-win64-test"] = "Midair",
    ["mindnight"] = "MINDNIGHT",
    ["minecraft"] = "Minecraft",
    ["minimetro"] = "Mini Metro",
    ["minionmasters"] = "Minion Masters",
    ["mirrorlayers"] = "Mirror Layers",
    ["mirrorsedge"] = "Mirrors Edge",
    ["mirrorsedgecatalyst"] = "Mirror's Edge: Catalyst",
    ["miscreated"] = "Miscreated",
    ["misstake"] = "The Marvellous Miss Take",
    ["mitosis"] = "Mitos.is: The Game",
    ["mj"] = "セガNET麻雀MJ",
    ["mk10"] = "Mortal Kombat 10",
    ["mkhdgame"] = "Mortal Kombat Arcade Kollection",
    ["mkke"] = "Mortal Kombat Komplete Edition",
    ["mn9game"] = "Mighty Number 9",
    ["mobiusff"] = "MOBIUS FINAL FANTASY",
    ["moderncombatversus"] = "Modern Combat Versus",
    ["momodorarutm"] = "Momodora: Reverie Under the Moonlight",
    ["monaco"] = "Monaco: What's Yours Is Mine",
    ["monkeyisland101"] = "Tales of Monkey Island",
    ["monkeyisland102"] = "Tales of Monkey Island",
    ["monkeyisland103"] = "Tales of Monkey Island",
    ["monkeyisland104"] = "Tales of Monkey Island",
    ["monkeyisland105"] = "Tales of Monkey Island",
    ["monsterhunterworld"] = "MONSTER HUNTER: WORLD",
    ["monsterprom"] = "Monster Prom",
    ["moonbasealphagame"] = "Moonbase Alpha",
    ["moonlighter"] = "Moonlighter",
    ["morrowind"] = "Morrowind",
    ["mountain"] = "Mountain",
    ["mountyourfriends"] = "Mount Your Friends",
    ["mow_assualt_squad"] = "Men Of War: Assault Squad",
    ["mowas2"] = "Men Of War: Assault Squad 2",
    ["mowas_2"] = "Men of War: Assault Squad 2",
    ["mudrunner"] = "Spintires: MudRunner",
    ["mugen"] = "M.U.G.E.N",
    ["mugensouls"] = "Mugen Souls",
    ["mulegend"] = "MU Legend",
    ["multi theft auto"] = "Multi Theft Auto San Andreas",
    ["munin"] = "Munin",
    ["murder miners"] = "Murder Miners",
    ["mwoclient"] = "MechWarrior Online",
    ["mxreflex"] = "MX vs. ATV Reflex",
    ["mxvsatv"] = "MX vs. ATV Unleashed",
    ["mycomgames"] = "Warface",
    ["mysummercar"] = "My Summer Car",
    ["napoleon"] = "Napoleon: Total War",
    ["nba2k13"] = "NBA 2k13",
    ["nba2k14"] = "NBA 2k14",
    ["nba2k15"] = "NBA 2k15",
    ["nba2k18"] = "NBA 2K18",
    ["necrodancer"] = "Crypt of the NecroDancer",
    ["nekopara_vol0"] = "Nekopara Vol. 0",
    ["nekopara_vol1"] = "NEKOPARA Vol. 1",
    ["neoaquarium"] = "NEO AQUARIUM - The King of Crustaceans",
    ["neoscavenger"] = "NERO Scavenger",
    ["neptuniarebirth1"] = "Hyperdimension Neptunia Re;Birth1",
    ["neptuniarebirth2"] = "Hyperdimension Neptunia Re;Birth2",
    ["neptuniarebirth3"] = "Hyperdimension Neptunia Re;Birth3",
    ["neverwinter"] = "Neverwinter",
    ["newcolossus_x64vk"] = "Wolfenstein II: The New Colossus",
    ["nextday_game"] = "Next Day: Survival",
    ["nexus"] = "Nexus: The Jupiter Incident",
    ["nfs11"] = "Need for Speed: Hot Pursuit",
    ["nfs13"] = "Need For Speed Most Wanted 2012",
    ["nfs14"] = "Need For Speed: Rivals",
    ["nfs14_x86"] = "Need For Speed: Rivals",
    ["nfs16"] = "Need For Speed 2016",
    ["nfsc"] = "Need for Speed: Carbon",
    ["nicole"] = "Nicole (Otome Version)",
    ["nidhogg"] = "Nidhogg",
    ["nierautomata"] = "NieR:Automata",
    ["night in the woods"] = "Night in the Woods",
    ["nino2"] = "Ni no Kuni™ II: Revenant Kingdom",
    ["nitronicrush"] = "Nitronic Rush",
    ["nms"] = "No Man's Sky",
    ["nomad"] = "Nomad",
    ["northgard"] = "Northgard",
    ["novaro"] = "Nova Ragnarok Online",
    ["nrzgame"] = "Yaiba - Ninja Gaiden Z",
    ["ns2"] = "Natural Selection 2",
    ["ns3fb"] = "Naruto Shippuden Ultimate Ninja Storm 3 Full Burst",
    ["nsuns4"] = "NARUTO SHIPPUDEN: Ultimate Ninja STORM 4",
    ["nsunsr"] = "Naruto Shippuden Ultimate Ninja Storm Revolution",
    ["nuclearthrone"] = "Nuclear Throne",
    ["nvse_loader"] = "Fallout: New Vegas",
    ["nw"] = "Montaro",
    ["nwmain"] = "Neverwinter Nights",
    ["nxsteam"] = "Vindictus",
    ["obduction-win64-shipping"] = "Obduction",
    ["oblivion"] = "The Elder Scrolls 4: Oblivion",
    ["observer-win64-shipping"] = "Pneuma: Breath of Life",
    ["octodaddadliestcatch"] = "Octodad: Deadliest Catch",
    ["oforcsandmen_steam"] = "Of Orcs and Men",
    ["ogat"] = "Of Guards And Thieves",
    ["okami"] = "OKAMI HD / 大神 絶景版",
    ["olgame"] = "Outlast",
    ["olliolli2"] = "OlliOlli2",
    ["omdo"] = "OMDO",
    ["omensight"] = "Omensight",
    ["once_human"] = "Once Human",
    ["one finger death punch"] = "One Finger Death Punch",
    ["oneshot"] = "OneShot",
    ["onward"] = "Onward",
    ["opencodecs_0.85.17777"] = "FaceRig",
    ["openitg-pc"] = "In The Groove 2",
    ["openrct2"] = "Rollercoaster Tycoon 2",
    ["oppw3"] = "One Piece Pirate Warriors 3",
    ["opus rocket of whispers"] = "OPUS: Rocket of Whispers",
    ["orcsmustdie2"] = "Orcs Must Die! 2",
    ["order of battle - pacific"] = "Order of Battle: Pacific",
    ["organtrail"] = "Organ Trail",
    ["ori"] = "Ori and the Blind Forest",
    ["oride"] = "Ori and the Blind Forest: Definitive Edition",
    ["orion"] = "Guardians of ORION",
    ["orionclient-win64-shipping"] = "Paragon",
    ["orlando"] = "Dangerous Golf",
    ["orwell"] = "Orwell",
    ["osbuddy"] = "RuneScape",
    ["osirisnewdawn"] = "Osiris: New Dawn",
    ["osu!"] = "osu!",
    ["otherlandsclient-win64-shipping"] = "Rend",
    ["outlast2"] = "Outlast 2",
    ["overcooked"] = "Overcooked",
    ["overcooked2"] = "Overcooked! 2",
    ["overgrowth"] = "Overgrowth",
    ["overwatch"] = "Overwatch",
    ["owlboy"] = "Owlboy",
    ["oxygennotincluded"] = "Oxygen Not Included",
    ["pa"] = "Planetary Annihilation",
    ["paintball war"] = "Paintball War",
    ["paintthetownred"] = "Paint the Town Red",
    ["paladins"] = "Paladins",
    ["pandora"] = "Pandora: Eclipse of Nashira",
    ["pang"] = "Pang Adventures",
    ["papersplease"] = "Papers, Please",
    ["paradiseisland"] = "Paradise Island",
    ["passpartout"] = "Passpartout: The Starving Artist",
    ["pathofexile"] = "Path of Exile",
    ["pathofexile2"] = "Path of Exile 2",
    ["pathofexile_x64steam"] = "Path of Exile",
    ["pathofexilesteam"] = "Path of Exile",
    ["patriots"] = "Rise of Nations: Extended Edition",
    ["pavlov-win64-shipping"] = "Pavlov VR",
    ["payday2_win32_release"] = "PAYDAY 2",
    ["payday_win32_release"] = "PAYDAY: The Heist",
    ["pbbg_win32"] = "Phantom Break: Baggle Grounds",
    ["pcars"] = "Project Cars",
    ["pcars2avx"] = "Project CARS 2",
    ["pcars64"] = "Project CARS",
    ["pcbs"] = "PC Building Simulator",
    ["pcsx2-r5875"] = "PCSX2",
    ["pctomb5"] = "Tomb Raider: Chronicles",
    ["pd"] = "Pixel Dungeon",
    ["perpetuum"] = "Perpetuum Online",
    ["phase_shift"] = "Phase Shift",
    ["pickcrafter"] = "PickCrafter",
    ["pillarsofeternity"] = "Pillars of Eternity",
    ["pillarsofeternityii"] = "Pillars of Eternity II: Deadfire",
    ["pinball"] = "3D Pinball: Space Cadet",
    ["pirate"] = "Pirate101",
    ["pitpeople"] = "Pit People",
    ["pixark"] = "PixARK",
    ["pixel heroes - byte and magic"] = "Pixel Heroes: Byte & Magic",
    ["pixel_dungeons"] = "Pixel Dungeon",
    ["pixelworlds"] = "Pixel Worlds",
    ["pizzeria simulator"] = "Freddy Fazbear's Pizzeria Simulator",
    ["plagueincevolved"] = "Plague Inc: Evolved",
    ["plagueincsc"] = "Plague Inc: Evolved",
    ["planetcoaster"] = "Planet Coaster",
    ["planetnomads"] = "Planet Nomads",
    ["planetside2_x64"] = "Planetside 2",
    ["planetside2_x86"] = "Planetside 2",
    ["plantsvszombies"] = "Plants vs. Zombies",
    ["playbns"] = "Blade & Soul",
    ["playjcmp"] = "Just Cause™ 3: Multiplayer Mod",
    ["playsnow"] = "SNOW",
    ["please"] = "Papers",
    ["pneuma breath of life"] = "Pneuma: Breath of Life",
    ["pokemon trading card game online"] = "Pokémon Trading Card Game Online",
    ["pokemoninsurgence"] = "Pokemon Insurgence",
    ["pokemonshowdown"] = "Pokemon Showdown",
    ["pokernight2"] = "Poker Night 2",
    ["pol"] = "FINAL FANTASY XI",
    ["police"] = "This is the Police",
    ["police2"] = "This Is the Police 2",
    ["polybridge"] = "Poly Bridge",
    ["polynomial"] = "The Polynomial",
    ["poolians"] = "Real Pool 3D - Poolians",
    ["popcapgame1"] = "Plants Vs Zombies",
    ["portal2"] = "Portal 2",
    ["portal_knights_x64"] = "Portal Knights",
    ["portalwars-win64-shipping"] = "Splitgate: Arena Warfare",
    ["portia"] = "My Time At Portia",
    ["postal2"] = "POSTAL 2",
    ["postscriptum"] = "Post Scriptum",
    ["powder"] = "The Powder Toy",
    ["precisionx_x64"] = "EVGA Precision XOC",
    ["prey"] = "Prey",
    ["primalcarnagegame"] = "Primal Cargnage",
    ["princeofpersia"] = "Prince of Persia: Warrior Within",
    ["prison architect"] = "Prison Architect",
    ["prison architect safe mode"] = "Prison Architect",
    ["pro64_93_3"] = "Pokemon Revolution Online",
    ["prog"] = "Death Road to Canada",
    ["project_druid_retail_update"] = "Project Druid",
    ["project_rhombus"] = "Project Rhombus",
    ["projectg"] = "PangYa!",
    ["projectzomboid32"] = "Project Zomboid",
    ["projectzomboid64"] = "Project Zomboid",
    ["prominence-win64-shipping"] = "Prominence Poker",
    ["propwitchhuntmodule-win64-shipping"] = "Witch It",
    ["proteus"] = "Mega Man Legacy Collection",
    ["protog"] = "Proto-G",
    ["protog_preproduction"] = "Proto-G",
    ["prototypef"] = "Prototype",
    ["pso"] = "Phantasy Star Online",
    ["pso2"] = "PHANTASY STAR ONLINE 2",
    ["psobb"] = "Phantasy Star Online Blue Burst",
    ["psychonauts"] = "Psychonauts",
    ["punch club"] = "Punch Club",
    ["puyovs"] = "Puyo Puyo VS 2",
    ["pyre"] = "Pyre",
    ["q2rtx"] = "Quake II",
    ["quake"] = "Quake",
    ["quake1"] = "Quake I",
    ["quake2"] = "Quake II",
    ["quake3"] = "Quake III",
    ["quake4"] = "Quake IV",
    ["quakechampions"] = "Quake Champions",
    ["quakelive"] = "Quake Live",
    ["quakelive_steam"] = "Quake Live",
    ["quantumbreak"] = "Quantum Break",
    ["qubegame"] = "QUBE",
    ["questviewer"] = "Audiosurf",
    ["r6vegas2_game"] = "Tom Clancy's Rainbow Six Vegas II",
    ["r6vegas_game"] = "Tom Clancy's Rainbow Six Vegas",
    ["ra3"] = "Command and Conquer: Red Alert 3",
    ["ra3ep1"] = "Command and Conquer: Red Alert 3",
    ["rabbit"] = "The Night of the Rabbit",
    ["raceabit"] = "Race.a.bit",
    ["racethesun"] = "Race The Sun",
    ["rad-win64-shipping"] = "Rad Rodgers",
    ["radicalheights"] = "Radical Heights",
    ["raft"] = "Raft",
    ["rage"] = "RAGE",
    ["rage64"] = "RAGE",
    ["ragexe"] = "Ragnarok Zero",
    ["railroads"] = "Sid Meier's Railroads!",
    ["railworks"] = "Train Simulator",
    ["rainbowsix"] = "Tom Clancy's Rainbow Six Siege",
    ["rainbowsix_be"] = "Tom Clancy's Rainbow Six Siege",
    ["rainslick3"] = "Penny Arcade's On the Rain-Slick Precipice of Darkness 3",
    ["rainslick4"] = "Penny Arcade's On the Rain-Slick Precipice of Darkness 4",
    ["rampage_knights"] = "Rampage Knights",
    ["rats"] = "Bad Rats",
    ["ravenfield"] = "Ravenfield",
    ["ravenshield"] = "Tom Clancy's Rainbow Six 3",
    ["rayman legends"] = "Rayman Legends",
    ["rayman origins"] = "Rayman Origins",
    ["rayman2"] = "Rayman 2: The Great Escape",
    ["rct"] = "RollerCoaster Tycoon: Deluxe",
    ["rct2"] = "RollerCoaster Tycoon 2: Triple Thrill Pack",
    ["rct3plus"] = "RollerCoaster Tycoon 3: Platinum!",
    ["re5dx9"] = "Resident Evil 5 / Biohazard 5",
    ["re6"] = "Resident Evil 6",
    ["re7"] = "RESIDENT EVIL 7 biohazard / BIOHAZARD 7 resident evil",
    ["reactivedrop"] = "Alien Swarm: Reactive Drop",
    ["realliveen"] = "CLANNAD",
    ["realm of the mad god"] = "Realm of the Mad God",
    ["realmeac"] = "Realm Royale",
    ["realmgrinderdesktop"] = "Realm Grinder",
    ["reassemblyrelease"] = "Reassembly",
    ["rebelgalaxy"] = "Rebel Galaxy",
    ["rebelgalaxygog"] = "Rebel Galaxy",
    ["rebelgalaxysteam"] = "Rebel Galaxy",
    ["reckoning"] = "Kingdoms of Amalur: Reckoning",
    ["recroom_release"] = "Rec Room",
    ["red crucible"] = "Red Crucible: Firestorm",
    ["redfaction"] = "Red Faction",
    ["redout"] = "Redout",
    ["redout-win64-shipping"] = "Redout",
    ["redtrigger"] = "Red Trigger",
    ["reflex"] = "Reflex",
    ["reigns"] = "Reigns",
    ["reliccoh"] = "Company of Heroes",
    ["reliccoh2"] = "Company of Heroes 2",
    ["relicdow3"] = "Warhammer 40,000: Dawn of War 3",
    ["relichunterszero"] = "Relic Hunters Zero",
    ["rememberinghowwemet"] = "A Kiss For The Petals - Remembering How We Met",
    ["rememberme"] = "Remember Me",
    ["removesaves"] = "Mafia II",
    ["reprisaluniverse"] = "Reprisal Universe",
    ["rerev"] = "Resident Evil Revelations",
    ["rerev2"] = "Resident Evil Revelations 2",
    ["retrocityrampage"] = "Retro City Rampage",
    ["reus"] = "Reus",
    ["rf4_x64"] = "Russian Fishing 4",
    ["rfactor"] = "rFactor",
    ["rfactor2"] = "rFactor 2",
    ["rfg"] = "Red Faction: Guerrilla",
    ["ride"] = "$1 Ride",
    ["rift"] = "Rift",
    ["rift_x64"] = "RiFT",
    ["rik"] = "ProjectRIK",
    ["rimworld914win"] = "RimWorld",
    ["rimworldwin"] = "RimWorld",
    ["ringrunner"] = "Ring Runner",
    ["risen"] = "Risen",
    ["risen3"] = "Risen 3 - Titan Lords",
    ["risingstorm2"] = "Rising Storm 2",
    ["risk of rain"] = "Risk of Rain",
    ["rivalsofaether"] = "Rivals of Aether",
    ["rivergame-win64-shipping"] = "The Flame in the Flood",
    ["rks"] = "Rosenkreuzstilette Grollschwert",
    ["rks_e"] = "Rosenkreuzstilette Grollschwert",
    ["roa2-win64-shipping"] = "Rock of Ages 2",
    ["roblox"] = "ROBLOX",
    ["robloxplayerbeta"] = "Roblox",
    ["robloxstudiobeta"] = "Roblox Studio",
    ["robocraft"] = "Robocraft",
    ["robocraftclient"] = "Robocraft",
    ["rocketleague"] = "Rocket League",
    ["rockfest"] = "Rockfest",
    ["rocksmith"] = "Rocksmith",
    ["rocksmith2014"] = "Rocksmith 2014",
    ["rogame"] = "Rising Storm/Red Orchestra 2",
    ["roguelands"] = "Roguelands",
    ["roguelegacy"] = "Rogue Legacy",
    ["roguesystemsim"] = "Rogue System",
    ["rome2"] = "Total War: Rome 2",
    ["rometw"] = "Rome: Total War",
    ["ros"] = "Rules Of Survival",
    ["rotaku"] = "Rotaku Society",
    ["rott"] = "Rise of the Triad (2013)",
    ["rottr"] = "Rise of the Tomb Raider",
    ["rpg_rt"] = "Yume Nikki",
    ["rpgmv"] = "RPG Maker MV",
    ["rpgvxace"] = "RPG Maker VX Ace",
    ["rrre64"] = "RaceRoom Racing Experience",
    ["ruiner"] = "RUINER",
    ["ruiner-win64-shipping"] = "RUINER",
    ["runescape"] = "RuneScape",
    ["rust"] = "Rust - Staging Branch",
    ["rustclient"] = "Rust",
    ["rwby-ge"] = "RWBY: Grimm Eclipse",
    ["rwr_game"] = "RUNNING WITH RIFLES",
    ["rxgame-win64-shipping"] = "Gigantic",
    ["ryse"] = "Ryse: Son of Rome",
    ["s1_mp64_ship"] = "Call of Duty Advanced Warfare: Multiplayer",
    ["s1_sp64_ship"] = "Call of Duty Advanced Warfare",
    ["s2_mp64_ship"] = "Call of Duty: WWII",
    ["s2_sp64_ship"] = "Call of Duty®: WWII",
    ["s4client"] = "S4 League",
    ["sacred2"] = "Sacred 2 Gold",
    ["sacred3"] = "Sacred 3",
    ["safetyfirst"] = "Safety First!",
    ["saintsrowgatoutofhell"] = "Saints Row: Gat out of Hell",
    ["saintsrowiv"] = "Saints Row IV",
    ["saintsrowthethird"] = "Saints Row 3",
    ["saintsrowthethird_dx11"] = "Saints Row 3",
    ["salt"] = "Salt and Sanctuary",
    ["sam3"] = "Serious Sam 3: BFE",
    ["sanctumgame-win32-shipping"] = "Sanctum 2",
    ["saofb-win64-shipping"] = "Sword Art Online: Fatal Bullet",
    ["sas4-win"] = "SAS: Zombie Assault 4",
    ["satellitereignwindows"] = "Satellite Reign",
    ["satinav"] = "The Dark Eye: Chains of Satinav",
    ["sausage"] = "Stephen's Sausage Roll",
    ["sbs"] = "Slam Bolt Scrappers",
    ["sc2"] = "Starcraft II",
    ["sc2_x64"] = "StarCraft II",
    ["sc2vn"] = "SC2VN: The e-sport Visual Novel",
    ["scpsl"] = "SCP: Secret Laboratory",
    ["scrapmechanic"] = "Scrap Mechanic",
    ["screencheat"] = "Screencheat",
    ["scribble"] = "Scribblenauts Unmasked: A DC Comics Adventure",
    ["scum"] = "SCUM",
    ["sdhdship"] = "Sleeping Dogs: Definitive Edition",
    ["se4"] = "Space Empires IV",
    ["seagame"] = "Steel Ocean",
    ["secondlifeviewer"] = "Second Life",
    ["secretponchosd3d11"] = "Secret Ponchos",
    ["secrets of grindea"] = "Secrets of Grindea",
    ["segagameroom"] = "SEGA Mega Drive & Genesis Classics",
    ["seum"] = "SEUM: Speedrunners from Hell",
    ["sf3clientfinal"] = "SpellForce 3",
    ["sfm"] = "Source Filmmaker",
    ["sftk"] = "Street Fighter X Tekken",
    ["sgw3"] = "Sniper Ghost Warrior 3",
    ["sh-win64-shipping"] = "Desolate",
    ["sh3"] = "Silent Hunter 3",
    ["sh4"] = "Silent Hunter: Wolves of the Pacific",
    ["sh5"] = "Silent Hunter 5: Battle of the Atlantic",
    ["shadow tactics"] = "Shadow Tactics: Blades of the Shogun",
    ["shadowcomplex-win32"] = "Shadow Complex",
    ["shadowcomplex-win32-egl"] = "Shadow Complex",
    ["shadowgrounds"] = "Shadowgrounds",
    ["shadowofmordor"] = "Shadow Of Mordor",
    ["shadowofwar"] = "Middle-earth: Shadow of War",
    ["shadowrun"] = "Shadowrun Returns",
    ["shadowverse"] = "Shadowverse",
    ["shadowwarrior2"] = "Shadow Warrior 2",
    ["shakes and fidget"] = "Shakes and Fidget",
    ["shank"] = "Shank",
    ["shank2"] = "Shank 2",
    ["shantaecurse"] = "Shantae and the Pirate's Curse",
    ["shatteredplanet"] = "Shattered Planet",
    ["shatteredskies"] = "Shattered Skies",
    ["she4"] = "Silent Hunter 4: Wolves of the Pacific",
    ["shellshocklive"] = "ShellShock Live",
    ["shiny"] = "Shiny The Firefly",
    ["shipping-thiefgame"] = "Thief",
    ["shippingpc-afeargame"] = "Alien Rage",
    ["shippingpc-bmgame"] = "Batman Arkham Asylum",
    ["shippingpc-stormgame"] = "Bulletstorm",
    ["shock2"] = "System Shock 2",
    ["shogun2"] = "Total War: SHOGUN 2",
    ["shootergame"] = "Ark: Survival Evolved",
    ["shootergame-win32-shipping"] = "Dirty Bomb",
    ["shootergame_be"] = "ARK: Survival Of The Fittest",
    ["shooterultimate"] = "PixelJunk Shooter Ultimate",
    ["shootingstars"] = "Shooting Stars!",
    ["shootyskies"] = "Shooty Skies",
    ["shovelknight"] = "Shovel Knight",
    ["showerdad"] = "Shower With Your Dad Simulator 2015: Do You Still Shower With Your Dad",
    ["shroud of the avatar"] = "Shroud of the Avatar",
    ["shutupndigsteamm5"] = "Shut Up And Dig",
    ["silence"] = "Silence",
    ["simcity"] = "SimCity™",
    ["simcity 4"] = "SimCity 4 Deluxe",
    ["simpleplanes"] = "SimplePlanes",
    ["simpsons"] = "The Simpsons: Hit & Run",
    ["sims2ep9"] = "The Sims 2: Ultimate Collection",
    ["sinemora"] = "Sine-Mora",
    ["sinemoraex"] = "Sine Mora EX",
    ["sins of a solar empire rebellion"] = "Sins of a Solar Empire: Rebellion",
    ["sir"] = "Sir You Are Being Hunted",
    ["sisterlocation"] = "Five Nights at Freddy's: Sister Location",
    ["skilltree"] = "Skilltree Saga",
    ["skullgirls"] = "Skullgirls",
    ["skydrift"] = "Gensou SkyDrift",
    ["skyforge"] = "Skyforge",
    ["slap city"] = "Slap City",
    ["slaythespire"] = "Slay the Spire",
    ["slime-san"] = "Slime-san",
    ["slimerancher"] = "Slime Rancher",
    ["slw"] = "Sonic Lost World",
    ["smite"] = "Smite",
    ["smiteeac"] = "SMITE",
    ["sniper_x86"] = "Sniper: Ghost Warrior",
    ["sniperelite4"] = "Sniper Elite 4",
    ["sniperelitev2"] = "Sniper Elite V2",
    ["sniperghostwarrior2"] = "Sniper Ghost Warrior 2",
    ["soma"] = "Soma",
    ["sonic2app"] = "Sonic Adventure 2",
    ["sonic_vis"] = "Sonic the Hedgehog 4 EP 1",
    ["sonic_xp"] = "Sonic the Hedgehog 4 EP 1",
    ["sonicgenerations"] = "Sonic Generations",
    ["sonicmania"] = "Sonic Mania",
    ["sorts2"] = "Sword of the Stars II: Lords of Winter",
    ["sos-win64-shipping"] = "SOS",
    ["soulaxiom"] = "Soul Axiom",
    ["soulcraft"] = "SoulCraft",
    ["soulstorm"] = "Warhammer 40K: Dawn of War SoulSorm",
    ["soulworker"] = "SoulWorker",
    ["soulworker100"] = "Soul Worker Online",
    ["south park - the stick of truth"] = "South Park The Stick of Truth",
    ["southpark_tfbw"] = "South Park Fractured But Whole",
    ["spaceengineers"] = "Space Engineers",
    ["spacegame-win64-shipping"] = "Fractured Space",
    ["spacehulkgame-win64-shipping"] = "Space Hulk: Deathwing - Enhanced Edition",
    ["spazgame"] = "Space Pirates and Zombies",
    ["specopstheline"] = "Spec Ops: The Line",
    ["speed"] = "Need For Speed Most Wanted",
    ["speedrunners"] = "SpeedRunners",
    ["spellforce"] = "SpellForce: Platinum Edition",
    ["spellforce2"] = "SpellForce 2 - Anniversary Edition",
    ["spellsworn-win64-test"] = "Spellsworn",
    ["spelunky"] = "Spelunky",
    ["sphinxd_gl"] = "Sphinx and the Cursed Mummy",
    ["spintires"] = "Spintires",
    ["spitfiredashboard"] = "Orcs Must Die! Unchained",
    ["spitfiregame"] = "Orcs Must Die! Unchained",
    ["splintercell"] = "Tom Clancy's Splinter Cell",
    ["splintercell3"] = "Tom Clancy's Splinter Cell Chaos Theory",
    ["splitsecond"] = "Split/Second",
    ["spooky"] = "Spooky's Jump Scare Mansion",
    ["sporeapp"] = "Spore",
    ["spyparty"] = "Spy Party",
    ["squad22"] = "Meridian: Squad 22",
    ["sr2_pc"] = "Saints Row 2",
    ["srhk"] = "Shadowrun: Hong Kong",
    ["ss2013"] = "Surgeon Simulator",
    ["ssf2"] = "Super Smash Flash 2",
    ["ssfexe"] = "Super Smash Flash 1",
    ["ssfiv"] = "Ultra Street Fighter IV",
    ["sshock"] = "System Shock: Enhanced Edition",
    ["sspace"] = "Shaddow Space",
    ["stalker-cop"] = "S.T.A.L.K.E.R.: Call of Pripyat",
    ["stalker2-win64-shipping"] = "S.T.A.L.K.E.R. 2",
    ["stanley"] = "The Stanley Parable",
    ["star trek online"] = "Star Trek Online",
    ["star_trek_online"] = "Star Trek Online",
    ["starbound"] = "Starbound",
    ["starbound_opengl"] = "Starbound",
    ["starcitizen"] = "Star Citizen",
    ["starcraft"] = "StarCraft",
    ["starcraft ii"] = "Starcraft II",
    ["starcraft ii editor_x64"] = "Starcraft II Editor",
    ["stardew valley"] = "Stardew Valley",
    ["stardrive"] = "Star Drive",
    ["starwarsbattlefront"] = "STAR WARS Battlefront",
    ["starwarsg"] = "STAR WARS™ Empire at War: Gold Pack",
    ["stateofdecay"] = "State of Decay: Year-One",
    ["steeldivision"] = "Steel Division: Normandy 44",
    ["steinsgate"] = "STEINS;GATE",
    ["stellarimpact"] = "Stellar Impact",
    ["stellaris"] = "Stellaris",
    ["stepmania"] = "Step Mania",
    ["stepmania-sse2"] = "StepMania",
    ["stickfight"] = "Stick Fight: The Game",
    ["stonehearth"] = "Stonehearth",
    ["stoneshard"] = "Stoneshard: Prologue",
    ["stories"] = "Stories: The Path of Destinies",
    ["stranded_deep_x64"] = "Stranded Deep",
    ["streetfighteriv"] = "Street Fighter IV",
    ["streetfighterv"] = "Street Fighter V",
    ["streetfightervbeta-win64-shipping"] = "Street Fighter V",
    ["streetsofrogue"] = "Streets of Rogue",
    ["strife"] = "Strife",
    ["strife-ve"] = "Strife: Veteran Edition",
    ["strikersedge"] = "Striker's Edge",
    ["stronghold crusader"] = "Stronghold Crusader HD",
    ["styx2"] = "Styx: Shards of Darkness",
    ["styx2-win64-shipping"] = "Styx: Shards of Darkness",
    ["styxgame"] = "Styx: Master of Shadows",
    ["sublevelzero"] = "Sublevel Zero",
    ["submerge-win64-shipping"] = "Subsiege",
    ["subnautica"] = "Subnautica",
    ["sudeki"] = "Sudeki",
    ["summercamp"] = "Friday the 13th: The Game",
    ["sundered"] = "Sundered",
    ["sunless skies"] = "Sunless Skies",
    ["super treasure arena"] = "Super Treasure Arena",
    ["superdungeonbros"] = "Super Dungeon Bros",
    ["superflight"] = "Superflight",
    ["superhexagon"] = "Super Hexagon",
    ["superhot"] = "Superhot",
    ["superhotvr"] = "SUPERHOT VR",
    ["supermeatboy"] = "Super Meat Boy",
    ["supermncgameclient"] = "Super Monday Night Combat",
    ["supremecommander"] = "Supreme Commander: Forged Alliance",
    ["supremecommander2"] = "Supreme Commander 2",
    ["survivor"] = "Shadowgrounds: Survivor",
    ["svencoop"] = "Sven Co-op",
    ["sw.x64"] = "Shadow Warrior",
    ["swarm"] = "Alien Swarm",
    ["sweaw"] = "Star Wars: Empire at War",
    ["swiftkit-rs"] = "RuneScape",
    ["swkotor"] = "STAR WARS™: Knights of the Old Republic™",
    ["swkotor2"] = "STAR WARS™ Knights of the Old Republic™ II: The Sith Lords™",
    ["swordandsworcery_pc"] = "Superbrothers: Sword & Sworcery EP",
    ["swordcoast"] = "Sword Coast Legends",
    ["swordwithsauce-win64-shipping"] = "Sword With Sauce: Alpha",
    ["swrepubliccommando"] = "STAR WARS™ Republic Commando",
    ["swtor"] = "STAR WARS: The Old Republic",
    ["syndicate"] = "Syndicate",
    ["synergy"] = "Synergy",
    ["system shock2"] = "System Shock 2",
    ["system40"] = "Sengoku Rance",
    ["t-engine"] = "Tales of Maj'Eyal",
    ["t6sp"] = "Call of Duty: Black Ops",
    ["t6zm"] = "Call of Duty: Black Ops II",
    ["tabletop simulator"] = "Tabletop Simulator",
    ["tachyon"] = "Tachyon: The Fringe",
    ["tactical monsters"] = "Tactical Monsters Rumble Arena",
    ["tales of berseria"] = "Tales of Berseria",
    ["tales of zesteria"] = "Tales of Zestiria",
    ["talisman"] = "Talisman: Digital Edition",
    ["talos"] = "The Talos Principle",
    ["tane"] = "Trainz: A New Era",
    ["tbl-win64-shipping"] = "Mirage: Arcane Warfare",
    ["teeworlds"] = "Teeworlds",
    ["tekkengame-win64-shipping"] = "TEKKEN 7",
    ["tera"] = "TERA",
    ["terraria"] = "Terraria",
    ["terratechwin32"] = "TerraTech",
    ["terratechwin64"] = "TerraTech",
    ["tesv"] = "The Elder Scrolls V: Skyrim",
    ["tesv_original"] = "The Elder Scrolls V: Skyrim",
    ["tetris"] = "Tetris",
    ["tew2"] = "The Evil Within 2",
    ["th06"] = "Touhou 6: Embodiment of Scarlet Devil",
    ["th06e"] = "Touhou 6: Embodiment of Scarlet Devil",
    ["th07"] = "Touhou 7: Perfect Cherry Blossom",
    ["th075"] = "Touhou 7.5: Immaterial and Missing Power",
    ["th075e"] = "Touhou 7.5: Immaterial and Missing Power",
    ["th07e"] = "Touhou 7: Perfect Cherry Blossom",
    ["th08"] = "Touhou 8: Imperishable Night",
    ["th08e"] = "Touhou 8: Imperishable Night",
    ["th09"] = "Touhou 9: Phantasmagoria Of Flower View",
    ["th095"] = "Touhou 9.5: Shoot the Bullet",
    ["th095e"] = "Touhou 9.5: Shoot the Bullet",
    ["th09e"] = "Touhou 9: Phantasmagoria Of Flower View",
    ["th10"] = "Touhou 10: Mountain of Faith",
    ["th105"] = "Touhou 10.5: Scarlet Weather Rhapsody",
    ["th105e"] = "Touhou 10.5: Scarlet Weather Rhapsody",
    ["th10e"] = "Touhou 10: Mountain of Faith",
    ["th11"] = "Touhou 11: Subterranean Animism",
    ["th11e"] = "Touhou 11: Subterranean Animism",
    ["th12"] = "Touhou 12: Undefined Fantastic Object",
    ["th123"] = "Touhou 12.3: Hisoutensoku",
    ["th123e"] = "Touhou 12.3: Hisoutensoku",
    ["th125"] = "Touhou 12.5: Double Spoiler",
    ["th125e"] = "Touhou 12.5: Double Spoiler",
    ["th128"] = "Touhou 12.8: Great Fairy Wars",
    ["th128e"] = "Touhou 12.8: Great Fairy Wars",
    ["th12e"] = "Touhou 12: Undefined Fantastic Object",
    ["th13"] = "Touhou 13: Ten Desires",
    ["th135"] = "Touhou 13.5 Hopeless Mascarade",
    ["th135e"] = "Touhou 13.5 Hopeless Mascarade",
    ["th13e"] = "Touhou 13: Ten Desires",
    ["th14"] = "Touhou 14: Double Dealing Character",
    ["th143"] = "Touhou 14.3: Impossible Spell Card",
    ["th143e"] = "Touhou 14.3: Impossible Spell Card",
    ["th145"] = "Touhou 14.5: Urban Legend in Limbo",
    ["th145e"] = "Touhou 14.5: Urban Legend in Limbo",
    ["th14e"] = "Touhou 14: Double Dealing Character",
    ["th15"] = "Touhou 15: Legacy of Lunatic Kingdom",
    ["th15e"] = "Touhou 15: Legacy of Lunatic Kingdom",
    ["the banner saga"] = "The Banner Saga",
    ["the banner saga 2"] = "The Banner Saga 2",
    ["the banner saga 3"] = "Banner Saga 3",
    ["the dig"] = "The Dig",
    ["the elder scrolls legends"] = "The Elder Scrolls: Legends",
    ["the jackbox party pack 2"] = "The Jackbox Party Pack 2",
    ["the jackbox party pack 3"] = "The Jackbox Party Pack 3",
    ["the jackbox party pack 4"] = "The Jackbox Party Pack 4",
    ["the universim"] = "The Universim",
    ["thebaconing"] = "The Baconing",
    ["thebureau"] = "The Bureau: XCOM Declassified",
    ["thecrew"] = "The Crew",
    ["thecrew2"] = "The Crew 2 - Open Beta",
    ["thedivision"] = "Tom Clancy's The Division",
    ["thedivision2"] = "The Division 2",
    ["theescapists"] = "The Escapists",
    ["theescapists2"] = "The Escapists 2",
    ["theexit-win64-shipping"] = "DEATHGARDEN",
    ["theforest"] = "The Forest",
    ["thegreatcircle"] = "Indiana Jones and the Great Circle",
    ["thehuntercotw_f"] = "theHunter™: Call of the Wild",
    ["theinnerworld"] = "The Inner World",
    ["thelab"] = "The Lab",
    ["themod 1.3"] = "Tony Hawk's Underground 2",
    ["thenewz"] = "Infestation: The New Z",
    ["thepark"] = "The Park",
    ["therewasacaveman"] = "There Was A Caveman",
    ["thesecretworld"] = "The Secret World",
    ["thesecretworlddx11"] = "The Secret World",
    ["thespacegame"] = "Ascent - The Space Game",
    ["thesurge"] = "The Surge",
    ["thewalkingdead2"] = "The Walking Dead Season Two",
    ["thewolfamongus"] = "The Wolf Among Us",
    ["theyarebillions"] = "They Are Billions",
    ["thg_demo_3"] = "Titanic: Honor and Glory",
    ["think of the children beta"] = "Think of the Children",
    ["this war of mine"] = "This War of Mine",
    ["thmhj"] = "Fantastic Danmaku Festival",
    ["throneoflies"] = "Throne of Lies",
    ["thrones"] = "Total War Saga: Thrones of Britannia",
    ["thug"] = "Tony Hawk's Underground",
    ["thug2"] = "Tony Hawk's Underground 2",
    ["thugpro"] = "THUG Pro",
    ["tibia"] = "Tibia",
    ["timeclickers"] = "Time Clickers",
    ["tinybrains"] = "Tiny Brains",
    ["tis100"] = "TIS-100",
    ["titan"] = "Titan Souls",
    ["titanfall"] = "Titanfall",
    ["titanfall2"] = "Titanfall 2",
    ["tjpp"] = "The Jackbox Party Pack",
    ["tkom"] = "Take On Mars",
    ["tld"] = "The Long Dark",
    ["tljh-win64-shipping"] = "The Long Journey Home",
    ["tlr"] = "The Last Remnant",
    ["tmforever"] = "Trackmania United Forever",
    ["tmnt-oots"] = "Teenage Mutant Ninja Turtles: Out of Shadows",
    ["tmunitedforever"] = "Trackmania United Forever",
    ["to the moon"] = "To the Moon",
    ["tomb2"] = "Tomb Raider II",
    ["tomb3"] = "Tomb Raider III: Adventures of Lara Croft",
    ["tomb4"] = "Tomb Raider: The Last Revelation",
    ["tombraider"] = "Tomb Raider",
    ["toothandtail"] = "Tooth and Tail",
    ["torchlight"] = "Torchlight",
    ["torchlight2"] = "Torchlight II",
    ["toren"] = "Toren",
    ["toribash"] = "Toribash",
    ["torment"] = "Planescape: Torment",
    ["tormentorxpunisher"] = "Tormentor❌Punisher",
    ["totallyaccuratebattlegrounds"] = "Totally Accurate Battlegrounds",
    ["tower"] = "Tower Unite",
    ["tower-win64-shipping"] = "Tower Unite",
    ["townofsalem"] = "Town of Salem",
    ["townsmen"] = "Townsmen",
    ["toxikk"] = "TOXIKK",
    ["tph"] = "Two Point Hospital",
    ["tq"] = "Titan Quest",
    ["tr"] = "Trench Run",
    ["tra"] = "Tomb Raider: Anniversary",
    ["trackmaniaturbo"] = "Trackmania Turbo",
    ["traktor.amalgam.app"] = "Gear Up",
    ["transformersdevastation"] = "Transformers: Devastation",
    ["transformice"] = "Transformice",
    ["transistor"] = "Transistor",
    ["transition"] = "WAKFU",
    ["transportfever"] = "Transport Fever",
    ["traod_p4"] = "Tomb Raider: Angel of Darkness",
    ["trappeddeadlockdown"] = "Trapped Dead: Lockdown",
    ["trgame"] = "Tales Runner",
    ["triadwars"] = "Triad Wars",
    ["trials_fusion"] = "Trials Fusion",
    ["trialsblooddragon"] = "Trials of the Blood Dragon",
    ["trialsfmx"] = "Trials Evolution",
    ["tribesascend"] = "Tribes: Ascend",
    ["trickytowers"] = "Tricky Towers",
    ["trine"] = "Trine",
    ["trine1_32bit"] = "Trine Enchanted Edition",
    ["trine2_32bit"] = "Trine 2",
    ["trine3_32bit"] = "Trine 3",
    ["trine3_64bit"] = "Trine 3",
    ["tripletown"] = "Triple Town",
    ["tristoy"] = "TRISTOY",
    ["trl"] = "Tomb Raider: Legend",
    ["tron"] = "Tron 2.0",
    ["tropico4"] = "Tropico 4",
    ["trove"] = "Trove",
    ["tru"] = "Tomb Raider: Underworld",
    ["trulon"] = "Trulon: The Shadow Engine",
    ["ts3"] = "The Sims 3",
    ["ts3w"] = "The Sims 3",
    ["ts4"] = "The Sims 4",
    ["ts4_x64"] = "The Sims 4",
    ["tsa"] = "Touhou Sky Arena",
    ["tslgame"] = "Player Unknown's Battlegrounds",
    ["tslgame_be"] = "PUBG: Experimental Server",
    ["tsunmajo"] = "Tsundertaker's Mahou Removal",
    ["ttrengine"] = "Toontown Rewritten",
    ["turmoil_pc_full"] = "Turmoil",
    ["twinsector_steam"] = "Twin Sector",
    ["twwse"] = "The Whispered World Special Edition",
    ["tyranny"] = "Tyranny",
    ["udk"] = "Unreal Development Kit",
    ["udkgame"] = "Unmechanical",
    ["ue4-win64-shipping"] = "Unreal Tournament 4",
    ["ue4-win64-test"] = "Unreal Tournament 4",
    ["ue4editor"] = "Unreal Editor",
    ["ue4game-win64-shipping"] = "<disable>",
    ["uebs"] = "Ultimate Epic Battle Simulator",
    ["ultimate custom night"] = "Ultimate Custom Night",
    ["ultimatechickenhorse"] = "Ultimate Chicken Horse",
    ["undertale"] = "Undertale",
    ["undying"] = "Clive Barker's Undying",
    ["universe sandbox x64"] = "Universe Sandbox ²",
    ["uno"] = "UNO",
    ["unreal"] = "Unreal Gold",
    ["unrealtournament"] = "Unreal Tournament 4",
    ["unturned_be"] = "Unturned",
    ["uokr"] = "Ultima Online",
    ["urbantrialfreestyle"] = "Urban Trial Freestyle",
    ["ut2004"] = "Unreal Tournament 2004",
    ["ut3"] = "Unreal Tournament 3",
    ["uurnog"] = "Uurnog Uurnlimited",
    ["v2game"] = "Victoria II",
    ["va-11 hall a"] = "VA-11 Hall-A: Cyberpunk Bartender Action",
    ["valkyria"] = "Valkyria Chronicles™",
    ["valley"] = "Valley",
    ["vampire"] = "Vampire: The Masquerade - Bloodlines",
    ["vermintide"] = "Warhammer: End Times - Vermintide",
    ["vermintide2"] = "Warhammer: End Times - Vermintide 2",
    ["vermintide2_dx12"] = "Warhammer: End Times - Vermintide 2",
    ["vessel"] = "Vessel",
    ["vfracer"] = "Mantis Burn Racing",
    ["victoria2"] = "Victoria II",
    ["vikingrage"] = "Viking Rage",
    ["vindictus"] = "Vindictus",
    ["viridi"] = "Viridi",
    ["visconfig"] = "Ken Follett's The Pillars of the Earth",
    ["vngame"] = "Rising Storm 2: Vietnam",
    ["voxelfarmkit"] = "Voxel Farm",
    ["vrchat"] = "VRChat",
    ["vu"] = "Battlefield 3: Venice Unleashed",
    ["wa"] = "Worms Armageddon",
    ["walkingdead101"] = "The Walking Dead",
    ["war"] = "Warhammer Online",
    ["war-win64-shipping"] = "Foxhole",
    ["war3"] = "Warcraft III",
    ["warcraft ii bne"] = "Warcraft 2",
    ["warcraft iii"] = "Warcraft III",
    ["warframe.x64"] = "Warframe",
    ["wargame3"] = "Wargame: Red Dragon",
    ["warhammer"] = "Warhammer: Total War",
    ["warhammer2"] = "Total War: WARHAMMER II",
    ["warmode"] = "WARMODE",
    ["warrecs"] = "Warrecs",
    ["warrobots"] = "War Robots",
    ["warsow_x64"] = "Warsow",
    ["warsow_x86"] = "Warsow",
    ["watch_dogs"] = "Watch_Dogs",
    ["watchdogs2"] = "Watch_Dogs 2",
    ["wc3"] = "Warcraft 3: Reign of Chaos",
    ["we were here"] = "We Were Here",
    ["we were here too"] = "We Were Here Too",
    ["we were here vr"] = "We Were Here",
    ["weneedtogodeeper"] = "We Need to Go Deeper",
    ["wesnoth"] = "Battle for Wesnoth",
    ["west of loathing"] = "West of Loathing",
    ["wftogame"] = "War For The Overworld",
    ["whitesilence-win64-shipping"] = "Fade to Silence",
    ["whosyourdaddy"] = "Who's Your Daddy",
    ["wildstar"] = "WildStar",
    ["wildstar64"] = "WildStar",
    ["windscape"] = "Windscape",
    ["wings of vi"] = "Wings of Vi",
    ["winquake"] = "Quake",
    ["witcher"] = "The Witcher: Enhanced Edition",
    ["witcher2"] = "The Witcher 2: Assassins of Kings Enhanced Edition",
    ["witcher3"] = "The Witcher 3: Wild Hunt",
    ["witn"] = "The Lord of the Rings: War in the North",
    ["witness64_d3d11"] = "The Witness",
    ["wizard101"] = "Wizard101",
    ["wizardoflegend"] = "Wizard of Legend",
    ["wl2"] = "Wasteland II",
    ["wmencoderen"] = "The Guild 2 Renaissance",
    ["wmv9codec"] = "Bridge Constructor Stunts",
    ["wolcen"] = "Wolcen: Lords of Mayhem",
    ["wolfmp"] = "Return to Castle Wolfenstein",
    ["wolfneworder_x64"] = "Wolfenstein: The New Order",
    ["wolfoldblood_x64"] = "Wolfenstein: The Old Blood",
    ["wolfsp"] = "Return to Castle Wolfenstein",
    ["worldoftanks"] = "World of Tanks",
    ["worldofwarplanes"] = "World of Warplanes",
    ["worldofwarships"] = "World of Warships",
    ["worldsadrift"] = "Worlds Adrift",
    ["wormis"] = "Worm.is: The Game",
    ["worms w.m.d"] = "Worms W.M.D",
    ["wormsrevolution"] = "Worms Revolution",
    ["wotblitz"] = "World of Tanks Blitz",
    ["wow"] = "World of Warcraft",
    ["wow-64"] = "World of Warcraft",
    ["wowt-64"] = "World of Warcraft Public Test",
    ["wreckfest"] = "Next Car Game: Wreckfest",
    ["wreckfest_x64"] = "Wreckfest",
    ["wulverblade"] = "Wulverblade",
    ["wuthering waves"] = "Wuthering Waves",
    ["ww2"] = "World War II Online",
    ["wwe2k18_x64"] = "WWE 2K18",
    ["wz2100"] = "Warzone 2100",
    ["x-plane-32bit"] = "X-Plane",
    ["x2"] = "Elsword",
    ["xcom2"] = "XCOM 2",
    ["xcomew"] = "XCOM: Enemy Unknown",
    ["xcomew.exe"] = "XCOM Enemy Within",
    ["xcomgame"] = "XCOM: Enemy Unknown",
    ["xdefiant"] = "XDefiant",
    ["xenonracer"] = "Xenon Racer",
    ["xenonracer-win64-shipping"] = "Xenon Racer",
    ["xgamefinal"] = "Halo Wars: Definitive Edition",
    ["xr_3da"] = "S.T.A.L.K.E.R.: Shadow of Chernobyl",
    ["xrebirth"] = "X Rebirth",
    ["xrengine"] = "S.T.A.L.K.E.R.: Clear Sky",
    ["xvid-1.3.2-20110601"] = "Helldorado",
    ["yakuza0"] = "Yakuza 0",
    ["yetanotherzombiedefense"] = "Yet Another Zombie Defense",
    ["ygopro_vs"] = "YGOPRO",
    ["ylands"] = "Ylands",
    ["yo_cm_client"] = "Life is Feudal: Your Own",
    ["youtuberslife"] = "Youtubers Life",
    ["yugioh"] = "Yu-Gi-Oh! Legacy of the Duelist",
    ["zandronum"] = "Zandronum",
    ["zenlesszonezero"] = "Zenless Zone Zero",
    ["zenoclash"] = "Zeno Clash",
    ["zombi"] = "Zombi",
    ["zombidle"] = "Zombidle: REMONSTERED",
    ["zps"] = "Zombie Panic! Source",
    ["蒼の彼方のフォーリズム"] = "Ao no Kanata no Four Rhythm",

}

-- ============================================================================
-- GAME NAME MAPPINGS (Quick exact matches - highest priority after custom)
-- ============================================================================

local GAME_NAMES = {
    -- Popular competitive games
    ["cs2"] = "Counter-Strike 2",
    ["csgo"] = "Counter-Strike GO",
    ["dota2"] = "Dota 2",
    ["r5apex"] = "Apex Legends",
    ["valorant-win64-shipping"] = "Valorant",
    ["fortnite"] = "Fortnite",
    ["fortnitelient-win64-shipping"] = "Fortnite",
    ["overwatch"] = "Overwatch 2",

    -- Rockstar Games
    ["gta5"] = "Grand Theft Auto V",
    ["gtav"] = "Grand Theft Auto V",
    ["rdr2"] = "Red Dead Redemption 2",

    -- Survival games
    ["shootergame"] = "ARK Survival Evolved",
    ["shootergame_be"] = "ARK Survival Evolved",
    ["arkascended"] = "ARK Survival Ascended",
    ["rustclient"] = "Rust",

    -- Minecraft (Java edition)
    ["javaw"] = "Minecraft",
    ["java"] = "Minecraft",

    -- War Thunder
    ["aces"] = "War Thunder",

    -- Final Fantasy XIV
    ["ffxiv_dx11"] = "Final Fantasy XIV",
    ["ffxiv"] = "Final Fantasy XIV",

    -- World of Tanks / Warships
    ["worldoftanks"] = "World of Tanks",
    ["wotlauncher"] = "World of Tanks",
    ["worldofwarships"] = "World of Warships",
    ["wowslauncher"] = "World of Warships",

    -- From Software games
    ["sekiro"] = "Sekiro",
    ["eldenring"] = "Elden Ring",
    ["darksoulsiii"] = "Dark Souls III",
    ["armoredcore6"] = "Armored Core VI",

    -- Resident Evil
    ["re2"] = "Resident Evil 2",
    ["re3"] = "Resident Evil 3",
    ["re4"] = "Resident Evil 4",
    ["re8"] = "Resident Evil Village",

    -- Monster Hunter
    ["monsterhunterworld"] = "Monster Hunter World",
    ["monsterhunterrise"] = "Monster Hunter Rise",

    -- Path of Exile
    ["pathofexile"] = "Path of Exile",
    ["pathofexile_x64"] = "Path of Exile",
    ["pathofexilesteam"] = "Path of Exile",
    ["pathofexile_x64steam"] = "Path of Exile",

    -- MMOs
    ["lostark"] = "Lost Ark",
    ["newworld"] = "New World",
    ["warframe"] = "Warframe",
    ["warframe.x64"] = "Warframe",
    ["guildwars2-64"] = "Guild Wars 2",
    ["wow"] = "World of Warcraft",
    ["wow-64"] = "World of Warcraft",

    -- Battle Royale
    ["tslgame"] = "PUBG",
    ["pubg"] = "PUBG",

    -- Blizzard games
    ["diablo iv"] = "Diablo IV",
    ["diablo iii"] = "Diablo III",
    ["hearthstone"] = "Hearthstone",
    ["starcraft2"] = "StarCraft II",

    -- EA games
    ["fifa23"] = "FIFA 23",
    ["fifa24"] = "FC 24",
    ["deadspace"] = "Dead Space",
    ["needforspeed"] = "Need for Speed",

    -- Ubisoft games
    ["acvalhalla"] = "Assassin's Creed Valhalla",
    ["acmirage"] = "Assassin's Creed Mirage",
    ["r6-siege"] = "Rainbow Six Siege",
    ["thedivision2"] = "The Division 2",

    -- Indie favorites
    ["hollowknight"] = "Hollow Knight",
    ["celeste"] = "Celeste",
    ["hades"] = "Hades",
    ["hadesii"] = "Hades II",
    ["deadcells"] = "Dead Cells",
    ["noita"] = "Noita",
    ["cuphead"] = "Cuphead",

    -- Horror
    ["phasmophobia"] = "Phasmophobia",
    ["lethalcompany"] = "Lethal Company",
    ["contentwarning"] = "Content Warning",

    -- Strategy
    ["eu4"] = "Europa Universalis IV",
    ["hoi4"] = "Hearts of Iron IV",
    ["ck3"] = "Crusader Kings III",
    ["stellaris"] = "Stellaris",
    ["civ6"] = "Civilization VI",
    ["totalwar"] = "Total War",

    -- Riot Games
    ["valorant"] = "Valorant",

    -- Embark Studios
    ["discovery"] = "THE FINALS",
    ["discovery-d"] = "THE FINALS",
    ["discovery-e"] = "THE FINALS",
    ["pioneergame"] = "ARC Raiders",
}

-- ============================================================================
-- GAME PATTERNS (Keyword matching - used when exact match fails)
-- ============================================================================

local GAME_PATTERNS = {
    -- Popular games (process name keywords)
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
    {"ets2", "Euro Truck Simulator 2"},
    {"rocketleague", "Rocket League"},
    {"rustclient", "Rust"},
    {"pubg", "PUBG"},
    {"tslgame", "PUBG"},
    {"rainbowsix", "Rainbow Six Siege"},
    {"siege", "Rainbow Six Siege"},
    {"destiny2", "Destiny 2"},
    {"destiny", "Destiny 2"},
    {"cyberpunk", "Cyberpunk 2077"},
    {"witcher", "The Witcher 3"},
    {"genshin", "Genshin Impact"},
    {"honkai", "Honkai Star Rail"},
    {"starrail", "Honkai Star Rail"},
    {"eldenring", "Elden Ring"},
    {"darksouls", "Dark Souls"},
    {"stardew", "Stardew Valley"},
    {"terraria", "Terraria"},
    {"amongus", "Among Us"},
    {"among us", "Among Us"},
    {"deadbydaylight", "Dead by Daylight"},
    {"dbd", "Dead by Daylight"},
    {"hoi4", "Hearts of Iron IV"},
    {"factorio", "Factorio"},
    {"baldur", "Baldur's Gate 3"},
    {"bg3", "Baldur's Gate 3"},
    {"palworld", "Palworld"},
    {"phasmophobia", "Phasmophobia"},
    {"left4dead", "Left 4 Dead 2"},
    {"l4d", "Left 4 Dead 2"},
    {"teamfortress", "Team Fortress 2"},
    {"tf2", "Team Fortress 2"},
    {"helldivers", "Helldivers 2"},
    {"starfield", "Starfield"},
    {"skyrim", "The Elder Scrolls V Skyrim"},
    {"fallout", "Fallout"},
    {"diablo", "Diablo"},
    {"wow", "World of Warcraft"},
    {"warcraft", "World of Warcraft"},
    {"apex", "Apex Legends"},

    -- War Thunder / World of Tanks
    {"warthunder", "War Thunder"},
    {"gaijin", "War Thunder"},
    {"worldoftanks", "World of Tanks"},
    {"wot", "World of Tanks"},

    -- Final Fantasy
    {"finalfantasy", "Final Fantasy"},
    {"ffxiv", "Final Fantasy XIV"},
    {"ff14", "Final Fantasy XIV"},
    {"ffxvi", "Final Fantasy XVI"},

    -- Additional popular games
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
    {"lethal", "Lethal Company"},
    {"content warning", "Content Warning"},

    -- Games with anti-cheat (detected via window title)
    {"sea of thieves", "Sea of Thieves"},
    {"seaofthieves", "Sea of Thieves"},
    {"7 days", "7 Days to Die"},
    {"unturned", "Unturned"},
    {"dayz", "DayZ"},
    {"tarkov", "Escape from Tarkov"},
    {"hunt showdown", "Hunt Showdown"},
    {"dead by daylight", "Dead by Daylight"},

    -- Racing
    {"forza", "Forza"},
    {"assetto", "Assetto Corsa"},
    {"iracing", "iRacing"},
    {"beamng", "BeamNG.drive"},

    -- Sports
    {"fifa", "FIFA"},
    {"nba2k", "NBA 2K"},
    {"madden", "Madden NFL"},

    -- Simulation
    {"msfs", "Microsoft Flight Simulator"},
    {"flightsimulator", "Microsoft Flight Simulator"},
    {"farming", "Farming Simulator"},
    {"citieskylines", "Cities Skylines"},
    {"cities skylines", "Cities Skylines"},
    {"planet coaster", "Planet Coaster"},
    {"planetcoaster", "Planet Coaster"},
}

-- ============================================================================
-- IGNORE LIST (Programs to skip when detecting games)
-- Extended in v2.7.0 with ~40 new entries
-- ============================================================================

local IGNORE_LIST = {
    -- ═══════════════════════════════════════════════════════════════
    -- SYSTEM & WINDOWS
    -- ═══════════════════════════════════════════════════════════════
    "explorer", "searchapp", "taskmgr", "lockapp", "applicationframehost",
    "shellexperiencehost", "systemsettings", "textinputhost", "dwm",
    "nvcplui", "startmenuexperiencehost", "runtimebroker", "sihost",
    "ctfmon", "dllhost", "conhost", "smartscreen", "securityhealthsystray",

    -- Windows 11 / Xbox
    "widgets", "windowsterminal", "wt", "gamebarui", "gamebar",
    "xbox", "xboxapp", "gamingservices", "xboxgamepass", "gamepass",
    "xboxgamebar", "gamingservicesnet", "xboxpcapp",

    -- ═══════════════════════════════════════════════════════════════
    -- OBS & STREAMING
    -- ═══════════════════════════════════════════════════════════════
    "obs64", "obs32", "obs", "streamlabs", "streamlabsobs",
    "xsplit", "xsplitbroadcaster", "xsplitgamecaster",

    -- ═══════════════════════════════════════════════════════════════
    -- COMMUNICATION
    -- ═══════════════════════════════════════════════════════════════
    "discord", "discordptb", "discordcanary", "discordupdate",
    "telegram", "skype", "teams", "slack", "zoom", "viber",
    "whatsapp", "signal", "guilded", "element", "mumble",
    "teamspeak", "teamspeak3", "ts3client_win64", "ventrilo",
    "vencord", "betterdiscord", "vesktop", "webcord",

    -- ═══════════════════════════════════════════════════════════════
    -- BROWSERS
    -- ═══════════════════════════════════════════════════════════════
    "chrome", "firefox", "opera", "msedge", "brave", "vivaldi", "safari",
    "iexplore", "chromium", "waterfox", "librewolf", "floorp", "arc",
    "thorium", "ungoogled", "yandex", "maxthon",

    -- ═══════════════════════════════════════════════════════════════
    -- MEDIA PLAYERS
    -- ═══════════════════════════════════════════════════════════════
    "spotify", "vlc", "wmplayer", "groove", "itunes", "foobar2000",
    "musicbee", "winamp", "deezer", "tidal", "amazonmusic", "mpv",
    "aimp", "qmmp", "potplayer", "mpc-hc", "mpc-be", "mediamonkey",

    -- ═══════════════════════════════════════════════════════════════
    -- GAME LAUNCHERS - MAJOR (v2.7.0 Extended)
    -- ═══════════════════════════════════════════════════════════════

    -- Steam
    "steam", "steamwebhelper", "steamservice", "steamerrorreporter",
    "steamclient", "steampresence",

    -- Epic Games
    "epicgameslauncher", "epicwebhelper", "epiconlineservices",
    "eosoverlayrenderer", "eosoverlay",

    -- EA / Origin
    "origin", "eadesktop", "eaapp", "eabackgroundservice",
    "originwebhelperservice", "igoproxy",

    -- GOG Galaxy
    "gog", "gogalaxy", "galaxyclient", "galaxycommunication",
    "gogalaxynotifications",

    -- Battle.net / Blizzard
    "battle.net", "blizzard", "bnet", "agent", "blizzard error reporter",

    -- Riot Games
    "riotclient", "riotclientservices", "riot client", "riotclientux",
    "riotclientcrashhandler", "vanguard",

    -- ═══════════════════════════════════════════════════════════════
    -- GAME LAUNCHERS - PUBLISHER SPECIFIC (v2.7.0 New)
    -- ═══════════════════════════════════════════════════════════════

    -- Ubisoft Connect (NEW)
    "ubisoftconnect", "upc", "ubisoftgamelauncher", "uplay",
    "ubisoft game launcher", "ubiconnect", "ubisoft connect",

    -- Rockstar Games (NEW)
    "rockstarlauncher", "rgsclauncher", "gtavlauncher",
    "playgtaiv", "playrdr", "rockstar games launcher",
    "socialclub", "socialclubhelper",

    -- Paradox (NEW)
    "paradoxlauncher", "paradox launcher", "bootstrapper",

    -- Nexon (NEW)
    "nexonlauncher", "nexon_client", "nexon_runtime",

    -- 2K Games (NEW)
    "launcherpatcher", "2klauncher",

    -- Pearl Abyss (NEW)
    "blackdesertlauncher", "pearlabyss",

    -- Bethesda
    "bethesda", "bethesdanetlauncher",

    -- Amazon Games
    "amazongames", "primegaming", "amazongameslauncher",

    -- ═══════════════════════════════════════════════════════════════
    -- GAME LAUNCHERS - INDIE / OTHER (v2.7.0 New)
    -- ═══════════════════════════════════════════════════════════════

    -- itch.io (NEW)
    "itch", "itchio", "butler",

    -- IndieGala (NEW)
    "igclient", "indiegalaclient",

    -- Misc launchers (NEW)
    "legacygames", "humblegames", "glyph", "glyphclient",
    "vkplay", "hoyo", "hoyoplay", "wargaming", "gamecenterlauncher",

    -- Playnite
    "playnite", "playnite.fullscreenapp", "playnite.desktopapp",

    -- Twitch
    "twitch", "twitchsetup",

    -- ═══════════════════════════════════════════════════════════════
    -- EDITING SOFTWARE
    -- ═══════════════════════════════════════════════════════════════
    "photoshop", "lightroom", "gimp", "paint", "mspaint", "paint3d",
    "premiere", "aftereffects", "davinci", "resolve", "vegas",
    "audacity", "audition", "capcut", "kdenlive", "shotcut",
    "clipstudio", "krita", "inkscape", "blender",

    -- ═══════════════════════════════════════════════════════════════
    -- OVERLAYS & HARDWARE UTILITIES (v2.7.0 Extended)
    -- ═══════════════════════════════════════════════════════════════

    -- NVIDIA
    "nvidia share", "geforce", "shadowplay", "geforceexperience",
    "nvcontainer", "nvspcaps", "nvdisplay.container",

    -- AMD
    "amd", "radeon", "adrenalin", "radeonsoftware", "amddow",

    -- Intel
    "igcc", "oneapp.igcc",

    -- Overlays
    "overwolf", "medal", "playstv", "raptr",

    -- Hardware utilities
    "corsair", "icue", "razer", "synapse", "logitech", "lghub",
    "steelseries", "gg", "steelseriesengine",
    "msiafterburner", "afterburner", "rivatuner", "rtss",
    "nzxt", "nzxtcam", "hwinfo", "hwinfo64", "cpuz", "gpuz",
    "fpsmonitor", "fraps",

    -- ═══════════════════════════════════════════════════════════════
    -- MOD MANAGERS (v2.7.0 New)
    -- ═══════════════════════════════════════════════════════════════
    "vortex", "modorganizer", "modorganizer2", "nexusmods",
    "r2modman", "thunderstore", "curseforge", "overwolfcurseforge",

    -- ═══════════════════════════════════════════════════════════════
    -- DESKTOP CUSTOMIZATION
    -- ═══════════════════════════════════════════════════════════════
    "ui32", "wallpaper32", "wallpaper64", "wallpaperengine",
    "rainmeter", "fences", "objectdock",

    -- ═══════════════════════════════════════════════════════════════
    -- AUDIO UTILITIES
    -- ═══════════════════════════════════════════════════════════════
    "eartrumpet", "voicemeeter", "voicemeeterpotato", "voicemeeterbanana",
    "equalizer apo", "soundpad", "voicemod",

    -- ═══════════════════════════════════════════════════════════════
    -- AUTOMATION TOOLS
    -- ═══════════════════════════════════════════════════════════════
    "gt auto clicker", "autoclicker", "autohotkey",
    "autohotkey64", "autohotkey32",

    -- ═══════════════════════════════════════════════════════════════
    -- SYSTEM UTILITIES
    -- ═══════════════════════════════════════════════════════════════
    "powertoys", "everything", "wox", "listary", "keypirinha",
    "quicklook", "files",

    -- ═══════════════════════════════════════════════════════════════
    -- TORRENT CLIENTS
    -- ═══════════════════════════════════════════════════════════════
    "qbittorrent", "utorrent", "bittorrent", "deluge", "transmission",
    "tixati", "vuze",

    -- ═══════════════════════════════════════════════════════════════
    -- VPN & NETWORK
    -- ═══════════════════════════════════════════════════════════════
    "rvrvpngui", "cloudflare warp", "nordvpn", "expressvpn",
    "protonvpn", "mullvad", "wireguard", "openvpn",

    -- ═══════════════════════════════════════════════════════════════
    -- RECORDING & SCREENSHOTS
    -- ═══════════════════════════════════════════════════════════════
    "sharex", "lightshot", "greenshot", "bandicam", "fraps",
    "action", "screentogif", "snipaste", "snagit", "camtasia",

    -- ═══════════════════════════════════════════════════════════════
    -- REMOTE DESKTOP (v2.7.0 Extended)
    -- ═══════════════════════════════════════════════════════════════
    "anydesk", "teamviewer", "parsec", "moonlight", "sunshine",
    "nomachine", "chrome remote desktop", "rustdesk",

    -- ═══════════════════════════════════════════════════════════════
    -- DEVELOPMENT
    -- ═══════════════════════════════════════════════════════════════
    "code", "vscode", "sublime", "notepad", "notepad++", "atom",
    "visual studio", "devenv", "idea", "idea64", "pycharm", "webstorm",
    "rider", "datagrip", "phpstorm", "goland", "clion", "rubymine",
    "cursor", "zed", "fleet",

    -- ═══════════════════════════════════════════════════════════════
    -- UTILITIES & MISC
    -- ═══════════════════════════════════════════════════════════════
    "7zfm", "winrar", "filezilla", "putty", "terminal", "powershell",
    "cmd", "conhost", "windowsterminal", "wezterm", "alacritty",

    -- Cloud storage
    "dropbox", "onedrive", "icloud", "googledrive", "megasync",

    -- Google apps
    "google", "googlecrashhandler", "googledrivesync", "backup",

    -- Misc
    "processhacker", "procexp", "procexp64",
}

-- Build hash set for O(1) exact process name matching
-- (IGNORE_LIST array is kept for window title substring matching in get_game_folder)
local IGNORE_SET = {}
for _, v in ipairs(IGNORE_LIST) do IGNORE_SET[v] = true end


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
    if not text or not keywords then return false end
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
-- Both process_name and window_title can be nil - we check whatever is available
-- PRIORITY: Custom names ALWAYS override everything else!
local function get_custom_name(process_name, window_title)
    local lower = nil
    local lower_no_ext = nil

    -- Prepare process name for matching (if available)
    if process_name and process_name ~= "" then
        lower = string.lower(process_name)
        -- Remove .exe if present for exact matching
        lower_no_ext = string.gsub(lower, "%.[eE][xX][eE]$", "")

        -- 1. Try exact match first (fast, highest priority) - only if process name available
        if CUSTOM_NAMES_EXACT[lower_no_ext] then
            return CUSTOM_NAMES_EXACT[lower_no_ext]
        end
        -- Also try with .exe extension in case user entered it that way
        if CUSTOM_NAMES_EXACT[lower] then
            return CUSTOM_NAMES_EXACT[lower]
        end
    end

    -- 2. Try contains matching (checks both process name AND window title)
    -- This works even when process_name is nil (anti-cheat blocked it)
    for _, entry in ipairs(CUSTOM_NAMES_CONTAINS) do
        -- Check process name if available
        if lower and matches_contains(process_name, entry.pattern) then
            return entry.name
        end
        -- Check window title (IMPORTANT: works even when process is nil!)
        if window_title and matches_contains(window_title, entry.pattern) then
            return entry.name
        end
    end

    -- 3. Try keywords matching (check against original name with spaces/version info)
    for _, entry in ipairs(CUSTOM_NAMES_KEYWORDS) do
        -- Check process name if available
        if lower and matches_keywords(process_name, entry.keywords) then
            return entry.name
        end
        -- Check window title (IMPORTANT: works even when process is nil!)
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
local last_screenshot_time = 0
local last_screenshot_notify_time = 0
local cache_raw_game = nil
local cache_folder_name = nil
local last_detection_time = 0
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
local notification_hinstance = nil      -- Module instance
local notification_bg_brush = nil       -- Persistent background brush
local notification_font = nil           -- Text font

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
    typedef unsigned short* LPWSTR;
    typedef unsigned short wchar_t;
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
    BOOL QueryFullProcessImageNameA(HANDLE hProcess, DWORD dwFlags, char* lpExeName, DWORD* lpdwSize);

    int MultiByteToWideChar(unsigned int CodePage, DWORD dwFlags, LPCSTR lpMultiByteStr, int cbMultiByte, LPWSTR lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
    BOOL DeleteFileW(LPCWSTR lpFileName);
    BOOL IsWindow(HWND hWnd);

    // Toolhelp32 Snapshot
    typedef struct tagPROCESSENTRY32 {
        DWORD dwSize;
        DWORD cntUsage;
        DWORD th32ProcessID;
        UINT_PTR th32DefaultHeapID;
        DWORD th32ModuleID;
        DWORD cntThreads;
        DWORD th32ParentProcessID;
        LONG  pcPriClassBase;
        DWORD dwFlags;
        char szExeFile[260];
    } PROCESSENTRY32;

    HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
    BOOL Process32First(HANDLE hSnapshot, void* lppe);
    BOOL Process32Next(HANDLE hSnapshot, void* lppe);

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
    unsigned int WinExec(LPCSTR lpCmdLine, unsigned int uCmdShow);

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
    int DrawTextW(HDC hdc, LPCWSTR lpchText, int cchText, RECT* lprc, UINT format);
    HBRUSH CreateSolidBrush(COLORREF color);
    int FillRect(HDC hDC, const RECT* lprc, HBRUSH hbr);
    BOOL GetClientRect(HWND hWnd, RECT* lpRect);

    // Sound function
    BOOL PlaySoundA(LPCSTR pszSound, HINSTANCE hmod, DWORD fdwSound);

    // Shell function for fullscreen detection
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
local PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
local PROCESS_VM_READ = 0x0010
local TH32CS_SNAPPROCESS = 0x00000002
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
local SND_FILENAME = 0x00020000
local SND_NODEFAULT = 0x0002

-- Fullscreen detection constants
local QUNS_RUNNING_D3D_FULL_SCREEN = 3

-- Window message constants
local WM_PAINT = 0x000F
local WM_ERASEBKGND = 0x0014
local WM_DESTROY = 0x0002
local CS_HREDRAW = 0x0002
local CS_VREDRAW = 0x0001

-- Colors (BGR format for Windows)
local COLOR_BG = 0x00252525
local COLOR_TEXT = 0x00FFFFFF
local COLOR_ACCENT = 0x0000D4AA

-- UTF-8 to UTF-16 conversion for Unicode support
local MAX_WIDE_BUFFER = 4096

local function utf8_to_wide(str)
    if not str or str == "" then return nil end
    if not kernel32 then return nil end

    if #str > MAX_WIDE_BUFFER * 4 then
        str = string.sub(str, 1, MAX_WIDE_BUFFER * 4)
    end

    local ok, result = pcall(function()
        local size = kernel32.MultiByteToWideChar(CP_UTF8, 0, str, -1, nil, 0)
        if size == 0 or size > MAX_WIDE_BUFFER then return nil end
        local buf = ffi.new("unsigned short[?]", size)
        kernel32.MultiByteToWideChar(CP_UTF8, 0, str, -1, buf, size)
        return buf
    end)

    return ok and result or nil
end

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

-- Notification window dimensions and identity
local NOTIFICATION_WIDTH = 300
local NOTIFICATION_HEIGHT = 70
local NOTIFICATION_MARGIN = 20
local NOTIFICATION_WINDOW_TITLE = "SmartReplayMoverNotification"

-- Animation settings
local FADE_STEP = 25
local FADE_MAX_ALPHA = 230
local FADE_INTERVAL = 20

-- Notification state
local notification_end_time = 0
local notification_title = ""
local notification_message = ""
local notification_alpha = 0
local notification_fade_state = "none"
local notification_window_shown = false

-- Custom window class
local NOTIFICATION_CLASS_NAME = "SmartReplayNotificationClass"
local notification_wndproc = nil
local notification_class_atom = nil

-- Update checker state
local update_status_msg = "v" .. VERSION
local GITHUB_VERSION_FILE = os.getenv("TEMP") .. "\\smart_replay_mover_update.txt"

local notification_destroying = false

-- Startup update check state (auto-check on load)
local startup_update_status = "📦 v" .. VERSION
local startup_update_check_done = false

local notification_timer_should_stop = false

-- GDI Objects for rendering
local notification_bg_brush = nil       -- Global background brush
local cached_title_font = nil           -- Cached font for title
local cached_msg_font = nil             -- Cached font for message
local last_font_scale = 100             -- Track scale changes to rebuild fonts

-- Check if app is in exclusive fullscreen mode
local function is_exclusive_fullscreen()
    if shell32 == nil then return false end

    local ok, result = pcall(function()
        local state = ffi.new("int[1]")
        local hr = shell32.SHQueryUserNotificationState(state)
        if hr == 0 then
            return state[0] == QUNS_RUNNING_D3D_FULL_SCREEN
        end
        return false
    end)

    return ok and result or false
end

-- Find and destroy any orphaned notification windows
local function destroy_orphaned_notifications()
    pcall(function()
        -- Only target OUR specific window class to avoid instability
        for i = 1, 10 do
            local orphan = user32.FindWindowA(NOTIFICATION_CLASS_NAME, nil)
            if orphan == nil or orphan == ffi.cast("HWND", 0) then
                break
            end
            
            -- If it's NOT our current handle, kill it
            if orphan ~= notification_hwnd then
                user32.ShowWindow(orphan, SW_HIDE)
                user32.DestroyWindow(orphan)
                dbg("Destroyed orphaned notification window")
            else
                break
            end
        end
    end)
end

-- Hide current notification (immediate)
local function hide_notification()
    if notification_destroying then return end

    local hwnd = notification_hwnd
    if hwnd == nil then return end

    notification_destroying = true

    notification_fade_state = "none"
    notification_alpha = 0
    notification_window_shown = false

    pcall(function()
        if user32.IsWindow(hwnd) then
            user32.ShowWindow(hwnd, SW_HIDE)
            -- NOTE: We no longer DestroyWindow here to allow reuse
        end
    end)

    notification_destroying = false
    dbg("Notification hidden (kept for reuse)")
end

-- Ensure fonts are created (cached)
local function ensure_fonts()
    -- Rebuild fonts if scale changed
    if last_font_scale ~= CONFIG.notification_scale then
        if cached_title_font then gdi32.DeleteObject(cached_title_font); cached_title_font = nil end
        if cached_msg_font then gdi32.DeleteObject(cached_msg_font); cached_msg_font = nil end
        last_font_scale = CONFIG.notification_scale
    end

    local scale_factor = CONFIG.notification_scale / 100.0

    if cached_title_font == nil then
        cached_title_font = gdi32.CreateFontA(
            math.floor(-15 * scale_factor), 0, 0, 0, FW_BOLD, 0, 0, 0,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY, DEFAULT_PITCH, "Segoe UI"
        )
    end
    if cached_msg_font == nil then
        cached_msg_font = gdi32.CreateFontA(
            math.floor(-13 * scale_factor), 0, 0, 0, 400, 0, 0, 0,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY, DEFAULT_PITCH, "Segoe UI"
        )
    end
end

-- Draw notification content to HDC
local function draw_notification_to_hdc(hdc, hwnd)
    if hdc == nil or hwnd == nil then return end

    local rect = ffi.new("RECT")
    user32.GetClientRect(hwnd, rect)

    local bg_brush = gdi32.CreateSolidBrush(COLOR_BG)
    if bg_brush ~= nil then
        user32.FillRect(hdc, rect, bg_brush)
        gdi32.DeleteObject(bg_brush)
    end

    local accent_brush = gdi32.CreateSolidBrush(COLOR_ACCENT)
    if accent_brush ~= nil then
        local accent_rect = ffi.new("RECT", {0, 0, 4, rect.bottom})
        user32.FillRect(hdc, accent_rect, accent_brush)
        gdi32.DeleteObject(accent_brush)
    end

    local scale_factor = CONFIG.notification_scale / 100.0

    ensure_fonts()
    if cached_title_font == nil then return end

    local old_font = gdi32.SelectObject(hdc, cached_title_font)
    gdi32.SetBkMode(hdc, TRANSPARENT)
    gdi32.SetTextColor(hdc, COLOR_TEXT)

    local safe_title = notification_title or "Notification"
    if safe_title == "" then safe_title = "Notification" end

    -- Scale drawing coordinates
    local title_x = math.floor(12 * scale_factor)
    local title_y = math.floor(10 * scale_factor)
    local title_h = math.floor(30 * scale_factor)
    
    -- DT_CENTER (1) + DT_VCENTER (4) + DT_SINGLELINE (32) = 37
    local text_flags = 37 
    
    local title_rect = ffi.new("RECT", {title_x, title_y, rect.right - math.floor(10 * scale_factor), title_y + title_h})
    local title_wide = utf8_to_wide(safe_title)
    if title_wide then
        user32.DrawTextW(hdc, title_wide, -1, title_rect, text_flags)
    else
        user32.DrawTextA(hdc, safe_title, -1, title_rect, text_flags)
    end

    if cached_msg_font ~= nil then
        gdi32.SelectObject(hdc, cached_msg_font)
        gdi32.SetTextColor(hdc, 0x00BBBBBB)

        local safe_message = notification_message or ""

        local msg_y = math.floor(34 * scale_factor)
        local msg_rect = ffi.new("RECT", {math.floor(12 * scale_factor), msg_y, rect.right - math.floor(10 * scale_factor), rect.bottom - math.floor(8 * scale_factor)})
        local msg_wide = utf8_to_wide(safe_message)
        if msg_wide then
            user32.DrawTextW(hdc, msg_wide, -1, msg_rect, text_flags)
        elseif safe_message ~= "" then
            user32.DrawTextA(hdc, safe_message, -1, msg_rect, text_flags)
        end
    end

    if old_font ~= nil then
        gdi32.SelectObject(hdc, old_font)
    end
end

-- Draw notification content (wrapper)
local function draw_notification_content()
    if notification_hwnd == nil then return end

    -- Enhanced safety: ensure we check if window still exists
    if not user32.IsWindow(notification_hwnd) then
        notification_hwnd = nil
        return
    end

    local hdc = user32.GetDC(notification_hwnd)
    if hdc ~= nil then
        -- CRITICAL SAFETY: Ensure ReleaseDC is ALWAYS called even if drawing fails
        -- to prevent GDI resource leaks.
        pcall(draw_notification_to_hdc, hdc, notification_hwnd)
        user32.ReleaseDC(notification_hwnd, hdc)
    end
end


-- Register custom notification window class
local function register_notification_class()
    if notification_class_atom ~= nil then
        return true
    end

    local ok, result = pcall(function()
        if notification_hinstance == nil then
            notification_hinstance = kernel32.GetModuleHandleA(nil)
        end

        pcall(function()
            user32.UnregisterClassA(NOTIFICATION_CLASS_NAME, notification_hinstance)
        end)

        -- CRASH FIX: Do not use a Lua callback for the Window Procedure.
        -- We pass the Windows Default function directly. This prevents the
        -- re-entrancy crash in lua51.dll.
        notification_wndproc = user32.DefWindowProcA

        if notification_bg_brush == nil then
            notification_bg_brush = gdi32.CreateSolidBrush(COLOR_BG)
        end

        local wc = ffi.new("WNDCLASSEXA")
        wc.cbSize = ffi.sizeof("WNDCLASSEXA")
        wc.style = CS_HREDRAW + CS_VREDRAW
        wc.lpfnWndProc = notification_wndproc -- Points to C function, not Lua
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = notification_hinstance
        wc.hIcon = nil
        wc.hCursor = nil
        wc.hbrBackground = notification_bg_brush
        wc.lpszMenuName = nil
        wc.lpszClassName = NOTIFICATION_CLASS_NAME
        wc.hIconSm = nil

        notification_class_atom = user32.RegisterClassExA(wc)

        if notification_class_atom == 0 then
            dbg("Failed to register notification class")
            if notification_bg_brush ~= nil then
                gdi32.DeleteObject(notification_bg_brush)
                notification_bg_brush = nil
            end
            return false
        end

        dbg("Registered custom notification class")
        return true
    end)

    return ok and result or false
end

-- Unregister custom notification window class
local function unregister_notification_class()
    if notification_wndproc ~= nil then
        notification_wndproc = nil
    end

    if notification_class_atom ~= nil then
        pcall(function()
            user32.UnregisterClassA(NOTIFICATION_CLASS_NAME, notification_hinstance)
        end)
        notification_class_atom = nil
    end

    if notification_bg_brush ~= nil then
        gdi32.DeleteObject(notification_bg_brush)
        notification_bg_brush = nil
    end

    dbg("Unregistered notification class")
end

-- Animation timer callback
local function notification_timer_callback()
    if notification_timer_should_stop then
        notification_timer_should_stop = false
        obs.timer_remove(notification_timer_callback)
        return
    end

    if notification_destroying then
        return
    end

    local ok, err = pcall(function()
        if notification_hwnd == nil or notification_destroying then
            notification_timer_should_stop = true
            notification_fade_state = "none"
            return
        end

        local need_redraw = false

        if notification_fade_state == "in" then
            notification_alpha = notification_alpha + FADE_STEP
            if notification_alpha >= FADE_MAX_ALPHA then
                notification_alpha = FADE_MAX_ALPHA
                notification_fade_state = "visible"
                -- Only redraw once when fully visible
                need_redraw = true
            else
                -- Redraw while fading in to update alpha
                need_redraw = true
            end

            user32.SetLayeredWindowAttributes(notification_hwnd, 0, notification_alpha, LWA_ALPHA)

            if not notification_window_shown then
                user32.ShowWindow(notification_hwnd, SW_SHOWNOACTIVATE)
                notification_window_shown = true
            end

        elseif notification_fade_state == "visible" then
            if os.time() >= notification_end_time then
                notification_fade_state = "out"
            end
            -- Efficiency: No redraw needed while static

        elseif notification_fade_state == "out" then
            notification_alpha = notification_alpha - FADE_STEP
            if notification_alpha <= 0 then
                notification_alpha = 0
                hide_notification()
                notification_timer_should_stop = true
                dbg("Notification fade-out complete")
                return
            end
            user32.SetLayeredWindowAttributes(notification_hwnd, 0, notification_alpha, LWA_ALPHA)
            -- Efficiency: Windows handles alpha transparency on its own,
            -- we don't need to re-render the bitmap itself.
            need_redraw = false
        end

        -- CRASH FIX: Manually draw content from the timer thread
        -- This is safe because it is sequential, not interrupt-driven
        if need_redraw and notification_hwnd ~= nil then
            draw_notification_content()
        end
    end)

    if not ok then
        dbg("Timer callback error: " .. tostring(err))
        hide_notification()
        notification_timer_should_stop = true
    end
end

-- Calculate notification position based on user setting
local function get_notification_position(scale_factor)
    local scaled_width = math.floor(NOTIFICATION_WIDTH * scale_factor)
    local scaled_height = math.floor(NOTIFICATION_HEIGHT * scale_factor)
    local scaled_margin = math.floor(NOTIFICATION_MARGIN * scale_factor)

    local screen_width = user32.GetSystemMetrics(SM_CXSCREEN)
    local screen_height = user32.GetSystemMetrics(SM_CYSCREEN)

    local pos = CONFIG.notification_position or "top_right"
    local x, y

    if pos == "top_left" then
        x = scaled_margin
        y = scaled_margin
    elseif pos == "bottom_right" then
        x = screen_width - scaled_width - scaled_margin
        y = screen_height - scaled_height - scaled_margin
    elseif pos == "bottom_left" then
        x = scaled_margin
        y = screen_height - scaled_height - scaled_margin
    else -- top_right (default)
        x = screen_width - scaled_width - scaled_margin
        y = scaled_margin
    end

    return x, y, scaled_width, scaled_height
end

-- Show notification popup
local function show_notification(title, message)
    if not CONFIG.show_notifications then return end

    if is_exclusive_fullscreen() then
        dbg("Exclusive fullscreen detected - skipping popup")
        return
    end

    -- STABILITY FIX: Instead of always destroying the window, we reuse it.
    -- This avoids the risky DestroyWindow/CreateWindow cycle during stress periods.
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

        if not register_notification_class() then
            dbg("Failed to register notification class, cannot show popup")
            return
        end

        -- Check if window still exists and is valid
        local needs_create = true
        if notification_hwnd ~= nil then
            if user32.IsWindow(notification_hwnd) then
                needs_create = false
            else
                notification_hwnd = nil -- Invalid handle
            end
        end

        if needs_create then
            destroy_orphaned_notifications()

            local scale_factor = CONFIG.notification_scale / 100.0
            local x, y, scaled_width, scaled_height = get_notification_position(scale_factor)

            local ex_style = WS_EX_TOPMOST + WS_EX_TOOLWINDOW + WS_EX_NOACTIVATE + WS_EX_LAYERED + WS_EX_TRANSPARENT

            notification_hwnd = user32.CreateWindowExA(
                ex_style,
                NOTIFICATION_CLASS_NAME,
                NOTIFICATION_WINDOW_TITLE,
                WS_POPUP,
                x, y,
                scaled_width, scaled_height,
                nil, nil,
                notification_hinstance,
                nil
            )

            if notification_hwnd == nil then
                dbg("CreateWindowExA failed")
                return
            end
            dbg("New notification window created (Reuse initialized) at scale " .. CONFIG.notification_scale .. "%")
        else
            -- If scale changes but window is reused, we might need to recreate it. 
            -- But for now, we assume users won't change scale mid-session often. 
            -- To be safe, we could destroy and recreate if size differs, but reuse is prioritized for stability.
            -- If needed, user can reload script to force resize.
            dbg("Reusing existing notification window")
            
            -- Optional: Position update if resolution changed or scale changed
            local scale_factor = CONFIG.notification_scale / 100.0
            local x, y, scaled_width, scaled_height = get_notification_position(scale_factor)
            
            user32.SetWindowPos(notification_hwnd, nil, x, y, scaled_width, scaled_height, 0x0010 + 0x0004) -- SWP_NOACTIVATE + SWP_NOZORDER
        end

        user32.SetLayeredWindowAttributes(notification_hwnd, 0, 0, LWA_ALPHA)

        -- Initial manual draw to set the new content
        draw_notification_content()

        -- Restart/Update timer
        obs.timer_remove(notification_timer_callback)
        obs.timer_add(notification_timer_callback, FADE_INTERVAL)

        dbg("Notification triggered: " .. title .. " | " .. message)
    end)

    if not ok then
        dbg("Failed to show notification: " .. tostring(err))
    end
end

-- Play notification sound
local function play_notification_sound()
    if not CONFIG.play_sound then return end
    if winmm == nil then return end

    pcall(function()
        if SCRIPT_DIR and SCRIPT_DIR ~= "" then
            local sound_file = "notification_sound.wav"
            if CONFIG.use_quiet_sound then
                sound_file = "notification_sound_silent.wav"
            end
            
            local full_path = SCRIPT_DIR .. sound_file
            local result = winmm.PlaySoundA(full_path, nil, SND_FILENAME + SND_ASYNC + SND_NODEFAULT)
            if result ~= 0 then
                dbg("Playing custom sound: " .. sound_file)
                return
            end
        end

        winmm.PlaySoundA("SystemNotification", nil, SND_ALIAS + SND_ASYNC)
        dbg("Playing system notification sound")
    end)
end

-- ============================================================================
-- THREAD-SAFE NOTIFICATION QUEUE
-- ============================================================================
-- PROBLEM: notify() is called from multiple threads:
--   - Hotkey callbacks  → OBS hotkey thread
--   - on_event()        → OBS UI/main thread
--   - Timer callbacks   → OBS graphics thread
-- Win32 windows MUST be created and manipulated from the SAME thread.
-- Cross-thread Win32 operations cause undefined behavior (hangs/deadlocks).
--
-- SOLUTION: notify() just pushes a message into a Lua table (queue).
-- process_notification_queue() is the ONLY function that calls show_notification()
-- and play_notification_sound(). It runs exclusively on the graphics thread via
-- a dedicated obs.timer_add, ensuring all GDI/Win32 calls are on one thread.
-- ============================================================================

local notification_queue = {}

-- Thread-safe: safe to call from hotkey thread, UI thread, or graphics thread.
-- Does NO Win32/GDI work — only inserts into a Lua table.
local function notify(title, message)
    table.insert(notification_queue, { title = title, message = message })
end

-- Runs on the graphics thread every 50ms via obs.timer_add in script_load.
-- This is the SOLE consumer of notification_queue.
local function process_notification_queue()
    if #notification_queue == 0 then return end

    local notif = table.remove(notification_queue, 1)

    -- Optimization for fast systems (NVMe/SSD):
    -- If "Saving..." is immediately followed by another notification (e.g. "Clip Saved"),
    -- skip the intermediate "Saving..." and show the final result right away.
    if notif.title == "Saving..." and #notification_queue > 0 then
        notif = table.remove(notification_queue, 1)
    end

    play_notification_sound()
    show_notification(notif.title, notif.message)
end

-- Cleanup notification resources
local function cleanup_notifications()
    notification_timer_should_stop = true
    obs.timer_remove(notification_timer_callback)

    hide_notification()

    if cached_title_font ~= nil then
        gdi32.DeleteObject(cached_title_font)
        cached_title_font = nil
    end
    if cached_msg_font ~= nil then
        gdi32.DeleteObject(cached_msg_font)
        cached_msg_font = nil
    end

    destroy_orphaned_notifications()

    unregister_notification_class()

    notification_hinstance = nil
    notification_destroying = false
    notification_timer_should_stop = false
    notification_fade_state = "none"
    notification_alpha = 0
    notification_window_shown = false
    notification_end_time = 0
    notification_title = ""
    notification_message = ""
    notification_hwnd = nil  -- Explicitly reset handle
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if handle is invalid (INVALID_HANDLE_VALUE = -1)
local function is_invalid_handle(handle)
    if handle == nil then return true end
    local handle_val = tonumber(ffi.cast("intptr_t", handle))
    return handle_val == -1 or handle_val == 0
end

local function clean_filename(str)
    if not str or str == "" then return "Unknown" end
    str = string.gsub(str, '[<>:"/\\|?*]', "")
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    if str == "" then return "Unknown" end
    return str
end

local function clean_folder_path(str)
    if not str or str == "" then return "Unknown" end
    -- Allow / and \ for nested folders, but sanitize specific chars
    str = string.gsub(str, '[<>:"|?*]', "")
    -- Remove directory traversal attempts
    str = string.gsub(str, "%.%.", "")
    -- Normalize slashes
    str = string.gsub(str, "\\", "/")
    -- Clean whitespace
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    if str == "" then return "Unknown" end
    return str
end

-- Recursive directory creation
local function recursive_mkdir(path)
    path = string.gsub(path, "\\", "/")
    local current = ""
    for part in string.gmatch(path, "[^/]+") do
        if current ~= "" then current = current .. "/" end
        current = current .. part
        obs.os_mkdir(current)
    end
    return obs.os_file_exists(path)
end

-- Truncate filename to fit within MAX_PATH limit
local function truncate_filename(filename, max_len)
    if not filename or #filename <= max_len then
        return filename
    end

    local name, ext = string.match(filename, "^(.+)(%.%w+)$")
    if not name then
        name = filename
        ext = ""
    end

    local keep_len = max_len - 3 - #ext
    if keep_len < 10 then
        keep_len = 10
    end

    return string.sub(name, 1, keep_len) .. "..." .. ext
end

-- Validate path length
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
    -- Exact match via hash set (O(1)) — no false positives
    -- e.g. "obs" won't match "observer", "code" won't match "barcode"
    return IGNORE_SET[lower] == true
end

-- ============================================================================
-- GET GAME FOLDER (Main detection logic with priorities)
-- ============================================================================

local function get_game_folder(raw_name, window_title, skip_window_fallback)
    -- ═══════════════════════════════════════════════════════════════
    -- PRIORITY 1: Custom names (ABSOLUTE - user-defined ALWAYS wins!)
    -- This is the HIGHEST priority - users can override ANY detection
    -- ═══════════════════════════════════════════════════════════════
    local custom = get_custom_name(raw_name, window_title)
    if custom then
        dbg("CUSTOM NAME OVERRIDE: " .. tostring(raw_name) .. " / " .. tostring(window_title) .. " -> " .. custom)
        return custom
    end

    -- If process name available, try to match it
    if raw_name and raw_name ~= "" then
        local lower = string.lower(raw_name)

        -- ═══════════════════════════════════════════════════════════════
        -- PRIORITY 2: GAME_NAMES (quick exact matches)
        -- ═══════════════════════════════════════════════════════════════
        if GAME_NAMES[lower] then
            dbg("GAME_NAMES match: " .. lower .. " -> " .. GAME_NAMES[lower])
            return GAME_NAMES[lower]
        end

        -- ═══════════════════════════════════════════════════════════════
        -- PRIORITY 3: GAME_DATABASE (1876 games embedded)
        -- Direct access - no lazy loading needed anymore
        -- ═══════════════════════════════════════════════════════════════
        if GAME_DATABASE and GAME_DATABASE[lower] then
            dbg("GAME_DATABASE match: " .. lower .. " -> " .. GAME_DATABASE[lower])
            return GAME_DATABASE[lower]
        end

        -- ═══════════════════════════════════════════════════════════════
        -- PRIORITY 4: GAME_PATTERNS (keyword matching)
        -- ═══════════════════════════════════════════════════════════════
        for _, pattern in ipairs(GAME_PATTERNS) do
            if string.find(lower, pattern[1], 1, true) then
                dbg("GAME_PATTERNS match: " .. lower .. " -> " .. pattern[2])
                return pattern[2]
            end
        end

        -- Use raw name if no pattern match (clean it for folder name)
        return clean_filename(raw_name)
    end

    -- If skip_window_fallback is true, process was ignored (Explorer, Discord, etc.)
    -- Go straight to fallback
    if skip_window_fallback then
        dbg("Process was ignored, skipping window title fallback")
        return CONFIG.fallback_folder
    end

    -- ═══════════════════════════════════════════════════════════════
    -- FALLBACK: Process name unavailable (anti-cheat blocked it)
    -- Try to detect game from window title - BUT ONLY known games!
    -- ═══════════════════════════════════════════════════════════════
    if window_title and window_title ~= "" then
        dbg("Process unavailable, checking window title: " .. window_title)
        local lower_title = string.lower(window_title)

        -- SAFETY CHECK: Skip if window title looks like a file explorer
        if string.find(lower_title, ":\\", 1, true) or
           string.find(lower_title, ":/", 1, true) or
           string.find(lower_title, "file explorer", 1, true) or
           string.find(lower_title, "explorer", 1, true) then
            dbg("Window title looks like file explorer, using fallback")
            return CONFIG.fallback_folder
        end

        -- Check if window title contains any ignored program name
        for _, ignored in ipairs(IGNORE_LIST) do
            if string.find(lower_title, ignored, 1, true) then
                dbg("Window title contains ignored program: " .. ignored)
                return CONFIG.fallback_folder
            end
        end

        -- Check patterns against window title
        for _, pattern in ipairs(GAME_PATTERNS) do
            if string.find(lower_title, pattern[1], 1, true) then
                dbg("Window title matched GAME_PATTERNS: " .. pattern[2])
                return pattern[2]
            end
        end

        -- Check exact game names
        for process, folder in pairs(GAME_NAMES) do
            if string.find(lower_title, process, 1, true) then
                dbg("Window title matched GAME_NAMES: " .. folder)
                return folder
            end
        end

        -- Check database by window title (slower but comprehensive)
        if GAME_DATABASE then
            for process, folder in pairs(GAME_DATABASE) do
                if string.find(lower_title, process, 1, true) then
                    dbg("Window title matched GAME_DATABASE: " .. folder)
                    return folder
                end
            end
        end

        dbg("Window title didn't match any known game, using fallback")
    end

    -- Final fallback
    local result = CONFIG.fallback_folder
    if not result or result == "" then
        result = "Desktop"
    end
    return result
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

        -- Validate PID before proceeding
        if pid[0] == 0 then return nil end

        local process = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION + PROCESS_VM_READ, 0, pid[0])
        if is_invalid_handle(process) then return nil end

        -- Use nested pcall for GetModuleBaseNameA - some anti-cheat systems
        -- (Marvel Rivals, Valorant, etc.) can cause crashes here
        local buffer = ffi.new("char[260]")
        local get_ok, len = pcall(function()
            return psapi.GetModuleBaseNameA(process, nil, buffer, 260)
        end)
        
        -- Safe close for first attempt
        kernel32.CloseHandle(process)

        if get_ok and len and len > 0 then
            -- Safely extract string with explicit length limit
            if len > 259 then len = 259 end
            local name = ffi.string(buffer, len)
            return string.gsub(name, "%.[eE][xX][eE]$", "")
        end
        
        -- FALLBACK: Try QueryFullProcessImageNameA with PROCESS_QUERY_LIMITED_INFORMATION
        -- This is needed for games with stricter anti-cheat (ARC Raiders, THE FINALS, etc.)
        -- that block PROCESS_VM_READ
        
        local process_fallback = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid[0])
        if is_invalid_handle(process_fallback) then return nil end
        
        local fallback_ok, fallback_result = pcall(function()
            local size = ffi.new("DWORD[1]", 260)
            local res = kernel32.QueryFullProcessImageNameA(process_fallback, 0, buffer, size)
            if res ~= 0 and size[0] > 0 then
                local full_path = ffi.string(buffer, size[0])
                -- Extract filename from full path
                local name = string.match(full_path, "([^/\\]+)$") or full_path
                return string.gsub(name, "%.[eE][xX][eE]$", "")
            end
            return nil
        end)
        
        kernel32.CloseHandle(process_fallback)
        
        return fallback_ok and fallback_result or nil
    end)

    return ok and result or nil
end

-- Helper to convert UTF-16 (wide string) to UTF-8
local MAX_UTF8_BUFFER = 8192

local function wide_to_utf8(wide_buffer, wide_len)
    if wide_len <= 0 or wide_len > MAX_WIDE_BUFFER then return nil end

    local ok, result = pcall(function()
        local size_needed = kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_buffer, wide_len, nil, 0, nil, nil)
        if size_needed <= 0 or size_needed > MAX_UTF8_BUFFER then return nil end

        local utf8_buffer = ffi.new("char[?]", size_needed + 1)
        local conv_result = kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_buffer, wide_len, utf8_buffer, size_needed, nil, nil)

        if conv_result > 0 then
            return ffi.string(utf8_buffer, conv_result)
        end
        return nil
    end)

    return ok and result or nil
end

local function get_window_title()
    local ok, result = pcall(function()
        local hwnd = user32.GetForegroundWindow()
        if not hwnd then return nil end

        local wide_buffer = ffi.new("unsigned short[512]")

        local get_ok, len = pcall(function()
            return user32.GetWindowTextW(hwnd, wide_buffer, 512)
        end)

        if not get_ok or not len or len <= 0 then
            return nil
        end

        if len > 500 then len = 500 end

        return wide_to_utf8(wide_buffer, len)
    end)

    return ok and result or nil
end

local function find_game_in_obs()
    local ok, result = pcall(function()
        local sources = obs.obs_enum_sources()
        if not sources then
            dbg("find_game_in_obs: No sources found")
            return nil
        end

        local found = nil

        for _, source in ipairs(sources) do
            local id = obs.obs_source_get_id(source)
            local name = obs.obs_source_get_name(source)

            if id == "game_capture" then
                local settings = obs.obs_source_get_settings(source)
                if settings then
                    local window = obs.obs_data_get_string(settings, "window")
                    local mode = obs.obs_data_get_string(settings, "capture_mode")
                    obs.obs_data_release(settings)

                    dbg("Game Capture '" .. (name or "?") .. "': mode=" .. (mode or "nil") .. ", window=" .. (window or "nil"))

                    if window and window ~= "" then
                        local exe = string.match(window, "([^:]+)$")
                        if exe then
                            found = string.gsub(exe, "%.[eE][xX][eE]$", "")
                            dbg("Found game from window field: " .. found)
                            break
                        end
                    end

                    if not found then
                        local proc_handler = obs.obs_source_get_proc_handler(source)
                        if proc_handler then
                            local cd = obs.calldata_create()
                            if cd then
                                local call_ok = pcall(function()
                                    if obs.proc_handler_call(proc_handler, "get_hooked", cd) then
                                        local hooked = obs.calldata_string(cd, "hooked_exe")
                                        if hooked and hooked ~= "" then
                                            found = string.gsub(hooked, "%.[eE][xX][eE]$", "")
                                            dbg("Found game from hooked process: " .. found)
                                        end
                                    end
                                end)
                                obs.calldata_destroy(cd)
                            end
                        end
                    end
                end
            end
        end

        obs.source_list_release(sources)

        if not found then
            dbg("find_game_in_obs: No game found in any Game Capture source")
        end

        return found
    end)

    return ok and result or nil
end

local function get_background_game()
    local ok, result = pcall(function()
        local snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        if is_invalid_handle(snapshot) then return nil end

        local pe32 = ffi.new("PROCESSENTRY32")
        pe32.dwSize = ffi.sizeof("PROCESSENTRY32")

        if kernel32.Process32First(snapshot, pe32) == 0 then
            kernel32.CloseHandle(snapshot)
            return nil
        end

        repeat
            local exe_file = ffi.string(pe32.szExeFile)
            local name = string.gsub(exe_file, "%.[eE][xX][eE]$", ""):lower()
            
            if not is_ignored(name) and GAME_DATABASE and GAME_DATABASE[name] then
                dbg("Background game found via process snapshot: " .. name)
                kernel32.CloseHandle(snapshot)
                return name
            end
        until kernel32.Process32Next(snapshot, pe32) == 0

        kernel32.CloseHandle(snapshot)
        return nil
    end)
    if not ok then dbg("get_background_game ERROR: " .. tostring(result)) end
    return ok and result or nil
end

-- Detect active game
-- Returns: process_or_game_name, window_title, skip_window_fallback
local function detect_game()
    local process = get_active_process()
    local title = get_window_title()
    local window_title_for_matching = title
    local active_ignored = false

    -- 1. Check if active process is in ignore list
    if process and is_ignored(process) then
        dbg("Active process ignored: " .. process)
        active_ignored = true
    end

    -- 2. Try active window process
    if process and not active_ignored then
        dbg("Detected from active process: " .. process)
        if title then
            dbg("Window title available: " .. title)
        end
        return process, window_title_for_matching, false
    end

    -- 3. Try OBS game capture source
    local obs_game = find_game_in_obs()
    if obs_game and not is_ignored(obs_game) then
        dbg("Detected from OBS Game Capture: " .. obs_game)
        return obs_game, window_title_for_matching, false
    end

    -- 4. Try background process scan (Fallback)
    if CONFIG.scan_all_processes then
        local bg_game = get_background_game()
        if bg_game then
            dbg("Detected from running process scan (fallback): " .. bg_game)
            return bg_game, window_title_for_matching, false
        end
    end

    -- 5. Nothing detected. Determine if we should skip window title fallback.
    if active_ignored then
        dbg("No game detected, skipping window title fallback (active process was ignored)")
        return nil, window_title_for_matching, true
    end

    dbg("No game detected, will try window title fallback")
    return nil, window_title_for_matching, false
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
    if obs.os_file_exists(path) then
        return true
    end

    recursive_mkdir(path)

    return obs.os_file_exists(path)
end

-- Get file size
local function get_file_size(path)
    local ok, result = pcall(function()
        path = string.gsub(path, "/", "\\")
        local data = ffi.new("WIN32_FIND_DATAA")
        local handle = kernel32.FindFirstFileA(path, data)

        if not is_invalid_handle(handle) then
            kernel32.FindClose(handle)
            local size = data.nFileSizeHigh * 4294967296 + data.nFileSizeLow
            return size
        end
        return 0
    end)
    return ok and result or 0
end

-- ============================================================================
-- FFMPEG SUPPORT (FFI / Sync ShellExecuteEx Method)
-- ============================================================================

-- NOTE: HANDLE, HWND, HINSTANCE, DWORD, BOOL, UINT are already declared in the
-- WINDOWS API section above. Only new struct/function declarations go here.
ffi.cdef[[
    typedef struct {
        DWORD cbSize;
        DWORD fMask;
        HWND hwnd;
        const char* lpVerb;
        const char* lpFile;
        const char* lpParameters;
        const char* lpDirectory;
        int nShow;
        HINSTANCE hInstApp;
        void* lpIDList;
        const char* lpClass;
        HANDLE hkeyClass;
        DWORD dwHotKey;
        union {
            HANDLE hIcon;
            HANDLE hMonitor;
        } DUMMYUNIONNAME;
        HANDLE hProcess;
    } SHELLEXECUTEINFOA;

    int ShellExecuteExA(SHELLEXECUTEINFOA* pExecInfo);
    DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
]]

local shell32 = ffi.load("shell32")
local kernel32 = ffi.load("kernel32")

-- Constants
local SEE_MASK_NOCLOSEPROCESS = 0x00000040
local SW_HIDE = 0
local INFINITE = 0xFFFFFFFF

local function is_video_file(path)
    if not path then return false end
    local ext = string.lower(string.match(path, "%.([^.]+)$") or "")
    local video_exts = {
        ["mp4"] = true, ["mkv"] = true, ["mov"] = true, ["flv"] = true,
        ["ts"] = true, ["m3u8"] = true, ["avi"] = true, ["webm"] = true
    }
    return video_exts[ext] or false
end

local function run_task_sync_hidden(commands, unique_id)
    local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
    local bat_path = temp_dir .. "\\srm_sync_" .. unique_id .. ".bat"

    local f_bat = io.open(bat_path, "w")
    if not f_bat then
        log("ERROR: Could not create temp batch file")
        return false
    end
    
    f_bat:write("@echo off\n")
    -- chcp 65001 is critical for non-English filenames
    f_bat:write("chcp 65001 > nul\n")
    
    for _, cmd in ipairs(commands) do
        f_bat:write(cmd .. "\n")
        f_bat:write("if %errorlevel% neq 0 exit /b %errorlevel%\n")
    end
    f_bat:close()

    -- Prepare ShellExecuteEx structure
    local sei = ffi.new("SHELLEXECUTEINFOA")
    sei.cbSize = ffi.sizeof("SHELLEXECUTEINFOA")
    sei.fMask = SEE_MASK_NOCLOSEPROCESS -- We need the process handle to wait
    sei.hwnd = nil
    sei.lpVerb = "open"
    sei.lpFile = "cmd.exe"
    sei.lpParameters = "/c \"" .. bat_path .. "\""
    sei.lpDirectory = nil
    sei.nShow = SW_HIDE
    sei.hInstApp = nil

    -- Execute
    if shell32.ShellExecuteExA(sei) ~= 0 then
        -- Wait for finish (Blocking)
        if sei.hProcess ~= nil then
            -- SAFETY: INFINITE wait required for large video files (embedding can take minutes)
            -- WARNING: This will block OBS UI during the operation! 
            -- This is expected behavior for a synchronous operation to ensure file integrity.
            kernel32.WaitForSingleObject(sei.hProcess, 0xFFFFFFFF)
            kernel32.CloseHandle(sei.hProcess)
        end
        
        -- Cleanup
        os.remove(bat_path)
        return true
    else
        log("ERROR: ShellExecuteEx failed")
        os.remove(bat_path)
        return false
    end
end

local function run_ffmpeg_thumbnail(ffmpeg_path, src, target, offset)
    if not ffmpeg_path or ffmpeg_path == "" then return false end

    -- Path correction
    local lower_path = string.lower(ffmpeg_path)
    if not string.match(lower_path, "%.exe$") then
        local try_bin = ffmpeg_path .. "/ffmpeg.exe"
        local try_bin_sub = ffmpeg_path .. "/bin/ffmpeg.exe"
        if obs.os_file_exists(try_bin) then ffmpeg_path = try_bin
        elseif obs.os_file_exists(try_bin_sub) then ffmpeg_path = try_bin_sub end
    end

    math.randomseed(os.time() + (os.clock() * 1000))
    local unique_id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    local temp_thumb = src .. "." .. unique_id .. ".thumb.jpg"
    
    local commands = {}
    
    table.insert(commands, string.format('"%s" -sseof -%.1f -i "%s" -vframes 1 -q:v 2 -y "%s"',
        ffmpeg_path, offset, src, temp_thumb))
        
    -- Embed and Move
    -- Logic depends on container type:
    -- MKV supports "Attachments" (Best for Cover Art support in Windows/Icaros)
    -- MP4 requires "Video Stream" with Disposition (Apple/Standard style)
    
    local is_mkv = string.match(string.lower(src), "%.mkv$") ~= nil
    local cmd_embed = ""
    
    if is_mkv then
        -- MKV Strategy: Use -attach for true Matroska attachments
        -- -c copy: Copy video/audio streams
        -- -attach: Attach the thumbnail file
        -- -metadata:s:t:0 mimetype: Set MIME type for the FIRST attachment stream explicitly
        -- -metadata:s:t:0 filename: Naming it "cover.jpg" or "cover.png" helps detection
        cmd_embed = string.format('"%s" -i "%s" -map 0 -c copy -attach "%s" -metadata:s:t:0 mimetype=image/jpeg -metadata:s:t:0 filename="cover.jpg" -y "%s"',
            ffmpeg_path, src, temp_thumb, target)
    else
        -- MP4/Other Strategy: Use stream mapping
        cmd_embed = string.format('"%s" -i "%s" -i "%s" -map 0 -map 1 -c:v:0 copy -c:a copy -c:v:1 mjpeg -disposition:v:1 attached_pic -metadata:s:v:1 title="Cover Art" -y "%s"',
            ffmpeg_path, src, temp_thumb, target)
    end
        
    table.insert(commands, cmd_embed)
    
    -- Sync Logic: We manage files in Lua now because we WAIT for completion
    -- No "del" commands in batch needed for result files, only temps
    
    dbg("Processing Thumbnail (Sync): " .. unique_id)
    
    -- Run it!
    run_task_sync_hidden(commands, unique_id)
    
    -- Cleanup temp thumb
    os.remove(temp_thumb)
    
    -- Validation (Now safe because process is guaranteed finished)
    if obs.os_file_exists(target) then
        local src_size = get_file_size(src)
        local target_size = get_file_size(target)
        
        -- If target is valid (not empty and reasonable size)
        if target_size > (src_size * 0.9) then
            return true
        end
    end
    
    return false 
end

local function move_file(src, folder_name, game_name)
    local ok, result = pcall(function()
        src = string.gsub(src, "\\", "/")

        local dir, filename = string.match(src, "^(.*)/(.*)$")
        if not dir or not filename then
            log("ERROR: Cannot parse source path - invalid format: " .. tostring(src))
            return false
        end

        if not obs.os_file_exists(src) then
            log("ERROR: Source file does not exist: " .. src)
            return false
        end

        local file_size = get_file_size(src)
        if file_size == 0 then
            log("WARNING: Source file appears empty or inaccessible: " .. src)
        elseif file_size < 1024 then
            dbg("File is very small (" .. file_size .. " bytes), might be incomplete")
        end

        -- ═══════════════════════════════════════════════════════════════
        -- "NO FOLDER" MODE: folder_name == ".", "/", or "\" means keep in OBS root
        -- File stays in the same directory, only prefix is added (if enabled)
        -- ═══════════════════════════════════════════════════════════════
        if folder_name == "." or folder_name == "/" or folder_name == "\\" then
            dbg("No-folder mode active, keeping file in output root")
            local new_filename = filename
            -- Still add prefix if enabled and game_name is meaningful
            local should_add_prefix = CONFIG.add_game_prefix and game_name and game_name ~= "" and (game_name ~= "." and game_name ~= "/" and game_name ~= "\\") and game_name ~= CONFIG.fallback_folder
            if should_add_prefix then
                local safe_game = clean_filename(game_name)
                new_filename = safe_game .. " - " .. filename
                dbg("No-folder mode: added prefix -> " .. new_filename)
            end
            local target_path = dir .. "/" .. new_filename
            -- If filename didn't change, nothing to do
            if target_path == src then
                log("No-folder mode: file already in place (no prefix): " .. filename)
                files_moved = files_moved + 1
                return true
            end
            if obs.os_rename(src, target_path) then
                log("Renamed (no-folder mode): " .. new_filename)
                files_moved = files_moved + 1
                return true
            end
            log("ERROR: Failed to rename file in no-folder mode")
            return false
        end

        local safe_folder = clean_folder_path(folder_name)
        local real_folder = safe_folder
        
        -- If safe_folder contains separators (nested folder), skip fuzzy existing check
        -- Otherwise (simple folder), try to find existing folder with matching case (e.g. "game" -> "Game")
        if not string.find(safe_folder, "[/\\]") then
            real_folder = get_existing_folder(dir, safe_folder)
        end
        
        local target_dir = dir .. "/" .. real_folder

        if CONFIG.use_date_subfolders then
            target_dir = target_dir .. "/" .. os.date("%Y-%m")
        end

        local new_filename = filename
        local should_add_prefix = CONFIG.add_game_prefix and game_name and game_name ~= "" and game_name ~= CONFIG.fallback_folder

        dbg("Prefix check: add_game_prefix=" .. tostring(CONFIG.add_game_prefix) ..
              ", game_name=" .. tostring(game_name) ..
              ", fallback=" .. tostring(CONFIG.fallback_folder) ..
              ", will_add=" .. tostring(should_add_prefix))

        if should_add_prefix then
            -- For nested paths (e.g., "Singleplayer/DS3"), use only the last segment as prefix
            local prefix_source = game_name
            if string.find(game_name, "[/\\]") then
                prefix_source = string.match(game_name, "([^/\\]+)$") or game_name
                dbg("Nested path detected, using last segment for prefix: " .. prefix_source)
            end
            local safe_game = clean_filename(prefix_source)
            new_filename = safe_game .. " - " .. filename
            dbg("Added prefix: " .. new_filename)
        end

        local target_path = target_dir .. "/" .. new_filename

        local valid, err = validate_path_length(target_path)
        if not valid then
            dbg("Path too long, truncating filename: " .. err)
            local max_filename_len = MAX_PATH - #target_dir - 2
            if max_filename_len < 20 then
                log("ERROR: Directory path too long, cannot fit filename: " .. target_dir)
                return false
            end
            new_filename = truncate_filename(new_filename, max_filename_len)
            target_path = target_dir .. "/" .. new_filename
            dbg("Truncated filename to: " .. new_filename)
        end

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

        -- FFMPEG THUMBNAIL LOGIC
        if CONFIG.enable_thumbnails and is_video_file(src) and CONFIG.ffmpeg_path ~= "" then
            log("Attempting to embed thumbnail with FFmpeg...")
            if run_ffmpeg_thumbnail(CONFIG.ffmpeg_path, src, target_path, CONFIG.thumbnail_offset) then
                log("Thumbnail embedded successfully!")
                log("Moved (FFmpeg): " .. new_filename)
                log("To: " .. target_dir)
                
                -- Delete original source file since FFmpeg created a new one
                os.remove(src)
                
                files_moved = files_moved + 1
                return true
            else
                log("FFmpeg failed or produced invalid file. Falling back to standard move.")
                -- Clean up potential failed target file
                if obs.os_file_exists(target_path) then
                    os.remove(target_path)
                end
            end
        end

        -- STANDARD MOVE (Fallback)
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
    end)

    if not ok then
        log("ERROR: Exception in move_file: " .. tostring(result))
        return false
    end
    return result
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

local function get_recording_path()
    local path = obs.obs_frontend_get_last_recording()
    return path
end

local function process_file(path)
    if not path or path == "" then
        log("ERROR: No file path provided")
        return
    end

    local raw_game, window_title, skip_fallback = detect_game()
    local folder_name = get_game_folder(raw_game, window_title, skip_fallback)

    if raw_game then
        log("Game: " .. raw_game .. " -> " .. folder_name)
    else
        log("No game detected, using: " .. folder_name)
    end

    move_file(path, folder_name, folder_name)
end

local function process_file_with_game(path, folder_name, game_name)
    if not path or path == "" then
        log("ERROR: No file path provided")
        return
    end

    if not folder_name then
        process_file(path)
        return
    end

    log("Using cached game: " .. folder_name)
    move_file(path, folder_name, game_name or folder_name)
end

-- ============================================================================
-- RECORDING SIGNAL HANDLERS
-- ============================================================================

local function on_recording_file_changed(calldata)
    if not CONFIG.organize_recordings then
        return
    end

    local prev_file = obs.calldata_string(calldata, "next_file")

    dbg("File split signal received, next_file: " .. tostring(prev_file))

    if recording_folder_name then
        local recording = obs.obs_frontend_get_recording_output()
        if recording then
            obs.obs_output_release(recording)
        end

        log("File split detected - using cached game: " .. recording_folder_name)
    end
end

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

local function connect_recording_signals()
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

    obs.signal_handler_connect(sh, "file_changed", on_recording_file_changed)

    recording_output_ref = recording
    recording_signal_handler = sh

    dbg("Connected to recording file_changed signal")
    return true
end

-- ============================================================================
-- SPLIT FILE TRACKING
-- ============================================================================

local split_files = {}
local current_recording_file = nil

local function check_split_files()
    if not CONFIG.organize_recordings then
        return
    end

    local recording = obs.obs_frontend_get_recording_output()
    if not recording then
        return
    end

    local cd = obs.calldata_create()
    local ph = obs.obs_output_get_proc_handler(recording)

    if ph then
        local success = obs.proc_handler_call(ph, "get_last_file", cd)
        if success then
            local current_file = obs.calldata_string(cd, "path")
            if current_file and current_file ~= "" and current_file ~= current_recording_file then
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

local function delayed_recording_init()
    obs.timer_remove(delayed_recording_init)

    if not CONFIG.organize_recordings then return end

    connect_recording_signals()

    local recording = obs.obs_frontend_get_recording_output()
    if recording then
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

    obs.timer_add(check_split_files, 1000)

    log("Recording initialized (delayed) - monitoring for file splits")

    local game_info = recording_folder_name or CONFIG.fallback_folder
    notify("Recording Started", "Game: " .. game_info)
end


local function start_buffer_delayed()
    obs.timer_remove(start_buffer_delayed)
    obs.obs_frontend_replay_buffer_start()
    dbg("Replay Buffer auto-restarted")
end 

-- Auto-start replay buffer on OBS launch (5s delay for full initialization)
local function auto_start_buffer_on_load()
    obs.timer_remove(auto_start_buffer_on_load)
    local ok, err = pcall(function()
        obs.obs_frontend_replay_buffer_start()
        log("Auto-started Replay Buffer on launch")
        notify("Replay Buffer", "Auto-started on launch")
    end)
    if not ok then
        dbg("Auto-start buffer failed: " .. tostring(err))
    end
end

-- ============================================================================
-- FRONTEND EVENT HANDLER
-- ============================================================================

local function on_event(event)
    local ok, err = pcall(function()
        if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
            local now = os.time()
            local diff = now - last_save_time

            local path = get_replay_path()

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
                local raw_game, window_title, skip_fallback = detect_game()
                local folder_name = get_game_folder(raw_game, window_title, skip_fallback)

                -- Use process_file_with_game to avoid calling detect_game() a second time
                -- inside process_file() which would cause a race if the active window changed
                process_file_with_game(path, folder_name, raw_game)

                notify("Clip Saved", "Moved to: " .. folder_name)
                
                -- Auto-restart buffer logic (Prevent Overlap)
                if CONFIG.restart_buffer_after_save then
                    restarting_buffer_active = true
                    obs.obs_frontend_replay_buffer_stop()
                    dbg("Auto-restart: Buffer stopping...")
                end
            end

        elseif event == obs.OBS_FRONTEND_EVENT_SCREENSHOT_TAKEN then
            if CONFIG.organize_screenshots then
                local now = os.clock()
                local path = obs.obs_frontend_get_last_screenshot()

                if path then
                    local raw_game, folder_name

                    -- Cache detection for 2 seconds to handle bursts
                    if now - last_detection_time < 2.0 and cache_folder_name then
                        raw_game = cache_raw_game
                        folder_name = cache_folder_name
                        dbg("Using detection cache for rapid screenshot burst")
                    else
                        local r, w, s = detect_game()
                        folder_name = get_game_folder(r, w, s)
                        raw_game = r

                        -- Update cache
                        cache_raw_game = r
                        cache_folder_name = folder_name
                        last_detection_time = now
                    end

                    process_file_with_game(path, folder_name, raw_game)

                    -- Throttle notifications (0.5s) to prevent UI overload
                    if now - last_screenshot_notify_time > 0.5 then
                        notify("Screenshot Saved", "Moved to: " .. folder_name)
                        last_screenshot_notify_time = now
                    end

                    last_screenshot_time = now
                end
            end


        elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTING then
            if CONFIG.organize_recordings then
                local raw_game, window_title, skip_fallback = detect_game()
                recording_game_name = raw_game
                recording_folder_name = get_game_folder(raw_game, window_title, skip_fallback)
                current_recording_file = nil

                if raw_game then
                    log("Recording starting - Game detected: " .. raw_game .. " -> " .. recording_folder_name)
                else
                    log("Recording starting - No game detected, using: " .. recording_folder_name)
                end
            end

        elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
            if CONFIG.organize_recordings then
                -- SAFETY: Delay initialization by 0.5s to prevent crash in graphics thread
                -- during high-stress recording startup period
                obs.timer_add(delayed_recording_init, 500)
                log("Recording started - initialization scheduled in 0.5s...")
            end

        elseif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED then
            if restarting_buffer_active then
                restarting_buffer_active = false
                dbg("Auto-restart: Buffer stop confirmed. Restarting in 200ms...")
                obs.timer_add(start_buffer_delayed, 200)
            end
            
        elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
            if CONFIG.organize_recordings then
                obs.timer_remove(delayed_recording_init)
                obs.timer_remove(check_split_files)

                local now = os.time()
                local diff = now - last_recording_time

                local path = get_recording_path()

                if diff < CONFIG.duplicate_cooldown then
                    log("Recording spam detected (" .. string.format("%.1f", diff) .. "s)")
                    if CONFIG.delete_spam_files and path then
                        delete_file(path)
                        log("Duplicate recording deleted")
                    end
                    files_skipped = files_skipped + 1
                else
                    last_recording_time = now

                    local saved_folder = recording_folder_name or CONFIG.fallback_folder

                    if path then
                        log("Recording stopped - organizing file")
                        if recording_folder_name then
                            process_file_with_game(path, recording_folder_name, recording_game_name)
                        else
                            process_file(path)
                        end

                        notify("Recording Saved", "Moved to: " .. saved_folder)
                    end
                end

                disconnect_recording_signals()

                recording_game_name = nil
                recording_folder_name = nil
                current_recording_file = nil
            end
        end
    end)

    if not ok then
        log("ERROR in event handler: " .. tostring(err))
    end
end

-- ============================================================================
-- IMPORT/EXPORT FUNCTIONS
-- ============================================================================

local function add_custom_mapping(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end

    local process = obs.obs_data_get_string(script_settings, "new_process_name")
    local folder = obs.obs_data_get_string(script_settings, "new_folder_name")

    process = string.gsub(process or "", "^%s+", "")
    process = string.gsub(process, "%s+$", "")
    folder = string.gsub(folder or "", "^%s+", "")
    folder = string.gsub(folder, "%s+$", "")

    if process == "" then
        log("ERROR: Please enter a process name (from Task Manager)")
        return false
    end
    if folder == "" then
        log("ERROR: Please enter a folder name")
        return false
    end

    local entry = process .. " > " .. folder

    local array = obs.obs_data_get_array(script_settings, "custom_names")
    if not array then
        array = obs.obs_data_array_create()
    end

    local item = obs.obs_data_create()
    obs.obs_data_set_string(item, "value", entry)
    obs.obs_data_array_push_back(array, item)
    obs.obs_data_release(item)

    obs.obs_data_set_array(script_settings, "custom_names", array)
    obs.obs_data_array_release(array)

    obs.obs_data_set_string(script_settings, "new_process_name", "")
    obs.obs_data_set_string(script_settings, "new_folder_name", "")

    load_custom_names(script_settings)

    log("Added custom mapping: " .. process .. " -> " .. folder)
    return true
end

local function get_default_export_path()
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "C:"
    return home .. "\\smart_replay_custom_names.txt"
end

local function export_custom_names(path)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end

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

    local count = 0
    local write_ok, write_err = pcall(function()
        file:write("# Smart Replay Mover - Custom Names Export\n")
        file:write("# Format: process_name > Folder Name\n")
        file:write("# Lines starting with # are comments\n\n")

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
    end)

    file:close()

    if not write_ok then
        log("ERROR: Failed to write export file: " .. tostring(write_err))
        return false
    end

    if count > 0 then
        log("Exported " .. count .. " custom name(s) to: " .. path)
    else
        log("No custom names to export. File created at: " .. path)
    end
    return true
end

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

    local read_ok, read_err = pcall(function()
        for line in file:lines() do
            local trimmed = string.gsub(line, "^%s+", "")
            trimmed = string.gsub(trimmed, "%s+$", "")

            if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
                local result, name, mode = parse_custom_entry(trimmed)
                if result and name and mode then
                    table.insert(entries, trimmed)
                    count = count + 1
                else
                    log("WARNING: Skipping invalid line: " .. trimmed)
                end
            end
        end
    end)

    file:close()

    if not read_ok then
        log("ERROR: Failed to read import file: " .. tostring(read_err))
        return false
    end

    if count > 0 then
        local array = obs.obs_data_get_array(script_settings, "custom_names")
        if not array then
            array = obs.obs_data_array_create()
        end

        for _, entry in ipairs(entries) do
            local item = obs.obs_data_create()
            obs.obs_data_set_string(item, "value", entry)
            obs.obs_data_array_push_back(array, item)
            obs.obs_data_release(item)
        end

        obs.obs_data_set_array(script_settings, "custom_names", array)
        obs.obs_data_array_release(array)

        load_custom_names(script_settings)
        log("Imported " .. count .. " custom name(s) from: " .. path)
    else
        log("No valid entries found in file")
    end

    return true
end

local function on_export_clicked(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end
    local path = obs.obs_data_get_string(script_settings, "import_export_path")
    export_custom_names(path)
    return false
end

local function on_import_clicked(props, p)
    if not script_settings then
        log("ERROR: Settings not loaded yet")
        return false
    end
    local path = obs.obs_data_get_string(script_settings, "import_export_path")
    if path == "" then
        path = get_default_export_path()
        log("No path specified, using default: " .. path)
    end
    import_custom_names(path, props)
    return true
end

local function on_test_notification_clicked(props, p)
    notify("Test Notification", "This is a test message to check size and sound.")
    return false
end

-- ============================================================================
-- OBS INTERFACE
-- ============================================================================

function script_description()
    return [[
<center>
<p style="font-size:24px; font-weight:bold; color:#00d4aa;">SMART REPLAY MOVER</p>
<p style="color:#888;">Automatic Game Clip Organizer v]] .. VERSION .. [[</p>
</center>

<hr style="border-color:#333;">

<table width="100%">
<tr><td width="50%" valign="top" align="center">
<p style="color:#00d4aa; font-weight:bold;">🎮 AUTO-ORGANIZE</p>
<p style="font-size:11px;">
Detects active game automatically<br>
Creates game-named folders<br>
Replays, recordings & screenshots
</p>
</td><td width="50%" valign="top" align="center">
<p style="color:#ff6b6b; font-weight:bold;">🛡️ SMART & SAFE</p>
<p style="font-size:11px;">
Spam protection with cooldown<br>
Custom game name mappings<br>
Optional date subfolders
</p>
</td></tr>
</table>

<center>
<p style="font-size:11px; color:#666; margin-top:10px;">
Made by <b>SlonickLab</b> • <a href="https://github.com/SlonickLab/Smart-Replay-Mover" style="color:#00d4aa;">GitHub</a>
</p>
</center>
]]
end

-- Helper function to compare semantic versions
-- Returns true if new > old
local function compare_versions(new, old)
    local new_m, new_n, new_p = new:match("(%d+)%.(%d+)%.?(%d*)")
    local old_m, old_n, old_p = old:match("(%d+)%.(%d+)%.?(%d*)")
    new_m, new_n, new_p = tonumber(new_m or 0), tonumber(new_n or 0), tonumber(new_p or 0)
    old_m, old_n, old_p = tonumber(old_m or 0), tonumber(old_n or 0), tonumber(old_p or 0)
    
    if new_m > old_m then return true end
    if new_m < old_m then return false end
    if new_n > old_n then return true end
    if new_n < old_n then return false end
    return new_p > old_p
end

-- Helper function to read configuration from settings
local function read_config(settings)
    script_settings = settings

    CONFIG.add_game_prefix = obs.obs_data_get_bool(settings, "add_game_prefix")
    CONFIG.organize_screenshots = obs.obs_data_get_bool(settings, "organize_screenshots")
    CONFIG.organize_recordings = obs.obs_data_get_bool(settings, "organize_recordings")
    CONFIG.use_date_subfolders = obs.obs_data_get_bool(settings, "use_date_subfolders")
    CONFIG.fallback_folder = obs.obs_data_get_string(settings, "fallback_folder")
    CONFIG.duplicate_cooldown = obs.obs_data_get_double(settings, "duplicate_cooldown")
    CONFIG.delete_spam_files = obs.obs_data_get_bool(settings, "delete_spam_files")
    CONFIG.debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
    CONFIG.show_notifications = obs.obs_data_get_bool(settings, "show_notifications")
    CONFIG.play_sound = obs.obs_data_get_bool(settings, "play_sound")
    CONFIG.notification_scale = math.floor(obs.obs_data_get_double(settings, "notification_scale"))
    CONFIG.use_quiet_sound = obs.obs_data_get_bool(settings, "use_quiet_sound")
    CONFIG.notification_duration = obs.obs_data_get_double(settings, "notification_duration")
    CONFIG.enable_thumbnails = obs.obs_data_get_bool(settings, "enable_thumbnails")
    CONFIG.thumbnail_offset = obs.obs_data_get_double(settings, "thumbnail_offset")
    CONFIG.ffmpeg_path = obs.obs_data_get_string(settings, "ffmpeg_path")
    CONFIG.restart_buffer_after_save = obs.obs_data_get_bool(settings, "restart_buffer_after_save")
    CONFIG.auto_start_buffer = obs.obs_data_get_bool(settings, "auto_start_buffer")
    CONFIG.scan_all_processes = obs.obs_data_get_bool(settings, "scan_all_processes")
    CONFIG.notification_position = obs.obs_data_get_string(settings, "notification_position")

    if CONFIG.fallback_folder == "" then
        CONFIG.fallback_folder = "Desktop"
    end
end

-- Parse result of startup auto-update check
local function parse_startup_update_result()
    obs.timer_remove(parse_startup_update_result)
    
    local file = io.open(GITHUB_VERSION_FILE, "r")
    if not file then
        startup_update_status = "⚠️ Update check failed"
        startup_update_check_done = true
        return
    end
    
    local content = file:read("*a")
    file:close()
    pcall(os.remove, GITHUB_VERSION_FILE)
    
    if not content or not content:match("^-- Smart Replay Mover") then
        startup_update_status = "⚠️ Update check failed"
    else
        local latest_version = content:match("Smart Replay Mover v?(%d+%.%d+%.?[%d]*)")
        if latest_version then
            latest_version = latest_version:gsub("^%s*(.-)%s*$", "%1")
            
            if latest_version == VERSION then
                startup_update_status = "✅ Up to date (v" .. VERSION .. ")"
            elseif compare_versions(latest_version, VERSION) then
                startup_update_status = "🆕 New version available: v" .. latest_version
            else
                startup_update_status = "✅ Dev version (v" .. VERSION .. ")"
            end
        else
            startup_update_status = "⚠️ Parse error"
        end
    end
    
    startup_update_check_done = true
    log("Update Check: " .. startup_update_status)
    
    -- Trigger UI refresh by toggling hidden property
    if script_settings then
        local current = obs.obs_data_get_bool(script_settings, "__startup_refresh")
        obs.obs_data_set_bool(script_settings, "__startup_refresh", not current)
    end
end

local function parse_update_result()
    -- This function is called by a timer after check_for_updates initiates a download.
    -- It reads the downloaded file from the temp directory.

    local file, err = io.open(GITHUB_VERSION_FILE, "r")
    if not file then
        -- This can happen if the download failed completely or was blocked,
        -- resulting in no output file.
        update_status_msg = "❌ Check failed: No response"
        obs.timer_remove(parse_update_result)
        dbg("Update file not found: " .. tostring(err))
        if script_settings then obs.obs_data_set_string(script_settings, "check_updates_status", update_status_msg) end
        return
    end

    local content = nil
    local read_ok, read_err = pcall(function()
        content = file:read("*a")
        file:close()
    end)
    
    if not read_ok then
        update_status_msg = "❌ Check failed: Read error"
        obs.timer_remove(parse_update_result)
        dbg("Failed to read update file: " .. tostring(read_err))
        return
    end
    
    -- The temporary file should be cleaned up immediately after reading.
    pcall(os.remove, GITHUB_VERSION_FILE)

    -- Robustness check: A valid script file must start with "-- Smart Replay Mover".
    -- This prevents parsing HTML error pages or other invalid data.
    if not content or not content:match("^-- Smart Replay Mover") then
        if content and content:match("404: Not Found") then
            update_status_msg = "❌ Check failed: File Not Found (404)"
        else
            update_status_msg = "❌ Check failed: Invalid response"
        end
    else
        -- Try to find the version number in the downloaded script content.
        local latest_version = content:match("Smart Replay Mover v?(%d+%.%d+%.?[%d]*)")
        if not latest_version then latest_version = content:match("v(%d+%.%d+%.%d+)") end
        
        if latest_version then
            -- (Version check logic follows)
            latest_version = latest_version:gsub("^%s*(.-)%s*$", "%1")
            
            -- Compare the latest version from GitHub with the current script version.
            if latest_version == VERSION then
                update_status_msg = "✅ You are up to date (v" .. VERSION .. ")"
            elseif compare_versions(latest_version, VERSION) then
                update_status_msg = "🎁 New update: v" .. latest_version .. "!"
            else
                -- This case handles when the local version is newer than the one on GitHub,
                -- which can happen during development or testing.
                update_status_msg = "✅ Running test version (v" .. VERSION .. ")"
            end
        else
            -- This happens if the downloaded file is the script but has a malformed version string.
            update_status_msg = "❌ Check failed: Cannot parse version"
        end
    end

    -- Stop the timer and update the status in the UI.
    obs.timer_remove(parse_update_result)
    
    if script_settings then
        obs.obs_data_set_string(script_settings, "check_updates_status", update_status_msg)
    end
    
    log("Update Check Result: " .. update_status_msg)

    -- Toggle the hidden boolean property to trigger the modified callback,
    -- which returns true and forces a UI refresh.
    if script_settings then
        obs.obs_data_set_bool(script_settings, "__ui_refresh_trigger", not obs.obs_data_get_bool(script_settings, "__ui_refresh_trigger"))
    end
end

-- This callback does nothing but return true, which is a signal to OBS
-- to refresh the script properties UI. We trigger this from our async
-- update check to show the final result without requiring a second click.
local update_check_in_progress = false
local button_text = "                  🔄  Check for Updates                  "

-- Callback for refresh button - dynamically updates the status text
local function refresh_update_status(props, p)
    -- Get the update_info property and change its description to current status
    local update_prop = obs.obs_properties_get(props, "update_info")
    if update_prop then
        obs.obs_property_set_description(update_prop, startup_update_status)
    end
    
    -- Show/hide the download button based on whether update is available
    local link_prop = obs.obs_properties_get(props, "open_releases_btn")
    if link_prop then
        obs.obs_property_set_visible(link_prop, startup_update_status:match("🆕") ~= nil)
    end
    
    return true
end

-- Callback for download button - opens releases page in browser (silent, no terminal window)
local function open_releases_url(props, p)
    if kernel32 then
        local cmd = 'powershell -WindowStyle Hidden -Command "Start-Process \'' .. GITHUB_RELEASES_URL .. '\'"'
        kernel32.WinExec(cmd, 0)
    end
    return false
end

local function check_for_updates(props, p)
	if update_check_in_progress then
		-- If a check is running, a second click should just refresh the UI.
		-- This will show the final result from the completed check.
		update_check_in_progress = false
		button_text = "                  🔄  Check for Updates                  "
		return true
	end

	-- Start a new check
	update_check_in_progress = true
	button_text = "           ⏳ Checking... (Click again in 5s)           "
	update_status_msg = "⏳ Connecting to GitHub..." -- Show status immediately

    -- Force UI refresh by toggling a dummy setting
    if script_settings then
        local dummy = obs.obs_data_get_bool(script_settings, "__ui_refresh_trigger")
        obs.obs_data_set_bool(script_settings, "__ui_refresh_trigger", not dummy)
    end

	if kernel32 then
		if obs.os_file_exists(GITHUB_VERSION_FILE) then
			os.remove(GITHUB_VERSION_FILE)
		end
		math.randomseed(os.time())
		local cache_buster = "?t=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
		local url_to_fetch = GITHUB_RAW_URL .. cache_buster
		local cmd = string.format('powershell -Command "Invoke-WebRequest -Uri \'%s\' -OutFile \'%s\'"', url_to_fetch, GITHUB_VERSION_FILE)
		kernel32.WinExec(cmd, 0)
		obs.timer_add(parse_update_result, 4000) -- Increased to 4s
	else
		update_status_msg = "❌ Error: kernel32 missing"
		update_check_in_progress = false
		button_text = "                  🔄  Check for Updates                  "
	end

	return true -- Force UI refresh to show the "Checking..." text on the button
end

function script_properties()
    local props = obs.obs_properties_create()

    -- UPDATE STATUS (FIRST ELEMENT - shown at top of UI)
    obs.obs_properties_add_text(props, "update_info", startup_update_status, obs.OBS_TEXT_INFO)
    
    -- Download button - opens releases page in browser (hidden until update available)
    local download_btn = obs.obs_properties_add_button(props, "open_releases_btn", "📥 Download Update", open_releases_url)
    obs.obs_property_set_visible(download_btn, startup_update_status:match("🆕") ~= nil)
    
    -- Refresh button - clicking updates the status display
    obs.obs_properties_add_button(props, "refresh_status_btn", "🔄 Refresh Status", refresh_update_status)
    obs.obs_properties_add_text(props, "refresh_hint", "Click after ~4 seconds to see update status", obs.OBS_TEXT_INFO)

    -- FILE NAMING GROUP
    local naming_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(naming_group, "add_game_prefix", "✏️  Add game name prefix to filename")
    obs.obs_properties_add_text(naming_group, "fallback_folder", "📂  Fallback folder name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_group(props, "naming_section", "📁  FILE NAMING", obs.OBS_GROUP_NORMAL, naming_group)

    -- CUSTOM NAMES GROUP
    local custom_group = obs.obs_properties_create()
    obs.obs_properties_add_text(custom_group, "custom_names_help", "Custom names have HIGHEST priority! Format: game > Folder | +keywords > Folder | *text* > Folder | game > / or . (no folder)", obs.OBS_TEXT_INFO)
    obs.obs_properties_add_text(custom_group, "new_process_name", "🎯  Game (process, +keywords, or *text*)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(custom_group, "new_folder_name", "📁  Folder name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(custom_group, "add_mapping_btn", "➕  Add", add_custom_mapping)
    obs.obs_properties_add_editable_list(custom_group, "custom_names", "Your mappings", obs.OBS_EDITABLE_LIST_TYPE_STRINGS, nil, nil)
    obs.obs_properties_add_group(props, "custom_section", "🎮  CUSTOM NAMES (Highest Priority)", obs.OBS_GROUP_NORMAL, custom_group)

    -- BACKUP GROUP
    local backup_group = obs.obs_properties_create()
    obs.obs_properties_add_path(backup_group, "import_export_path", "📄  File path (optional)", obs.OBS_PATH_FILE_SAVE, "Text files (*.txt)", nil)
    obs.obs_properties_add_button(backup_group, "import_btn", "📥  Import", on_import_clicked)
    obs.obs_properties_add_button(backup_group, "export_btn", "📤  Export", on_export_clicked)
    obs.obs_properties_add_group(props, "backup_section", "💾  BACKUP", obs.OBS_GROUP_NORMAL, backup_group)

    -- BUFFER CONTROL GROUP
    local buffer_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(buffer_group, "restart_buffer_after_save", "🔄  Auto-restart Replay Buffer after save (Prevent Overlap)")
    obs.obs_properties_add_bool(buffer_group, "auto_start_buffer", "▶️  Auto-start Replay Buffer on OBS launch")
    obs.obs_properties_add_text(buffer_group, "smart_save_help", "💡 Smart Save: Go to OBS Settings → Hotkeys → find 'Smart Save Replay' and assign your key. Shows instant 'Saving...' feedback!", obs.OBS_TEXT_INFO)
    obs.obs_properties_add_group(props, "buffer_section", "🔄  BUFFER CONTROL", obs.OBS_GROUP_NORMAL, buffer_group)

    -- ORGANIZATION GROUP
    local folder_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(folder_group, "use_date_subfolders", "📅  Create monthly subfolders (YYYY-MM)")
    obs.obs_properties_add_bool(folder_group, "organize_screenshots", "📸  Also organize screenshots")
    obs.obs_properties_add_bool(folder_group, "organize_recordings", "🎬  Organize recordings (Start/Stop Recording)")
    obs.obs_properties_add_bool(folder_group, "scan_all_processes", "🔍  Detect game by scanning all running processes")
    obs.obs_properties_add_text(folder_group, "scan_all_processes_help", "Detects background games when focused on Discord or Desktop (acts as a smart fallback).", obs.OBS_TEXT_INFO)
    obs.obs_properties_add_group(props, "folder_section", "🗂️  ORGANIZATION", obs.OBS_GROUP_NORMAL, folder_group)

    -- SPAM PROTECTION GROUP
    local spam_group = obs.obs_properties_create()
    obs.obs_properties_add_float_slider(spam_group, "duplicate_cooldown", "⏱️  Cooldown between saves (seconds)", 0, 30, 0.5)
    obs.obs_properties_add_bool(spam_group, "delete_spam_files", "🗑️  Auto-delete duplicate files")
    obs.obs_properties_add_group(props, "spam_section", "🛡️  SPAM PROTECTION", obs.OBS_GROUP_NORMAL, spam_group)

    -- NOTIFICATIONS GROUP
    local notify_group = obs.obs_properties_create()
    obs.obs_properties_add_text(notify_group, "notify_help", "Visual popup works only in Borderless Windowed games!", obs.OBS_TEXT_INFO)
    obs.obs_properties_add_bool(notify_group, "show_notifications", "🖼️  Show visual popup (Borderless Windowed only)")
    obs.obs_properties_add_bool(notify_group, "play_sound", "🔊  Play notification sound (works in Fullscreen too)")
    
    local p_scale = obs.obs_properties_add_float_slider(notify_group, "notification_scale", "📏  Scale %", 100.0, 300.0, 10.0)
    
    local p_pos = obs.obs_properties_add_list(notify_group, "notification_position", "📍  Position", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(p_pos, "↗ Top Right", "top_right")
    obs.obs_property_list_add_string(p_pos, "↖ Top Left", "top_left")
    obs.obs_property_list_add_string(p_pos, "↘ Bottom Right", "bottom_right")
    obs.obs_property_list_add_string(p_pos, "↙ Bottom Left", "bottom_left")
    
    obs.obs_properties_add_bool(notify_group, "use_quiet_sound", "🔇  Use Quiet Sound (notification_sound_silent.wav)")

    obs.obs_properties_add_float_slider(notify_group, "notification_duration", "⏱️  Popup duration (seconds)", 1.0, 10.0, 0.5)
    
    obs.obs_properties_add_button(notify_group, "test_notification_btn", "🔊  Test Notification", on_test_notification_clicked)
    
    obs.obs_properties_add_group(props, "notify_section", "🔔  NOTIFICATIONS", obs.OBS_GROUP_NORMAL, notify_group)

    -- TOOLS GROUP
    local tools_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(tools_group, "debug_mode", "🐛  Show debug messages in console")
    obs.obs_properties_add_group(props, "tools_section", "🔧  TOOLS & DEBUG", obs.OBS_GROUP_NORMAL, tools_group)

    -- FFMPEG GROUP (Advanced)
    local ffmpeg_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(ffmpeg_group, "enable_thumbnails", "🖼️  Embed Video Dictionary (Thumbnail)")
    obs.obs_properties_add_float_slider(ffmpeg_group, "thumbnail_offset", "⏱️  Thumbnail Offset (seconds from end)", 1.0, 60.0, 1.0)
    obs.obs_properties_add_path(ffmpeg_group, "ffmpeg_path", "📂  FFmpeg Executable Path (ffmpeg.exe)", obs.OBS_PATH_FILE, "Executables (*.exe);;All Files (*.*)", nil)
    obs.obs_properties_add_text(ffmpeg_group, "ffmpeg_info", "Note: Requires FFmpeg installed. Adds processing time regarding disk speed.", obs.OBS_TEXT_INFO)
    obs.obs_properties_add_group(props, "ffmpeg_section", "🎬  FFMPEG THUMBNAILS (Advanced)", obs.OBS_GROUP_NORMAL, ffmpeg_group)

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
    obs.obs_data_set_default_bool(settings, "show_notifications", true)
    obs.obs_data_set_default_bool(settings, "play_sound", false)
    obs.obs_data_set_default_double(settings, "notification_scale", 100.0)
    obs.obs_data_set_default_bool(settings, "use_quiet_sound", false)
    obs.obs_data_set_default_double(settings, "notification_duration", 3.0)
    obs.obs_data_set_default_bool(settings, "enable_thumbnails", false)
    obs.obs_data_set_default_double(settings, "thumbnail_offset", 10.0)
    obs.obs_data_set_default_string(settings, "ffmpeg_path", "")
    obs.obs_data_set_default_bool(settings, "restart_buffer_after_save", false)
    obs.obs_data_set_default_bool(settings, "auto_start_buffer", false)
    obs.obs_data_set_default_bool(settings, "scan_all_processes", false)
    obs.obs_data_set_default_string(settings, "notification_position", "top_right")
end

function script_update(settings)
    read_config(settings)
    
    load_custom_names(settings)

    local exact_count = 0
    for _ in pairs(CUSTOM_NAMES_EXACT) do exact_count = exact_count + 1 end
    local keywords_count = #CUSTOM_NAMES_KEYWORDS
    local contains_count = #CUSTOM_NAMES_CONTAINS
    local total_count = exact_count + keywords_count + contains_count
    if total_count > 0 then
        dbg("Loaded " .. total_count .. " custom name mapping(s) (" .. exact_count .. " exact, " .. keywords_count .. " keywords, " .. contains_count .. " contains)")
    end
end

-- Smart Save Hotkey state
local smart_save_hotkey_id = nil

-- Smart Save Hotkey callback.
-- notify() is now thread-safe (pushes to queue only, no Win32 calls).
-- obs_frontend_replay_buffer_save() is thread-safe (uses OBS signal handler internally).
-- Both can be called directly from the hotkey thread -- no timer deferral needed.
local function smart_save_replay(pressed)
    if not pressed then return end

    local ok, err = pcall(function()
        -- Queue "Saving..." -- displayed by process_notification_queue on the graphics thread.
        -- On fast systems (NVMe), save completes before the 50ms timer fires, so the
        -- optimization in process_notification_queue skips it and shows "Clip Saved" directly.
        notify("Saving...", "Replay buffer saving...")
        dbg("Smart Save: queued instant notification, triggering save")
        obs.obs_frontend_replay_buffer_save()
    end)

    if not ok then
        log("ERROR in Smart Save hotkey: " .. tostring(err))
    end
end

function script_load(settings)
    destroy_orphaned_notifications()

    read_config(settings)

    load_custom_names(settings)

    obs.obs_frontend_add_event_callback(on_event)

    -- Start the notification queue processor on the graphics thread.
    -- This is the ONLY place that calls show_notification() / play_notification_sound().
    -- All notify() calls from any thread are safe because they only push to the queue.
    obs.timer_add(process_notification_queue, 50)

    -- Register Smart Save Replay hotkey
    smart_save_hotkey_id = obs.obs_hotkey_register_frontend(
        "smart_save_replay",
        "Smart Save Replay (Instant Notification)",
        smart_save_replay
    )
    
    -- Load saved hotkey binding
    local hotkey_save_array = obs.obs_data_get_array(settings, "smart_save_replay_hotkey")
    if hotkey_save_array then
        obs.obs_hotkey_load(smart_save_hotkey_id, hotkey_save_array)
        obs.obs_data_array_release(hotkey_save_array)
    end
    dbg("Smart Save Replay hotkey registered")

    local exact_count = 0
    for _ in pairs(CUSTOM_NAMES_EXACT) do exact_count = exact_count + 1 end
    local custom_count = exact_count + #CUSTOM_NAMES_KEYWORDS + #CUSTOM_NAMES_CONTAINS

    -- Count embedded database entries
    local db_count = 0
    if GAME_DATABASE then
        for _ in pairs(GAME_DATABASE) do db_count = db_count + 1 end
    end

    log("Smart Replay Mover v" .. VERSION .. " loaded (GPL v3 - github.com/SlonickLab/Smart-Replay-Mover)")
    log("Database: " .. db_count .. " games | Custom: " .. custom_count .. " mappings")
    log("Prefix: " .. (CONFIG.add_game_prefix and "ON" or "OFF") ..
        " | Recordings: " .. (CONFIG.organize_recordings and "ON" or "OFF") ..
        " | Fallback: " .. CONFIG.fallback_folder)
    
    -- AUTO UPDATE CHECK (runs async, result ready by UI open)
    if kernel32 then
        pcall(function()
            if obs.os_file_exists(GITHUB_VERSION_FILE) then
                os.remove(GITHUB_VERSION_FILE)
            end
            math.randomseed(os.time())
            local cache_buster = "?t=" .. os.time() .. math.random(1000, 9999)
            local cmd = string.format(
                'powershell -Command "Invoke-WebRequest -Uri \'%s%s\' -OutFile \'%s\'"',
                GITHUB_RAW_URL, cache_buster, GITHUB_VERSION_FILE
            )
            kernel32.WinExec(cmd, 0)
            obs.timer_add(parse_startup_update_result, 4000)
            dbg("Auto update check started")
        end)
    else
        startup_update_status = "⚠️ Check unavailable"
        startup_update_check_done = true
    end

    -- AUTO-START REPLAY BUFFER (5s delay for OBS to fully initialize)
    if CONFIG.auto_start_buffer then
        obs.timer_add(auto_start_buffer_on_load, 5000)
        dbg("Auto-start buffer scheduled in 5s")
    end
end

-- Save hotkey binding when settings are saved
function script_save(settings)
    if smart_save_hotkey_id then
        local hotkey_save_array = obs.obs_hotkey_save(smart_save_hotkey_id)
        obs.obs_data_set_array(settings, "smart_save_replay_hotkey", hotkey_save_array)
        obs.obs_data_array_release(hotkey_save_array)
    end
end

function script_unload()
    obs.timer_remove(check_split_files)
    obs.timer_remove(notification_timer_callback)
    obs.timer_remove(process_notification_queue)   -- Stop notification queue processor
    obs.timer_remove(delayed_recording_init)
    obs.timer_remove(parse_startup_update_result)  -- Stop startup update check if still running
    obs.timer_remove(auto_start_buffer_on_load)    -- Cancel auto-start if still pending
    notification_timer_should_stop = true
    notification_queue = {}                        -- Discard any pending notifications

    disconnect_recording_signals()

    pcall(function()
        obs.obs_frontend_remove_event_callback(on_event)
    end)

    cleanup_notifications()

    split_files = {}
    current_recording_file = nil
    recording_game_name = nil
    recording_folder_name = nil

    log("Session: " .. files_moved .. " moved, " .. files_skipped .. " skipped")
end

-- ============================================================================
-- END OF SCRIPT v2.8.1
-- Copyright (C) 2025-2026 SlonickLab - Licensed under GPL v3
-- https://github.com/SlonickLab/Smart-Replay-Mover
-- ============================================================================
