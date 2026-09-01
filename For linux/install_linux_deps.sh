#!/bin/bash
# ============================================================================
# Smart Replay Mover — Linux Dependencies Installer
# ============================================================================
# This script installs all optional dependencies needed for full functionality
# on Linux. Run it once after downloading Smart Replay Mover.
#
# Usage:  chmod +x install_linux_deps.sh && ./install_linux_deps.sh
# ============================================================================


# Removed 'set -e' to handle errors gracefully manually
# set -e 

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🎮 Smart Replay Mover — Linux Setup         ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Detect package manager ──────────────────────────────────────────────────

PKG_MANAGER=""
INSTALL_CMD=""

# Alpine images and containers often ship without sudo, and running as root
# needs no elevation at all.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    elif command -v doas &>/dev/null; then
        SUDO="doas"
    else
        echo -e "${YELLOW}⚠️  Neither sudo nor doas found. Re-run this script as root.${NC}"
        echo ""
    fi
fi

if command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
    INSTALL_CMD="$SUDO apt-get install -y"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="$SUDO dnf install -y"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="$SUDO pacman -S --noconfirm"
elif command -v zypper &>/dev/null; then
    PKG_MANAGER="zypper"
    INSTALL_CMD="$SUDO zypper install -y"
elif command -v apk &>/dev/null; then
    PKG_MANAGER="apk"
    INSTALL_CMD="$SUDO apk add"
else
    echo -e "${RED}❌ Could not detect package manager!${NC}"
    echo "   Please install the following packages manually:"
    echo "   • xprop (usually in xprop, xorg-xprop or x11-utils)"
    echo "   • notify-send (usually in libnotify, libnotify-bin or libnotify-tools)"
    echo "   • paplay (usually in pulseaudio-utils) OR pw-play (pipewire)"
    echo "   • ffmpeg and ffprobe (both come from the ffmpeg package)"
    exit 1
fi

# Package lists are refreshed only when something actually has to be installed.
APT_UPDATED=0
ensure_pkg_lists() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    [ "$APT_UPDATED" -eq 0 ] || return 0
    echo -e "  ${YELLOW}📦 Updating package lists (apt-get update)...${NC}"
    $SUDO apt-get update
    APT_UPDATED=1
}

echo -e "${GREEN}✅ Detected package manager: ${BOLD}${PKG_MANAGER}${NC}"
echo ""

# ── Define packages per distro ──────────────────────────────────────────────

XPROP_PKG=""
NOTIFY_PKG=""
AUDIO_PKG=""

case "$PKG_MANAGER" in
    apt)
        XPROP_PKG="x11-utils"
        NOTIFY_PKG="libnotify-bin"
        AUDIO_PKG="pulseaudio-utils"
        ;;
    dnf)
        XPROP_PKG="xprop"
        NOTIFY_PKG="libnotify"
        AUDIO_PKG="pulseaudio-utils"
        ;;
    pacman)
        XPROP_PKG="xorg-xprop"
        NOTIFY_PKG="libnotify"
        AUDIO_PKG="libpulse"
        ;;
    zypper)
        XPROP_PKG="xprop"
        NOTIFY_PKG="libnotify-tools"
        AUDIO_PKG="pulseaudio-utils"
        ;;
    apk)
        XPROP_PKG="xprop"
        NOTIFY_PKG="libnotify"
        AUDIO_PKG="pulseaudio-utils"
        ;;
esac

# ── Check & install ─────────────────────────────────────────────────────────

INSTALLED=0
SKIPPED=0

install_if_missing() {
    local cmd_name="$1"
    local pkg_name="$2"
    local description="$3"

    if command -v "$cmd_name" &>/dev/null; then
        echo -e "  ${GREEN}✅ ${description}${NC} — already installed ($(command -v "$cmd_name"))"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    echo -e "  ${YELLOW}📦 Installing ${description}${NC} (${pkg_name})..."
    ensure_pkg_lists
    if ! $INSTALL_CMD "$pkg_name"; then
        echo -e "  ${RED}❌ ${description} — could not install '${pkg_name}'. Install it manually.${NC}"
        return 1
    fi
    if command -v "$cmd_name" &>/dev/null; then
        echo -e "  ${GREEN}✅ ${description} installed successfully!${NC}"
        INSTALLED=$((INSTALLED + 1))
    else
        echo -e "  ${RED}⚠️  ${description} — installed, but '${cmd_name}' is not on PATH yet. May need a relog.${NC}"
    fi
}

