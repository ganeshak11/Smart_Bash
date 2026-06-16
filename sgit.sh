#!/bin/bash

# Smart Git using fzf

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

_check_git() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${BOLD_RED}❌ Not a git repository.${RESET}"
        return 1
    fi
}

_sgit_menu() {
    local prompt="$1"
    shift
    printf '%s\n' "$@" | fzf \
        --prompt="$prompt > " \
        --height=40% \
        --border=rounded \
        --ansi \
        --no-multi \
        --cycle \
        --pointer="❯" \
        --color="prompt:cyan,pointer:yellow,hl:green,border:cyan"
}

_sgit_stage() {
    echo -e "${BOLD_CYAN}📝 Select files to stage (Tab to multi-select):${RESET}"
    local selected
    selected=$(git -c color.status=always status -s | \
        fzf --height=50% --border=rounded --ansi --multi \
            --prompt="Stage > " --pointer="❯" \
            --preview="git diff --color=always -- {-1} | head -200")
    
    if [[ -n "$selected" ]]; then
        # Extract file paths from git status -s output
        local files=$(echo "$selected" | sed -E 's/^...//')
        echo "$files" | tr '\n' '\0' | xargs -0 git add
        echo -e "${BOLD_GREEN}✅ Staged selected files.${RESET}"
    fi
}

_sgit_branch() {
    echo -e "${BOLD_CYAN}🌿 Select branch:${RESET}"
    local selected
    selected=$(git branch -a --color=always | \
        fzf --height=50% --border=rounded --ansi --no-multi \
            --prompt="Branch > " --pointer="❯" \
            --preview="git log --color=always --oneline --graph --date=short -n 50 {1} 2>/dev/null")
    
    if [[ -n "$selected" ]]; then
        local branch=$(echo "$selected" | sed -E 's/^[* ]*//' | awk '{print $1}')
        local action=$(_sgit_menu "Action for $branch" "Checkout" "Delete" "Merge into current")
        case "$action" in
            "Checkout") git checkout "$branch" ;;
            "Delete") git branch -D "$branch" ;;
            "Merge into current") git merge "$branch" ;;
        esac
    fi
}

_sgit_log() {
    echo -e "${BOLD_CYAN}📜 Git Log:${RESET}"
    local selected
    selected=$(git log --color=always --oneline --graph --decorate --all | \
        fzf --height=80% --border=rounded --ansi --no-multi \
            --prompt="Log > " --pointer="❯" \
            --preview="git show --color=always {2} 2>/dev/null")
    
    if [[ -n "$selected" ]]; then
        local commit=$(echo "$selected" | grep -oE '[a-f0-9]{7,}' | head -1)
        if [[ -n "$commit" ]]; then
            local action=$(_sgit_menu "Action for $commit" "Show full diff" "Cherry-pick")
            case "$action" in
                "Show full diff") git show "$commit" ;;
                "Cherry-pick") git cherry-pick "$commit" ;;
            esac
        fi
    fi
}

sgit() {
    _check_git || return 1
    
    while true; do
        local choice=$(_sgit_menu "Smart Git" \
            "📝  Stage Files" \
            "🌿  Manage Branches" \
            "📜  Explore Log" \
            "❌  Exit")
            
        case "$choice" in
            *"Stage"*) _sgit_stage ;;
            *"Branch"*) _sgit_branch ;;
            *"Log"*) _sgit_log ;;
            *"Exit"*|"") return ;;
        esac
    done
}

sgit
