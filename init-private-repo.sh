#!/bin/bash
# Bootible - Initialize Private Configuration Repository
# =======================================================
# Creates a new Git repository with the structure needed for
# private Bootible configuration.
#
# Usage:
#   ./init-private-repo.sh
#   cd private
#   git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
#   git push -u origin main

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_PATH="$SCRIPT_DIR/private"

echo -e "${BLUE}"
echo "+------------------------------------------------------------+"
echo "|       Bootible - Initialize Private Repository             |"
echo "+------------------------------------------------------------+"
echo -e "${NC}"

if [[ -d "$PRIVATE_PATH/.git" ]]; then
    echo -e "${YELLOW}!${NC} Private repo already initialized at: $PRIVATE_PATH"
    exit 0
fi

echo -e "${BLUE}->${NC} Creating private repository structure..."

# Create directories for each device
mkdir -p "$PRIVATE_PATH/rog-ally/scripts"
mkdir -p "$PRIVATE_PATH/steamdeck/scripts"
mkdir -p "$PRIVATE_PATH/logs/rog-ally"
mkdir -p "$PRIVATE_PATH/logs/steamdeck"

# Copy default config files
# Users can see all available options and modify as needed
cp "$SCRIPT_DIR/config/rog-ally/config.yml" "$PRIVATE_PATH/rog-ally/config.yml"
cp "$SCRIPT_DIR/config/steamdeck/config.yml" "$PRIVATE_PATH/steamdeck/config.yml"

# Create README
cat > "$PRIVATE_PATH/README.md" << 'EOF'
# Bootible Private Configuration

My private overlay for [bootible](https://github.com/gavinmcfall/bootible).

## Structure

```
private/
├── rog-ally/
│   ├── config.yml        # ROG Ally overrides
│   └── scripts/          # Install scripts (EmuDeck EA, etc.)
├── steamdeck/
│   ├── config.yml        # Steam Deck overrides
│   └── scripts/          # Install scripts
└── logs/
    ├── rog-ally/         # Dry run logs
    └── steamdeck/
```

## Usage

Run bootible with this private repo:

**Steam Deck:**
```bash
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash -s -- git@github.com:YOUR_USER/YOUR_REPO.git
```

**ROG Ally X:**
```powershell
$env:BOOTIBLE_PRIVATE = "https://github.com/YOUR_USER/YOUR_REPO.git"
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex
```

## Adding EmuDeck Early Access

If you have EmuDeck Patreon access, place the install scripts in:

| Device | Location |
|--------|----------|
| Steam Deck | `steamdeck/scripts/EmuDeck EA SteamOS.desktop.download` |
| ROG Ally | `rog-ally/scripts/EmuDeck EA Windows.bat` |

Bootible will automatically use EA version if found.
EOF

# Create .gitignore
cat > "$PRIVATE_PATH/.gitignore" << 'EOF'
# Large binary files (download these, don't commit)
*.exe
*.msi
*.zip
*.7z
*.flatpak
*.AppImage

# But keep directory structure
!.gitkeep

# Sensitive files
*.key
*.pem
credentials*
*secret*
EOF

# Add .gitkeep files
touch "$PRIVATE_PATH/rog-ally/scripts/.gitkeep"
touch "$PRIVATE_PATH/steamdeck/scripts/.gitkeep"
touch "$PRIVATE_PATH/logs/rog-ally/.gitkeep"
touch "$PRIVATE_PATH/logs/steamdeck/.gitkeep"

# Initialize git repo
cd "$PRIVATE_PATH"
git init
git add .
git commit -m "Initial bootible private configuration"

echo ""
echo -e "${GREEN}[OK]${NC} Private repository initialized!"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create a private repo on GitHub:"
echo "     https://github.com/new"
echo ""
echo "  2. Push this repo:"
echo "     cd private"
echo "     git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git"
echo "     git push -u origin main"
echo ""
echo "  3. Edit configs for your devices:"
echo "     private/rog-ally/config.yml"
echo "     private/steamdeck/config.yml"
echo ""