echo -e "${BOLD}Checking dependencies...${NC}"
echo ""

echo -e "${CYAN}── Game Detection (X11) ──${NC}"
install_if_missing "xprop" "$XPROP_PKG" "xprop (X11 window detection)"
echo ""

echo -e "${CYAN}── Notifications ──${NC}"
install_if_missing "notify-send" "$NOTIFY_PKG" "notify-send (desktop notifications)"
echo ""

echo -e "${CYAN}── Audio ──${NC}"
if command -v paplay &>/dev/null; then
    echo -e "  ${GREEN}✅ paplay (PulseAudio)${NC} — already installed"
    SKIPPED=$((SKIPPED + 1))
elif command -v pw-play &>/dev/null; then
    echo -e "  ${GREEN}✅ pw-play (PipeWire)${NC} — already installed"
    SKIPPED=$((SKIPPED + 1))
else
    echo -e "  ${YELLOW}📦 Installing audio playback${NC} (${AUDIO_PKG})..."
    ensure_pkg_lists
    if ! $INSTALL_CMD "$AUDIO_PKG"; then
        echo -e "  ${RED}❌ Could not install '${AUDIO_PKG}'. Notification sounds will be silent.${NC}"
    elif command -v paplay &>/dev/null || command -v pw-play &>/dev/null; then
        echo -e "  ${GREEN}✅ Audio playback installed!${NC}"
        INSTALLED=$((INSTALLED + 1))
    else
        echo -e "  ${RED}⚠️  Installed, but neither paplay nor pw-play is on PATH. Notification sounds will be silent.${NC}"
    fi
fi

echo ""

echo -e "${CYAN}── FFmpeg (Video Thumbnails) ──${NC}"
if command -v ffmpeg &>/dev/null; then
    echo -e "  ${GREEN}✅ ffmpeg${NC} — already installed ($(command -v ffmpeg))"
    SKIPPED=$((SKIPPED + 1))
else
    echo -e "  ${YELLOW}📦 Installing ffmpeg${NC}..."
    ensure_pkg_lists
    if ! $INSTALL_CMD ffmpeg; then
        echo -e "  ${RED}❌ Could not install ffmpeg. Video thumbnails will be unavailable.${NC}"
    elif command -v ffmpeg &>/dev/null; then
        echo -e "  ${GREEN}✅ ffmpeg installed successfully!${NC}"
        INSTALLED=$((INSTALLED + 1))
    else
        echo -e "  ${RED}⚠️  Installed, but ffmpeg is not on PATH yet. Video thumbnails will be unavailable.${NC}"
    fi
fi

# ffprobe ships with the ffmpeg package and is what keeps MP4 audio track names.
if command -v ffprobe &>/dev/null; then
    echo -e "  ${GREEN}✅ ffprobe${NC} — available (MP4 thumbnails will keep audio track names)"
else
    echo -e "  ${YELLOW}⚠️  ffprobe not found${NC} — MP4 files will be moved without a thumbnail"
fi

# ── KDE Wayland note ────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}── KDE Plasma / Wayland ──${NC}"
if command -v gdbus &>/dev/null; then
    echo -e "  ${GREEN}✅ gdbus${NC} — available (KDE Wayland window detection will work)"
else
    echo -e "  ${YELLOW}ℹ️  gdbus not found${NC} — KDE Wayland detection unavailable (X11 still works)"
fi

# ── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Done!${NC} Installed: ${INSTALLED}, Already present: ${SKIPPED}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  1. Open OBS Studio"
echo -e "  2. Go to Tools → Scripts"
echo -e "  3. Add Smart_Replay_Mover.lua"
echo -e "  4. The script auto-detects Linux — enjoy! 🎮"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""
