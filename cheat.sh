#!/bin/bash

# Cheat Sheet Manager using fzf

CHEAT_FILE="$HOME/.smart_cheats.tsv"

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

if [[ ! -f "$CHEAT_FILE" ]]; then
    echo -e "Description\tCommand" > "$CHEAT_FILE"
    echo -e "Example: list dir\tls -la" >> "$CHEAT_FILE"
fi

_copy_to_clipboard() {
    local text="$1"
    if command -v wl-copy &> /dev/null; then
        echo -n "$text" | wl-copy
    elif command -v xclip &> /dev/null; then
        echo -n "$text" | xclip -selection clipboard
    elif command -v xsel &> /dev/null; then
        echo -n "$text" | xsel --clipboard --input
    else
        echo -e "${BOLD_YELLOW}⚠️  No clipboard manager found (wl-copy, xclip, xsel).${RESET}"
        return 1
    fi
    echo -e "${BOLD_GREEN}✅ Copied to clipboard: ${RESET}$text"
}

_cheat_menu() {
    while true; do
        local choice=$(printf "🔍  Search Cheats\n➕  Add Cheat\n❌  Exit" | \
            fzf --prompt="Cheat Sheet > " \
                --height=30% \
                --border=rounded \
                --pointer="❯" \
                --color="prompt:cyan,pointer:yellow,hl:green,border:cyan")
                
        case "$choice" in
            *"Search"*)
                local selected
                selected=$(tail -n +2 "$CHEAT_FILE" | \
                    fzf --prompt="Search > " \
                        --height=50% --border=rounded \
                        --delimiter='\t' --with-nth=1 \
                        --preview='echo -e "\033[1;36mCommand:\033[0m\n{2}"' \
                        --preview-window=down:3:wrap \
                        --pointer="❯" \
                        --color="prompt:cyan,pointer:yellow,hl:green,border:cyan")
                
                if [[ -n "$selected" ]]; then
                    local cmd=$(echo "$selected" | awk -F'\t' '{print $2}')
                    _copy_to_clipboard "$cmd"
                    return
                fi
                ;;
            *"Add"*)
                read -r -p $'\e[1;36m❯ Description: \e[0m' desc
                read -r -p $'\e[1;36m❯ Command: \e[0m' cmd
                if [[ -n "$desc" && -n "$cmd" ]]; then
                    echo -e "${desc}\t${cmd}" >> "$CHEAT_FILE"
                    echo -e "${BOLD_GREEN}✅ Added to cheat sheet.${RESET}"
                fi
                ;;
            *"Exit"*|"") return ;;
        esac
    done
}

_cheat_menu
