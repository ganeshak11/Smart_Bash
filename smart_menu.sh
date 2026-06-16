#!/bin/bash

# ─── Smart Menu Configuration ────────────────────────────────────────────────
CONFIG_FILE="$HOME/.smart_menu.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat << 'EOF' > "$CONFIG_FILE"
# Smart Menu Configuration
SMART_MENU_DEV_DIRS=("$HOME/dev" "$HOME/dev/HACKHAZARD" "$HOME/dev/Decvb")
SMART_MENU_EDITORS=("VS Code:code" "Cursor:cursor" "Antigravity:antigravity" "None (Just cd to dir):none")
EOF
fi
source "$CONFIG_FILE"

# ─── Known projects → layout mapping ─────────────────────────────────────────
# Key: lowercase folder name  Value: layout filename (no .kdl)
declare -A KNOWN_PROJECT_LAYOUTS=(
    ["fortis-ci"]="fortis-ci"
    ["cicd-sentinel"]="cicd-sentinel"
)

# ─── Colors ───────────────────────────────────────────────────────────────────
DIM='\e[2m'
CYAN='\e[36m'
BOLD_CYAN='\e[1;36m'
YELLOW='\e[33m'
BOLD_YELLOW='\e[1;33m'
GREEN='\e[32m'
BOLD_GREEN='\e[1;32m'
MAGENTA='\e[35m'
BOLD_MAGENTA='\e[1;35m'
WHITE='\e[37m'
BOLD_WHITE='\e[1;37m'
RED='\e[31m'
BOLD_RED='\e[1;31m'
RESET='\e[0m'
CLEAR_LINE='\e[K'

# ─── Cursor helpers ───────────────────────────────────────────────────────────
cursor_up() {
    tput cuu $1 2>/dev/null || echo -ne "\e[${1}A"
}

# ─── draw_menu ────────────────────────────────────────────────────────────────
draw_menu() {
    local title="$1"
    local selected="$2"
    shift 2
    local options=("$@")

    echo -e "${BOLD_MAGENTA}HI Boss, What are you doing today?${RESET}${CLEAR_LINE}"
    echo -e "${DIM}${CYAN}$title${RESET}${CLEAR_LINE}"
    echo -e "${CLEAR_LINE}"

    for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
            echo -e "  ${BOLD_GREEN}❯ ${options[$i]}${RESET}${CLEAR_LINE}"
        else
            echo -e "    ${WHITE}${options[$i]}${RESET}${CLEAR_LINE}"
        fi
    done
}

