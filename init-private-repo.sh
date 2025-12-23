#!/bin/bash
# Initialize a private deckible configuration repository
# ======================================================
# Creates a private GitHub repo with the correct structure for deckible.
#
# Usage:
#   ./init-private-repo.sh                    # Interactive
#   ./init-private-repo.sh myusername         # With GitHub username
#   ./init-private-repo.sh myusername myrepo  # Custom repo name

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║   Deckible Private Repo Setup              ║"
echo "║   Creates your personal config repository  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is required${NC}"
    echo ""
    echo "Install it with:"
    echo "  sudo pacman -S github-cli    # Arch/SteamOS"
    echo "  brew install gh              # macOS"
    echo "  sudo apt install gh          # Debian/Ubuntu"
    echo ""
    echo "Then authenticate:"
    echo "  gh auth login"
    exit 1
fi

# Check gh auth status
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI not authenticated${NC}"
    echo "Running: gh auth login"
    gh auth login
fi

# Get GitHub username
if [[ -n "$1" ]]; then
    GH_USER="$1"
else
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [[ -z "$GH_USER" ]]; then
        read -p "GitHub username: " GH_USER
    else
        echo -e "GitHub user: ${GREEN}$GH_USER${NC}"
        read -p "Press Enter to confirm or type a different username: " input
        [[ -n "$input" ]] && GH_USER="$input"
    fi
fi

# Get repo name
REPO_NAME="${2:-steamdeck}"
echo -e "Repository name: ${GREEN}$REPO_NAME${NC}"
read -p "Press Enter to confirm or type a different name: " input
[[ -n "$input" ]] && REPO_NAME="$input"

echo ""
echo -e "${BLUE}Creating private repository: $GH_USER/$REPO_NAME${NC}"

# Check if repo already exists
if gh repo view "$GH_USER/$REPO_NAME" &> /dev/null; then
    echo -e "${YELLOW}Repository $GH_USER/$REPO_NAME already exists${NC}"
    read -p "Clone and set up anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    # Create the private repo
    echo -e "${BLUE}→${NC} Creating private repository..."
    gh repo create "$REPO_NAME" --private --description "My deckible private configuration" --clone
    cd "$REPO_NAME"
fi

# Clone if we didn't just create it
if [[ ! -d "$REPO_NAME" ]] && [[ "$(basename "$PWD")" != "$REPO_NAME" ]]; then
    echo -e "${BLUE}→${NC} Cloning repository..."
    gh repo clone "$GH_USER/$REPO_NAME"
    cd "$REPO_NAME"
fi

# Create directory structure
echo -e "${BLUE}→${NC} Creating directory structure..."
mkdir -p group_vars files/appimages files/flatpaks

# Create .gitkeep files
touch files/appimages/.gitkeep files/flatpaks/.gitkeep

# Download default config
echo -e "${BLUE}→${NC} Downloading default configuration..."
curl -sL "https://raw.githubusercontent.com/gavinmcfall/deckible/main/group_vars/all.yml" -o group_vars/all.yml

# Create README
cat > README.md << 'EOF'
# Deckible Private Configuration

My private overlay repository for [deckible](https://github.com/gavinmcfall/deckible).

## Structure

```
├── group_vars/
│   └── all.yml          # My personal settings (overrides deckible defaults)
└── files/
    ├── appimages/       # EmuDeck EA, etc.
    └── flatpaks/        # Local .flatpak files
```

## Usage

```bash
git clone https://github.com/gavinmcfall/deckible.git
cd deckible
./setup.sh git@github.com:YOUR_USERNAME/steamdeck.git
ansible-playbook playbook.yml --ask-become-pass
```

## Updating

Edit `group_vars/all.yml`, then:

```bash
git add -A && git commit -m "Update config" && git push
```
EOF

# Update README with actual username
sed -i "s/YOUR_USERNAME/$GH_USER/g" README.md

# Create .gitignore
cat > .gitignore << 'EOF'
# Ansible
*.retry

# OS
.DS_Store
Thumbs.db
EOF

# Commit and push
echo -e "${BLUE}→${NC} Committing and pushing..."
git add -A
git commit -m "Initial deckible private configuration"
git push -u origin main 2>/dev/null || git push -u origin master

REPO_PATH="$PWD"
cd "$SCRIPT_DIR"

echo ""
echo -e "${GREEN}✓ Private repository created successfully!${NC}"
echo ""
echo -e "Repository: ${BLUE}https://github.com/$GH_USER/$REPO_NAME${NC}"
echo -e "Local path: ${BLUE}$REPO_PATH${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Edit your configuration:"
echo -e "     ${YELLOW}nano $REPO_PATH/group_vars/all.yml${NC}"
echo ""
echo "  2. Add private files (optional):"
echo -e "     ${YELLOW}cp ~/Downloads/EmuDeck*.desktop.download $REPO_PATH/files/appimages/${NC}"
echo ""
echo "  3. Commit your changes:"
echo -e "     ${YELLOW}cd $REPO_PATH && git add -A && git commit -m 'My config' && git push${NC}"
echo ""
echo "  4. Link to deckible:"
echo -e "     ${YELLOW}cd $SCRIPT_DIR && ./setup.sh git@github.com:$GH_USER/$REPO_NAME.git${NC}"
echo ""

# Offer to link now
read -p "Link this repo to deckible now? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ./setup.sh "git@github.com:$GH_USER/$REPO_NAME.git"
fi
