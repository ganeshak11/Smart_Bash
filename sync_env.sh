#!/bin/bash
# Dotfiles Backup Script

# shellcheck disable=SC1091
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DOT_DIR="$HOME/dotfiles"

echo -e "${SB_BOLD_CYAN}🔄 Synchronizing Environment to $DOT_DIR${SB_RESET}"

mkdir -p "$DOT_DIR/Smart_Bash"
mkdir -p "$DOT_DIR/config/zellij/layouts"

# Init git if needed
if [[ ! -d "$DOT_DIR/.git" ]]; then
    cd "$DOT_DIR" || exit 1
    git init
    echo -e "${SB_BOLD_YELLOW}Initialized empty Git repository.${SB_RESET}"
fi

echo "Copying files..."
cp "$HOME/.bashrc" "$DOT_DIR/"
cp "$HOME/.bashrc.local" "$DOT_DIR/" 2>/dev/null
cp "$HOME/.smart_menu.conf" "$DOT_DIR/" 2>/dev/null
# Smart Bash itself (without its .git — it has its own repo)
if command -v rsync &>/dev/null; then
    rsync -a --exclude='.git' --exclude='.claude' "$SMART_BASH_DIR/" "$DOT_DIR/Smart_Bash/"
else
    cp -r "$SMART_BASH_DIR/"* "$DOT_DIR/Smart_Bash/"
fi
cp -r "$HOME/.config/zellij/layouts/"* "$DOT_DIR/config/zellij/layouts/" 2>/dev/null

cd "$DOT_DIR" || exit 1

git add .
if git diff-index --quiet HEAD --; then
    echo -e "${SB_BOLD_GREEN}✅ No changes to sync.${SB_RESET}"
    exit 0
fi

git commit -m "Auto-sync environment: $(date '+%Y-%m-%d %H:%M:%S')"

echo -e "${SB_BOLD_GREEN}✅ Committed locally.${SB_RESET}"

if git remote -v | grep -q 'origin'; then
    echo -e "Pushing to remote..."
    git push origin main || git push origin master
    echo -e "${SB_BOLD_GREEN}✅ Sync complete!${SB_RESET}"
else
    echo -e "${SB_BOLD_YELLOW}⚠️  No remote 'origin' configured.${SB_RESET}"
    echo -e "To backup to GitHub, run:"
    echo -e "  cd ~/dotfiles"
    echo -e "  git remote add origin <your-repo-url>"
    echo -e "  git push -u origin main"
fi
