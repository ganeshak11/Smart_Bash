#!/bin/bash

# shellcheck disable=SC1091
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# ─── Smart Menu Configuration ────────────────────────────────────────────────
_SM_CONFIG_FILE="$HOME/.smart_menu.conf"
if [[ ! -f "$_SM_CONFIG_FILE" ]]; then
    cat << 'EOF' > "$_SM_CONFIG_FILE"
# Smart Menu Configuration
# Normally written by install.sh — this is only the fallback if it's missing.
SMART_MENU_DEV_DIRS=("$HOME/dev")
SMART_MENU_EDITORS=("VS Code:code" "Cursor:cursor" "Neovim:nvim" "None (Just cd to dir):none")
EOF
fi
source "$_SM_CONFIG_FILE"

# ─── Known projects → layout mapping ─────────────────────────────────────────
# Key: lowercase folder name  Value: layout filename (no .kdl)
declare -A _SM_KNOWN_LAYOUTS=(
    ["fortis-ci"]="fortis-ci"
    ["cicd-sentinel"]="cicd-sentinel"
)

# ─── Colors ───────────────────────────────────────────────────────────────────

# ─── Cursor helpers ───────────────────────────────────────────────────────────
_sm_cursor_up() {
    tput cuu "$1" 2>/dev/null || echo -ne "\e[${1}A"
}

# ─── _sm_draw_menu ────────────────────────────────────────────────────────────────
_sm_draw_menu() {
    local title="$1"
    local selected="$2"
    shift 2
    local options=("$@")

    echo -e "${SB_BOLD_MAGENTA}Welcome back, Boss! What do you want to do?${SB_RESET}${SB_CLEAR_LINE}"
    echo -e "${SB_DIM}${SB_CYAN}$title${SB_RESET}${SB_CLEAR_LINE}"
    echo -e "${SB_CLEAR_LINE}"

    for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
            echo -e "  ${SB_BOLD_GREEN}❯ ${options[$i]}${SB_RESET}${SB_CLEAR_LINE}"
        else
            echo -e "    ${SB_WHITE}${options[$i]}${SB_RESET}${SB_CLEAR_LINE}"
        fi
    done
}

# ─── _sm_run_menu ─────────────────────────────────────────────────────────────────
_sm_run_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local count=${#options[@]}
    local lines_to_clear=$(( count + 3 ))

    for ((i=0; i<lines_to_clear; i++)); do echo ""; done
    _sm_cursor_up "$lines_to_clear"

    while true; do
        _sm_draw_menu "$title" "$selected" "${options[@]}"

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            if [[ $key2 == '[A' ]]; then
                ((selected--))
                if [[ $selected -lt 0 ]]; then selected=$((count - 1)); fi
            elif [[ $key2 == '[B' ]]; then
                ((selected++))
                if [[ $selected -ge $count ]]; then selected=0; fi
            fi
        elif [[ $key == "" ]]; then
            break
        fi

        _sm_cursor_up "$lines_to_clear"
    done

    echo ""
    return "$selected"
}

# ─── Exported state ───────────────────────────────────────────────────────────
export SMART_MENU_ACTION=""
export SMART_MENU_PROJECT_DIR=""
export SMART_MENU_EDITOR=""
export SMART_MENU_SSH_HOST=""
export SMART_MENU_LAYOUT=""

# ─── Editor picker ────────────────────────────────────────────────────────────
_sm_editor_picker() {
    local editor_names=()
    local editor_cmds=()
    for ed in "${SMART_MENU_EDITORS[@]}"; do
        editor_names+=("${ed%%:*}")
        editor_cmds+=("${ed##*:}")
    done
    _sm_run_menu "Open project with which editor?" "${editor_names[@]}"
    local ed_choice=$?
    export SMART_MENU_EDITOR="${editor_cmds[$ed_choice]}"
}