# ─── run_menu ─────────────────────────────────────────────────────────────────
run_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local count=${#options[@]}
    local lines_to_clear=$(( count + 3 ))

    for ((i=0; i<lines_to_clear; i++)); do echo ""; done
    cursor_up $lines_to_clear

    while true; do
        draw_menu "$title" "$selected" "${options[@]}"

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

        cursor_up $lines_to_clear
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
editor_picker() {
    local editor_names=()
    local editor_cmds=()
    for ed in "${SMART_MENU_EDITORS[@]}"; do
        editor_names+=("${ed%%:*}")
        editor_cmds+=("${ed##*:}")
    done
    run_menu "Open project with which editor?" "${editor_names[@]}"
    local ed_choice=$?
    export SMART_MENU_EDITOR="${editor_cmds[$ed_choice]}"
}

# ─── Project menu ─────────────────────────────────────────────────────────────
project_menu() {
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

    run_menu "Select a project to dive into:" "${options[@]}"
    local choice=$?

    local num_recent=${#recent_dirs[@]}

    if [[ $choice -lt $num_recent ]]; then
        SMART_MENU_PROJECT_DIR="${project_paths[$choice]}"
        local proj_key
        proj_key=$(basename "${project_paths[$choice]}" | tr '[:upper:]' '[:lower:]')
        if [[ -n "${KNOWN_PROJECT_LAYOUTS[$proj_key]}" ]]; then
            SMART_MENU_LAYOUT="${KNOWN_PROJECT_LAYOUTS[$proj_key]}"
        else
            SMART_MENU_LAYOUT="generic-project"
        fi
        editor_picker
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
            if [[ -n "${KNOWN_PROJECT_LAYOUTS[$proj_key]}" ]]; then
                SMART_MENU_LAYOUT="${KNOWN_PROJECT_LAYOUTS[$proj_key]}"
            else
                SMART_MENU_LAYOUT="generic-project"
            fi
            editor_picker
            SMART_MENU_ACTION="project"
        else
            project_menu
        fi

    elif [[ $choice -eq $((num_recent + 1)) ]]; then
        local default_dev="${SMART_MENU_DEV_DIRS[0]:-$HOME/dev}"
        local new_opts=("Create empty project locally" "Clone from remote repository" "< Cancel")
        run_menu "How do you want to start?" "${new_opts[@]}"
        local new_choice=$?

        if [[ $new_choice -eq 0 ]]; then
            echo -e "${BOLD_YELLOW}Enter new project name (in ${default_dev}):${RESET}"
            read -r proj_name
            if [[ -n "$proj_name" ]]; then
                local new_dir="${default_dev}/$proj_name"
                mkdir -p "$new_dir"
                SMART_MENU_PROJECT_DIR="$new_dir"
                SMART_MENU_LAYOUT="generic-project"
                editor_picker
                SMART_MENU_ACTION="project"
            else
                project_menu
            fi
        elif [[ $new_choice -eq 1 ]]; then
            echo -e "${BOLD_YELLOW}Enter Git repository URL to clone:${RESET}"
            read -r repo_url
            if [[ -n "$repo_url" ]]; then
                local proj_name
                proj_name=$(basename "$repo_url" .git)
                local new_dir="${default_dev}/$proj_name"
                echo -e "${BOLD_CYAN}Cloning into $new_dir...${RESET}"
                git clone "$repo_url" "$new_dir"
                if [[ $? -eq 0 ]]; then
                    SMART_MENU_PROJECT_DIR="$new_dir"
                    SMART_MENU_LAYOUT="generic-project"
                    editor_picker
                    SMART_MENU_ACTION="project"
                else
                    echo -e "${BOLD_RED}Clone failed.${RESET}"
                    read -r -p "Press any key to continue..." -n 1
                    project_menu
                fi
            else
                project_menu
            fi
        else
            main_menu
        fi
    else
        main_menu
    fi
}

# ─── SSH picker ───────────────────────────────────────────────────────────────
quick_ssh() {
    local ssh_config="$HOME/.ssh/config"
    local hosts=""
    if [[ -f "$ssh_config" ]]; then
        hosts=$(grep -i '^Host ' "$ssh_config" | awk '{print $2}' | grep -v '*')
    fi

    local selected_host
    if [[ -n "$hosts" ]]; then
        selected_host=$(echo "$hosts" | fzf --prompt="🔌 Select SSH Host: " --height=40% --layout=reverse --border=rounded)
    else
        echo -e "${BOLD_YELLOW}No hosts found in ~/.ssh/config.${RESET}"
        read -e -p $'\e[1;36m❯ Enter SSH destination (user@host): \e[0m' selected_host
    fi

    if [[ -n "$selected_host" ]]; then
        export SMART_MENU_ACTION="ssh"
        export SMART_MENU_SSH_HOST="$selected_host"
    else
        main_menu
    fi
}

# ─── Main menu ────────────────────────────────────────────────────────────────
main_menu() {
    local options=(
        "  Casual Browsing"
        "  Projects"
        "  Give me Zellij"
        "  Give me Bash"
        "  Quick SSH"
        "  System Maintenance"
    )
    run_menu "Choose your mission, Boss:" "${options[@]}"
    local choice=$?

    case $choice in
        0) SMART_MENU_ACTION="browse" ;;
        1) project_menu ;;
        2) SMART_MENU_ACTION="zellij" ;;
        3) SMART_MENU_ACTION="bash" ;;
        4) quick_ssh ;;
        5) SMART_MENU_ACTION="maintenance" ;;
    esac
}

# ─── Entry point ─────────────────────────────────────────────────────────────
if [[ $- == *i* ]]; then
    main_menu
fi
