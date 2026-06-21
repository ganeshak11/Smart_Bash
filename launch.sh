#!/bin/bash

# ─── Smart Menu Launcher ──────────────────────────────────────────────────────
# Reads SMART_MENU_* exports from smart_menu.sh and launches the right thing.
# Sourced from ~/.bashrc after smart_menu.sh runs.

ZELLIJ_LAYOUTS="$HOME/.config/zellij/layouts"

# ─── Editor launcher ─────────────────────────────────────────────────────────
_sm_launch_editor() {
    local dir="$1"
    [[ -z "$dir" ]] && return
    case "$SMART_MENU_EDITOR" in
        antigravity)
            nohup antigravity "$dir" > /dev/null 2>&1 &
            disown
            ;;
        code)
            nohup code "$dir" > /dev/null 2>&1 &
            disown
            ;;
        cursor)
            nohup cursor "$dir" > /dev/null 2>&1 &
            disown
            ;;
        none|"") ;;
    esac
}

# ─── Dynamic KDL generators ──────────────────────────────────────────────────
# Zellij does NOT expand shell vars in static KDL files,
# so we generate a temp KDL with real paths baked in at runtime.

_gen_kdl_fortis() {
    local proj_dir="$1"
    local backend_dir="$proj_dir/backend"
    local frontend_dir="$proj_dir/frontend"
    local tab_name
    tab_name=$(basename "$proj_dir" | tr '[:lower:]' '[:upper:]')

    # Fallback if subdirs don't exist
    [[ -d "$backend_dir" ]] || backend_dir="$proj_dir"
    [[ -d "$frontend_dir" ]] || frontend_dir="$proj_dir"

    cat << EOF
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=1 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="$tab_name" {
        pane split_direction="vertical" {
            pane split_direction="horizontal" {
                pane size="50%" cwd="$proj_dir" {
                    focus true
                }
                pane size="50%" cwd="$backend_dir" {}
            }
            pane split_direction="horizontal" {
                pane size="50%" cwd="$backend_dir" {}
                pane size="50%" cwd="$frontend_dir" {}
            }
        }
    }
}
EOF
}

_gen_kdl_generic() {
    local proj_dir="$1"
    local tab_name
    tab_name=$(basename "$proj_dir" | tr '[:lower:]' '[:upper:]')

    cat << EOF
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=1 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="$tab_name" {
        pane split_direction="vertical" {
            pane cwd="$proj_dir" {
                focus true
            }
            pane cwd="$proj_dir" {}
        }
    }
}
EOF
}

# ─── Dispatcher ──────────────────────────────────────────────────────────────
case "$SMART_MENU_ACTION" in

    browse)
        clear
        export SMART_MENU_SHOW_STATS=1
        echo -e "\e[1;36m🌐 Opening Brave & launching Hacker mode...\e[0m"
        export SMART_MENU_ACTION=""  # Reset BEFORE spawning Brave/Zellij so child shells don't re-trigger

        # If Brave is already running, just focus it — don't open a new window.
        # If it's not running, launch it fresh so Brave restores your last session.
        if pgrep -f "brave-browser" > /dev/null 2>&1; then
            wmctrl -a "Brave" 2>/dev/null \
                || xdotool search --name "Brave" windowactivate 2>/dev/null \
                || true  # silently skip if neither tool is available
        else
            nohup brave-browser > /dev/null 2>&1 &
            disown
        fi

        sleep 0.3
        zellij --layout "$ZELLIJ_LAYOUTS/hacker.kdl"
        if [[ $? -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij failed to launch.\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    project)
        clear
        export SMART_MENU_SHOW_STATS=0
        local_session_name=$(basename "$SMART_MENU_PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        echo -e "\e[1;32m🚀 Launching: \e[1;37m$(basename "$SMART_MENU_PROJECT_DIR")\e[0m"
        echo -e "\e[2m   Layout  : $SMART_MENU_LAYOUT\e[0m"
        echo -e "\e[2m   Editor  : ${SMART_MENU_EDITOR:-none}\e[0m"
        echo -e "\e[2m   Session : $local_session_name\e[0m"

        # Launch editor first in background
        _sm_launch_editor "$SMART_MENU_PROJECT_DIR"

        # Generate dynamic KDL with real paths baked in
        local_tmp_kdl=$(mktemp /tmp/zellij-XXXXXX.kdl)
        case "$SMART_MENU_LAYOUT" in
            fortis-ci|cicd-sentinel)
                _gen_kdl_fortis "$SMART_MENU_PROJECT_DIR" > "$local_tmp_kdl"
                ;;
            *)
                _gen_kdl_generic "$SMART_MENU_PROJECT_DIR" > "$local_tmp_kdl"
                ;;
        esac

        sleep 0.3

        # Reset BEFORE spawning Zellij so child shells don't re-trigger the project launch
        export SMART_MENU_ACTION=""

        # Purge ALL dead sessions to prevent pile-up
        zellij list-sessions 2>/dev/null \
            | grep 'EXITED' \
            | awk '{print $1}' \
            | xargs -r -I{} zellij delete-session {} -f 2>/dev/null

        # Check if an alive session with our name survived the purge
        alive_session=$(zellij list-sessions 2>/dev/null \
            | grep -E "^${local_session_name}[[:space:]]" \
            | grep -v 'EXITED' \
            | head -1)

        if [[ -n "$alive_session" ]]; then
            # Alive session — just attach
            rm -f "$local_tmp_kdl"
            zellij attach "$local_session_name"
            zellij_exit=$?
        else
            # No alive session — create fresh
            zellij -s "$local_session_name" -n "$local_tmp_kdl"
            zellij_exit=$?
        fi

        rm -f "$local_tmp_kdl"
        if [[ $zellij_exit -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij exited with error ($zellij_exit).\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    zellij)
        clear
        export SMART_MENU_SHOW_STATS=1
        echo -e "\e[1;35m⚡ Launching Zellij...\e[0m"
        export SMART_MENU_ACTION=""  # Reset BEFORE spawning Zellij so child shells don't re-trigger
        sleep 0.2
        zellij --layout "$ZELLIJ_LAYOUTS/hacker.kdl"
        if [[ $? -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij failed to launch.\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    bash)
        clear
        export SMART_MENU_SHOW_STATS=0
        source "$HOME/Smart_Bash/terminal_banner_v2.sh"
        ;;

    ssh)
        clear
        echo -e "\e[1;32m🔌 Connecting to $SMART_MENU_SSH_HOST...\e[0m"
        ssh "$SMART_MENU_SSH_HOST"
        ;;

    maintenance)
        clear
        echo -e "\e[1;36m🧹 Running System Maintenance...\e[0m"
        sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
        echo -e "\e[1;32m✅ Maintenance complete.\e[0m"
        read -r -p "Press any key to continue..." -n 1
        clear
        ;;

esac

# Reset so it doesn't fire again on shell reload
export SMART_MENU_ACTION=""