# ─── Project menu ─────────────────────────────────────────────────────────────
_sm_project_menu() {
    local recent_dirs=()
    local find_cmd="find"
    for dir in "${SMART_MENU_DEV_DIRS[@]}"; do
        [[ -d "$dir" ]] && find_cmd+=" \"$dir\""
    done

    if [[ "$find_cmd" != "find" ]]; then
        find_cmd+=" -mindepth 1 -maxdepth 1 -type d ! -name \".*\""
        while IFS= read -r line; do
            recent_dirs+=("$line")
        done < <(eval "$find_cmd" | xargs -I {} stat -c "%Y %n" "{}" 2>/dev/null | sort -nr | head -n 6 | cut -d' ' -f2-)
    fi

    local options=()
    local project_paths=()
    for dir in "${recent_dirs[@]}"; do
        options+=("  $(basename "$dir")")
        project_paths+=("$dir")
    done

    options+=("  Search existing project" "+ New Project" "< Back")

    _sm_run_menu "Select a project to dive into:" "${options[@]}"
    local choice=$?

    local num_recent=${#recent_dirs[@]}

    if [[ $choice -lt $num_recent ]]; then
        SMART_MENU_PROJECT_DIR="${project_paths[$choice]}"
        local proj_key
        proj_key=$(basename "${project_paths[$choice]}" | tr '[:upper:]' '[:lower:]')
        if [[ -n "${_SM_KNOWN_LAYOUTS[$proj_key]}" ]]; then
            SMART_MENU_LAYOUT="${_SM_KNOWN_LAYOUTS[$proj_key]}"
        else
            SMART_MENU_LAYOUT="generic-project"
        fi
        _sm_editor_picker
        SMART_MENU_ACTION="project"

    elif [[ $choice -eq $num_recent ]]; then
        local find_search_cmd=""
        for dir in "${SMART_MENU_DEV_DIRS[@]}"; do
            [[ -d "$dir" ]] && find_search_cmd+="find \"$dir\" -mindepth 1 -maxdepth 1 -type d ! -name \".*\" 2>/dev/null; "
        done
        local selected_project
        selected_project=$(eval "$find_search_cmd" | sed "s|^$HOME/|~/|" | sort -u | fzf --prompt="🔍 Search project: " --height=40% --layout=reverse --border=rounded)

        if [[ -n "$selected_project" ]]; then
            SMART_MENU_PROJECT_DIR="${selected_project/#\~\//$HOME/}"
            local proj_key
            proj_key=$(basename "$SMART_MENU_PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
            if [[ -n "${_SM_KNOWN_LAYOUTS[$proj_key]}" ]]; then
                SMART_MENU_LAYOUT="${_SM_KNOWN_LAYOUTS[$proj_key]}"
            else
                SMART_MENU_LAYOUT="generic-project"
            fi
            _sm_editor_picker
            SMART_MENU_ACTION="project"
        else
            _sm_project_menu
        fi

    elif [[ $choice -eq $((num_recent + 1)) ]]; then
        local default_dev="${SMART_MENU_DEV_DIRS[0]:-$HOME/dev}"
        local new_opts=("Create empty project locally" "Clone from remote repository" "< Cancel")
        _sm_run_menu "How do you want to start?" "${new_opts[@]}"
        local new_choice=$?

        if [[ $new_choice -eq 0 ]]; then
            echo -e "${SB_BOLD_YELLOW}Enter new project name (in ${default_dev}):${SB_RESET}"
            read -r proj_name
            if [[ -n "$proj_name" ]]; then
                local new_dir="${default_dev}/$proj_name"
                mkdir -p "$new_dir"
                SMART_MENU_PROJECT_DIR="$new_dir"
                SMART_MENU_LAYOUT="generic-project"
                _sm_editor_picker
                SMART_MENU_ACTION="project"
            else
                _sm_project_menu
            fi
        elif [[ $new_choice -eq 1 ]]; then
            echo -e "${SB_BOLD_YELLOW}Enter Git repository URL to clone:${SB_RESET}"
            read -r repo_url
            if [[ -n "$repo_url" ]]; then
                local proj_name
                proj_name=$(basename "$repo_url" .git)
                local new_dir="${default_dev}/$proj_name"
                echo -e "${SB_BOLD_CYAN}Cloning into $new_dir...${SB_RESET}"
                git clone "$repo_url" "$new_dir"
                if [[ $? -eq 0 ]]; then
                    SMART_MENU_PROJECT_DIR="$new_dir"
                    SMART_MENU_LAYOUT="generic-project"
                    _sm_editor_picker
                    SMART_MENU_ACTION="project"
                else
                    echo -e "${SB_BOLD_RED}Clone failed.${SB_RESET}"
                    read -r -p "Press any key to continue..." -n 1
                    _sm_project_menu
                fi
            else
                _sm_project_menu
            fi
        else
            _sm_main_menu
        fi
    else
        _sm_main_menu
    fi
}

# ─── SSH picker ───────────────────────────────────────────────────────────────
_sm_quick_ssh() {
    local ssh_config="$HOME/.ssh/config"
    local hosts=""
    if [[ -f "$ssh_config" ]]; then
        hosts=$(grep -i '^Host ' "$ssh_config" | awk '{print $2}' | grep -vF '*')
    fi

    local selected_host
    if [[ -n "$hosts" ]]; then
        selected_host=$(echo "$hosts" | fzf --prompt="🔌 Select SSH Host: " --height=40% --layout=reverse --border=rounded)
    else
        echo -e "${SB_BOLD_YELLOW}No hosts found in ~/.ssh/config.${SB_RESET}"
        read -e -p $'\e[1;36m❯ Enter SSH destination (user@host): \e[0m' selected_host
    fi

    if [[ -n "$selected_host" ]]; then
        export SMART_MENU_ACTION="ssh"
        export SMART_MENU_SSH_HOST="$selected_host"
    else
        _sm_main_menu
    fi
}

# ─── Main menu ────────────────────────────────────────────────────────────────
_sm_main_menu() {
    local options=(
        "  Casual Browsing"
        "  Projects"
        "  Give me Zellij"
        "  Give me Bash"
        "  Quick SSH"
        "  System Maintenance"
    )
    _sm_run_menu "Choose your mission, Boss:" "${options[@]}"
    local choice=$?

    case $choice in
        0) SMART_MENU_ACTION="browse" ;;
        1) _sm_project_menu ;;
        2) SMART_MENU_ACTION="zellij" ;;
        3) SMART_MENU_ACTION="bash" ;;
        4) _sm_quick_ssh ;;
        5) SMART_MENU_ACTION="maintenance" ;;
    esac
}

# ─── Entry point ─────────────────────────────────────────────────────────────
if [[ $- == *i* ]]; then
    _sm_main_menu
fi
