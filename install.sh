#!/usr/bin/env bash
# ==============================================================================
#  KYPRLAND - MACOS / KDE HYBRID HYPRLAND RICE INSTALLER
#  Designed for clean, floating-first, 100% zoom, macOS topbar & bottom dock.
# ==============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/hypr-setup-backup-$(date +%Y%m%d_%H%M%S)"

echo -e "${CYAN}${BOLD}"
echo "  ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗ "
echo "  ██║ ██╔╝╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗"
echo "  █████╔╝  ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║"
echo "  ██╔═██╗   ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║"
echo "  ██║  ██╗   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝"
echo "  ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ "
echo "                ~ Kyprland: Floating-First Hyprland Rice ~           "
echo -e "${NC}"

# 1. Distro & AUR Helper check
echo -e "${YELLOW}[1/6] Checking system environment...${NC}"
if ! command -v pacman &>/dev/null; then
    echo -e "${RED}Error: This setup is designed for Arch Linux / CachyOS / EndeavourOS.${NC}"
    exit 1
fi

AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    echo -e "${YELLOW}Installing yay AUR helper...${NC}"
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    AUR_HELPER="yay"
fi

# 2. Dependencies
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
PACKAGES=(
    # Core & Shell
    hyprland
    kitty
    noctalia
    nautilus
    adw-gtk-theme
    adwaita-icon-theme
    adwaita-fonts
    qt6ct
    librsvg
    # Build dependencies for plugins
    cmake
    make
    gcc
    pkg-config
    libadwaita
)

$AUR_HELPER -S --needed --noconfirm "${PACKAGES[@]}"

# 3. Backup existing configs
echo -e "${YELLOW}[3/6] Backing up existing configs to ${BACKUP_DIR}...${NC}"
mkdir -p "$BACKUP_DIR"
for cfg in hypr noctalia kitty qt6ct; do
    if [ -d "$HOME/.config/$cfg" ]; then
        cp -r "$HOME/.config/$cfg" "$BACKUP_DIR/"
    fi
done
if [ -f "$HOME/.local/state/noctalia/settings.toml" ]; then
    mkdir -p "$BACKUP_DIR/state_noctalia"
    cp "$HOME/.local/state/noctalia/settings.toml" "$BACKUP_DIR/state_noctalia/"
fi

# 4. Deploy configurations
echo -e "${YELLOW}[4/6] Deploying dotfiles...${NC}"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/state/noctalia"
mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$HOME/.local/share/applications"

# Copy configs
cp -r "$DOTFILES_DIR/config/hypr" "$HOME/.config/"
cp -r "$DOTFILES_DIR/config/noctalia" "$HOME/.config/"
cp -r "$DOTFILES_DIR/config/kitty" "$HOME/.config/"
cp -r "$DOTFILES_DIR/config/qt6ct" "$HOME/.config/"
cp -f "$DOTFILES_DIR/config/kdeglobals" "$HOME/.config/" 2>/dev/null || true

# Copy Noctalia state (dock & bar state)
cp -f "$DOTFILES_DIR/local/state/noctalia/settings.toml" "$HOME/.local/state/noctalia/" 2>/dev/null || true

# Copy Icons & Applications
cp -rf "$DOTFILES_DIR/local/share/icons/"* "$HOME/.local/share/icons/" 2>/dev/null || true
cp -rf "$DOTFILES_DIR/local/share/applications/"* "$HOME/.local/share/applications/" 2>/dev/null || true

# Optional VS Code config if installed
if [ -d "$HOME/.config/Code - OSS" ]; then
    mkdir -p "$HOME/.config/Code - OSS/User"
    cp -f "$DOTFILES_DIR/config/vscode/settings.json" "$HOME/.config/Code - OSS/User/" 2>/dev/null || true
fi
if [ -d "$HOME/.config/Code" ]; then
    mkdir -p "$HOME/.config/Code/User"
    cp -f "$DOTFILES_DIR/config/vscode/settings.json" "$HOME/.config/Code/User/" 2>/dev/null || true
fi

# 5. Build/Verify Hyprland Plugins
echo -e "${YELLOW}[5/6] Verifying and compiling plugins for your Hyprland version...${NC}"
HYPR_PLUGINS_DIR="$HOME/.config/hypr/plugins"

# Check hyprbars
if [ -d "$HYPR_PLUGINS_DIR/hyprbars" ]; then
    echo "Compiling hyprbars plugin..."
    (cd "$HYPR_PLUGINS_DIR/hyprbars" && make clean 2>/dev/null || true && make all) || {
        echo -e "${YELLOW}Notice: Using shipped hyprbars binary.${NC}"
    }
fi

# Check kyprland
if [ -d "$HYPR_PLUGINS_DIR/kyprland" ]; then
    echo "Compiling kyprland plugin..."
    (cd "$HYPR_PLUGINS_DIR/kyprland" && \
     g++ -shared -fPIC --no-gnu-unique main.cpp -o "$HYPR_PLUGINS_DIR/kyprland.so" -I/usr/include/hyprland -DWLR_USE_UNSTABLE -O2 -std=c++23) || {
        echo -e "${YELLOW}Notice: Using shipped kyprland binary.${NC}"
    }
fi

# 6. Refresh Caches & Reload
echo -e "${YELLOW}[6/6] Refreshing icon caches and reloading environment...${NC}"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

if command -v hyprctl &>/dev/null; then
    hyprctl reload config-only 2>/dev/null || true
fi

if command -v noctalia &>/dev/null; then
    noctalia msg config-reload 2>/dev/null || true
    noctalia msg dock-reload 2>/dev/null || true
fi

echo -e "\n${GREEN}${BOLD}✓ Installation Complete!${NC}"
echo -e "${CYAN}Features active:"
echo " - 100% Crisp Scaling (no blurry UI or giant windows)"
echo " - Clean Floating-first Window Management"
echo " - macOS-style Traffic Light Buttons (Close, Maximize, Native Minimize)"
echo " - Noctalia Floating Top Bar + Autohiding Bottom Dock"
echo " - Adwaita Dark Styling & Custom App Icons"
echo -e "${NC}\nEnjoy your setup! 🚀"
