#!/bin/bash
# Dotfiles Backup Script

DOT_DIR="$HOME/dotfiles"

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${BOLD_CYAN}🔄 Synchronizing Environment to $DOT_DIR${RESET}"

mkdir -p "$DOT_DIR/Smart_Bash"
mkdir -p "$DOT_DIR/config/zellij/layouts"

# Init git if needed
if [[ ! -d "$DOT_DIR/.git" ]]; then
    cd "$DOT_DIR" || exit 1
    git init
    echo -e "${BOLD_YELLOW}Initialized empty Git repository.${RESET}"
fi

echo "Copying files..."
cp "$HOME/.bashrc" "$DOT_DIR/"
cp "$HOME/.smart_menu.conf" "$DOT_DIR/" 2>/dev/null
cp -r "$HOME/Smart_Bash/"* "$DOT_DIR/Smart_Bash/"
cp -r "$HOME/.config/zellij/layouts/"* "$DOT_DIR/config/zellij/layouts/" 2>/dev/null

cd "$DOT_DIR" || exit 1

git add .
if git diff-index --quiet HEAD --; then
    echo -e "${BOLD_GREEN}✅ No changes to sync.${RESET}"
    exit 0
fi

git commit -m "Auto-sync environment: $(date '+%Y-%m-%d %H:%M:%S')"

echo -e "${BOLD_GREEN}✅ Committed locally.${RESET}"

if git remote -v | grep -q 'origin'; then
    echo -e "Pushing to remote..."
    git push origin main || git push origin master
    echo -e "${BOLD_GREEN}✅ Sync complete!${RESET}"
else
    echo -e "${BOLD_YELLOW}⚠️  No remote 'origin' configured.${RESET}"
    echo -e "To backup to GitHub, run:"
    echo -e "  cd ~/dotfiles"
    echo -e "  git remote add origin <your-repo-url>"
    echo -e "  git push -u origin main"
fi
