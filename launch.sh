#!/bin/bash

# ─── Smart Menu Launcher ──────────────────────────────────────────────────────
# Reads SMART_MENU_* exports from smart_menu.sh and launches the right thing.
# Sourced from ~/.bashrc after smart_menu.sh runs.

_SM_ZELLIJ_LAYOUTS="$HOME/.config/zellij/layouts"

# ─── Editor launcher ─────────────────────────────────────────────────────────
# Terminal editors (nvim, vim, ...) can't be backgrounded with nohup — they are
# opened inside the focused Zellij pane instead (see _kdl_main_pane).
_sm_is_tui_editor() {
    case "$1" in
        nvim|vim|vi|nano|hx|helix|micro) return 0 ;;
        *) return 1 ;;
    esac
}

_sm_launch_editor() {
    local dir="$1"
    [[ -z "$dir" ]] && return
    local ed="$SMART_MENU_EDITOR"
    [[ -z "$ed" || "$ed" == "none" ]] && return
    _sm_is_tui_editor "$ed" && return   # handled by the Zellij layout
    if command -v "$ed" &>/dev/null; then
        nohup "$ed" "$dir" > /dev/null 2>&1 &
        disown
    else
        echo -e "\e[1;33m⚠️  Editor '$ed' not found in PATH — skipping.\e[0m"
    fi
}

# Main (focused) pane: runs a terminal editor if one was picked, else a shell.
_kdl_main_pane() {
    local dir="$1" size_attr="$2"
    if _sm_is_tui_editor "$SMART_MENU_EDITOR" && command -v "$SMART_MENU_EDITOR" &>/dev/null; then
        cat << EOF
pane ${size_attr}cwd="$dir" command="$SMART_MENU_EDITOR" focus=true {
    args "."
}
EOF
    else
        cat << EOF
pane ${size_attr}cwd="$dir" {
    focus true
}
EOF
    fi
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
$(_kdl_main_pane "$proj_dir" 'size="50%" ' | sed 's/^/                /')
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
$(_kdl_main_pane "$proj_dir" "" | sed 's/^/            /')
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
        zellij --layout "$_SM_ZELLIJ_LAYOUTS/hacker.kdl"
        if [[ $? -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij failed to launch.\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    project)
        clear
        export SMART_MENU_SHOW_STATS=0
        _sm_session=$(basename "$SMART_MENU_PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        echo -e "\e[1;32m🚀 Launching: \e[1;37m$(basename "$SMART_MENU_PROJECT_DIR")\e[0m"
        echo -e "\e[2m   Layout  : $SMART_MENU_LAYOUT\e[0m"
        echo -e "\e[2m   Editor  : ${SMART_MENU_EDITOR:-none}\e[0m"
        echo -e "\e[2m   Session : $_sm_session\e[0m"

        # Launch editor first in background
        _sm_launch_editor "$SMART_MENU_PROJECT_DIR"

        # Generate dynamic KDL with real paths baked in
        _sm_tmp_kdl=$(mktemp "${TMPDIR:-/tmp}/zellij-XXXXXX.kdl")
        case "$SMART_MENU_LAYOUT" in
            fortis-ci|cicd-sentinel)
                _gen_kdl_fortis "$SMART_MENU_PROJECT_DIR" > "$_sm_tmp_kdl"
                ;;
            *)
                _gen_kdl_generic "$SMART_MENU_PROJECT_DIR" > "$_sm_tmp_kdl"
                ;;
        esac

        sleep 0.3

        # Reset BEFORE spawning Zellij so child shells don't re-trigger the project launch
        export SMART_MENU_ACTION=""

        # Clear only THIS project's dead session (if any) so it can be recreated.
        # Other projects' exited sessions are left alone — they stay resurrectable.
        zellij list-sessions --no-formatting 2>/dev/null \
            | grep -E "^${_sm_session}[[:space:]].*EXITED" \
            | awk '{print $1}' \
            | xargs -r -I{} zellij delete-session {} -f 2>/dev/null

        # Check if an alive session with our name survived the purge
        _sm_alive=$(zellij list-sessions --no-formatting 2>/dev/null \
            | grep -E "^${_sm_session}[[:space:]]" \
            | grep -v 'EXITED' \
            | head -1)

        if [[ -n "$_sm_alive" ]]; then
            # Alive session — just attach
            rm -f "$_sm_tmp_kdl"
            zellij attach "$_sm_session"
            _sm_zexit=$?
        else
            # No alive session — create fresh
            zellij -s "$_sm_session" -n "$_sm_tmp_kdl"
            _sm_zexit=$?
        fi

        rm -f "$_sm_tmp_kdl"
        if [[ $_sm_zexit -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij exited with error ($_sm_zexit).\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    zellij)
        clear
        export SMART_MENU_SHOW_STATS=1
        echo -e "\e[1;35m⚡ Launching Zellij...\e[0m"
        export SMART_MENU_ACTION=""  # Reset BEFORE spawning Zellij so child shells don't re-trigger
        sleep 0.2
        zellij --layout "$_SM_ZELLIJ_LAYOUTS/hacker.kdl"
        if [[ $? -ne 0 ]]; then
            echo -e "\e[1;31m\u274c Zellij failed to launch.\e[0m"
            read -r -p "Press any key to continue..." -n 1
        fi
        ;;

    bash)
        clear
        export SMART_MENU_SHOW_STATS=0
        bash "$SMART_BASH_DIR/terminal_banner_v2.sh"
        ;;

    ssh)
        clear
        echo -e "\e[1;32m🔌 Connecting to $SMART_MENU_SSH_HOST...\e[0m"
        ssh "$SMART_MENU_SSH_HOST"
        ;;

    maintenance)
        clear
        echo -e "\e[1;36m🧹 Running System Maintenance...\e[0m"
        if _sb_pkg_upgrade_all; then
            echo -e "\e[1;32m✅ Maintenance complete.\e[0m"
        else
            echo -e "\e[1;31m❌ Maintenance failed (see above).\e[0m"
        fi
        read -r -p "Press any key to continue..." -n 1
        clear
        ;;

esac

# Reset so it doesn't fire again on shell reload
export SMART_MENU_ACTION=""
unset _sm_session _sm_tmp_kdl _sm_alive _sm_zexit
