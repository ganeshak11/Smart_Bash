#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Smart Bash — uninstaller                                                    ║
# ║  Restores your pre-Smart-Bash ~/.bashrc. Asks before removing anything else. ║
# ║  Never deletes this repo, ~/.bashrc.local or ~/.secrets.                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e
SMART_BASH_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SMART_BASH_DIR/lib.sh"

BASHRC="$HOME/.bashrc"
STUB_MARKER="# >>> smart-bash >>>"

ask() {  # ask "question" → 0 on yes
    local a
    read -r -p "  $1 [y/N]: " a
    [[ "$a" =~ ^[Yy]$ ]]
}

echo -e "\n  ${SB_BOLD_MAGENTA}Smart Bash — uninstall${SB_RESET}\n"

# Newest backup that is NOT itself a Smart Bash stub
restore_from=""
while IFS= read -r f; do
    if ! grep -qF "$STUB_MARKER" "$f"; then restore_from="$f"; break; fi
done < <(ls -1t "$HOME"/.bashrc.backup.* 2>/dev/null)

if [[ -n "$restore_from" ]]; then
    echo -e "  Latest backup of your old config: ${SB_BOLD_WHITE}$restore_from${SB_RESET}"
    ask "Restore it as ~/.bashrc?" || { echo "  Nothing changed."; exit 0; }
elif [[ -f /etc/skel/.bashrc ]]; then
    restore_from=/etc/skel/.bashrc
    echo -e "  No backup found — the system default ${SB_BOLD_WHITE}/etc/skel/.bashrc${SB_RESET} will be used."
    ask "Replace ~/.bashrc with the system default?" || { echo "  Nothing changed."; exit 0; }
else
    echo -e "  ${SB_BOLD_RED}No backup and no /etc/skel/.bashrc found.${SB_RESET}"
    echo "  Edit ~/.bashrc yourself and remove the smart-bash block."
    exit 1
fi

# Keep a copy of the current file too, in case
cp "$BASHRC" "$HOME/.bashrc.smart-bash.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
cp "$restore_from" "$BASHRC"
echo -e "  ${SB_BOLD_GREEN}✔${SB_RESET}  ~/.bashrc restored from $restore_from"

if [[ -f "$HOME/.config/zellij/layouts/hacker.kdl" ]] && ask "Remove the zellij hacker layout?"; then
    rm -f -- "$HOME/.config/zellij/layouts/hacker.kdl"
    echo -e "  ${SB_BOLD_GREEN}✔${SB_RESET}  Removed hacker.kdl"
fi
if [[ -f "$HOME/.smart_menu.conf" ]] && ask "Remove ~/.smart_menu.conf?"; then
    rm -f -- "$HOME/.smart_menu.conf"
    echo -e "  ${SB_BOLD_GREEN}✔${SB_RESET}  Removed ~/.smart_menu.conf"
fi
if [[ -d "$SB_CACHE_DIR" || -d "$SB_CONFIG_DIR" ]] && ask "Remove Smart Bash cache and settings (~/.cache/smart_bash, ~/.config/smart_bash)?"; then
    rm -rf -- "${SB_CACHE_DIR:?}" "${SB_CONFIG_DIR:?}"
    echo -e "  ${SB_BOLD_GREEN}✔${SB_RESET}  Removed cache and settings"
fi

echo ""
echo -e "  Kept: ${SB_BOLD_WHITE}~/.bashrc.local${SB_RESET}, ${SB_BOLD_WHITE}~/.secrets${SB_RESET} and the repo at ${SB_BOLD_WHITE}$SMART_BASH_DIR${SB_RESET}"
echo -e "  Open a new terminal to use the restored config."
echo ""
