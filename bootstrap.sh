#!/bin/bash
# Deckible Bootstrap Script
# =========================
# One-command setup for Steam Deck
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/gavinmcfall/deckible/main/bootstrap.sh | bash
#
# Or with a private repo:
#   curl -fsSL https://raw.githubusercontent.com/gavinmcfall/deckible/main/bootstrap.sh | bash -s -- git@github.com:USER/steamdeck.git

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PRIVATE_REPO="${1:-}"
DECKIBLE_DIR="$HOME/deckible"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║         Deckible Bootstrap             ║"
echo "║   Steam Deck Ansible Configuration     ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running on Steam Deck / Arch
check_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
            echo -e "${GREEN}✓${NC} Running on Arch-based system"
            return 0
        fi
    fi
    echo -e "${YELLOW}⚠${NC} Not running on Arch/SteamOS - some features may not work"
}

# Check for sudo password
check_sudo() {
    echo -e "${BLUE}→${NC} Checking sudo access..."
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Sudo access confirmed"
        return 0
    fi

    # Check if password is set
    if passwd -S "$USER" 2>/dev/null | grep -q " NP "; then
        echo -e "${YELLOW}!${NC} No sudo password set"
        echo ""
        echo "Please set a password now (you'll need this for ansible):"
        passwd
        echo ""
    fi

    # Verify sudo works
    echo "Enter your sudo password to continue:"
    if ! sudo true; then
        echo -e "${RED}✗${NC} Sudo authentication failed"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Sudo access confirmed"
}

# Install Ansible
install_ansible() {
    if command -v ansible-playbook &> /dev/null; then
        echo -e "${GREEN}✓${NC} Ansible already installed"
        return 0
    fi

    echo -e "${BLUE}→${NC} Installing Ansible..."

    # Try pip first (survives SteamOS updates)
    if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
        echo "  Using pip (recommended - survives updates)..."
        pip3 install --user ansible || pip install --user ansible
        export PATH="$HOME/.local/bin:$PATH"
        if command -v ansible-playbook &> /dev/null; then
            echo -e "${GREEN}✓${NC} Ansible installed via pip"
            return 0
        fi
    fi

    # Fall back to pacman
    echo "  Using pacman..."
    sudo steamos-readonly disable
    sudo pacman -S --noconfirm ansible
    sudo steamos-readonly enable
    echo -e "${GREEN}✓${NC} Ansible installed via pacman"
}

# Clone deckible
clone_deckible() {
    if [[ -d "$DECKIBLE_DIR" ]]; then
        echo -e "${BLUE}→${NC} Updating existing deckible..."
        cd "$DECKIBLE_DIR"
        git pull
    else
        echo -e "${BLUE}→${NC} Cloning deckible..."
        git clone https://github.com/gavinmcfall/deckible.git "$DECKIBLE_DIR"
        cd "$DECKIBLE_DIR"
    fi
    echo -e "${GREEN}✓${NC} Deckible ready at $DECKIBLE_DIR"
}

# Setup private repo if provided
setup_private() {
    if [[ -n "$PRIVATE_REPO" ]]; then
        echo -e "${BLUE}→${NC} Setting up private repo..."
        ./setup.sh "$PRIVATE_REPO"
    fi
}

# Run playbook
run_playbook() {
    echo ""
    echo -e "${BLUE}→${NC} Running deckible playbook..."
    echo ""
    ansible-playbook playbook.yml --ask-become-pass
}

# Main
main() {
    check_system
    echo ""
    check_sudo
    echo ""
    install_ansible
    echo ""
    clone_deckible
    echo ""
    setup_private
    echo ""
    run_playbook

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Setup Complete!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  • Switch to Gaming Mode to see Decky plugins"
    echo "  • Run EmuDeck wizard if you enabled emulation"
    echo "  • Check README for post-install configuration"
    echo ""
    echo "To re-run or update:"
    echo "  cd ~/deckible && git pull && ansible-playbook playbook.yml --ask-become-pass"
}

main "$@"
