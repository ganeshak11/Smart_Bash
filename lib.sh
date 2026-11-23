#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Smart Bash — shared library                                                 ║
# ║  Sourced by bashrc.sh and by every script. Everything defined here is        ║
# ║  namespaced (SB_* / _sb_*) so it is safe to live in an interactive shell.    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
# shellcheck disable=SC2034  # colours are used by the scripts that source this

SMART_BASH_DIR="${SMART_BASH_DIR:-$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
SB_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/smart_bash"
SB_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/smart_bash"

# ── Colours ───────────────────────────────────────────────────────────────────
SB_RESET=$'\e[0m'
SB_DIM=$'\e[2m'
SB_CLEAR_LINE=$'\e[K'
SB_RED=$'\e[0;31m';     SB_BOLD_RED=$'\e[1;31m'
SB_GREEN=$'\e[0;32m';   SB_BOLD_GREEN=$'\e[1;32m'
SB_YELLOW=$'\e[0;33m';  SB_BOLD_YELLOW=$'\e[1;33m'
SB_MAGENTA=$'\e[0;35m'; SB_BOLD_MAGENTA=$'\e[1;35m'
SB_CYAN=$'\e[0;36m';    SB_BOLD_CYAN=$'\e[1;36m'
SB_WHITE=$'\e[0;37m';   SB_BOLD_WHITE=$'\e[1;37m'
SB_NEON_GREEN=$'\e[38;5;46m'
SB_NEON_PINK=$'\e[38;5;201m'

# Shared fzf look for all the menus
SB_FZF_COLORS="prompt:cyan,pointer:yellow,hl:green,border:cyan,header:bright-cyan"

# ── Small helpers ─────────────────────────────────────────────────────────────
_sb_has() { command -v "$1" &>/dev/null; }


# ── Cache ─────────────────────────────────────────────────────────────────────
# _sb_cached <var> <key> <ttl-seconds> <command...>
#   Puts the last cached output of <command> into <var> immediately — never
#   blocks on the network. When the value is missing or older than <ttl>, a
#   refresh runs in the background so the next call is fresh. A failed refresh
#   keeps the old value. File format: line 1 = epoch stamp, rest = value.
#   Uses only builtins on the hot path (no forks), so it is cheap to call.
_sb_cached() {
    local __sb_var="$1" key="$2" ttl="$3"; shift 3
    local file="$SB_CACHE_DIR/$key" stamp="" value="" now
    printf -v now '%(%s)T' -1

    if [[ -r "$file" ]]; then
        { IFS= read -r stamp; IFS= read -r -d '' value; } < "$file"
        value="${value%$'\n'}"
    fi

    if [[ ! "$stamp" =~ ^[0-9]+$ ]] || (( now - stamp >= ttl )); then
        [[ -d "$SB_CACHE_DIR" ]] || command mkdir -p "$SB_CACHE_DIR" 2>/dev/null || { printf -v "$__sb_var" '%s' "$value"; return 0; }
        # Re-stamp first so parallel shells don't all start the same refresh
        printf '%s\n%s\n' "$now" "$value" > "$file" 2>/dev/null
        # Double fork: no job-control noise in interactive shells
        ( (
            out=$("$@" 2>/dev/null) && [[ -n "$out" ]] || exit 0
            tmp="$file.tmp.$BASHPID"
            printf -v ts '%(%s)T' -1
            printf '%s\n%s\n' "$ts" "$out" > "$tmp" && mv -f "$tmp" "$file"
        ) &>/dev/null & )
    fi
    printf -v "$__sb_var" '%s' "$value"
}

# Fetchers used with _sb_cached
_sb_fetch_ip()      { curl -s --max-time 3 https://api.ipify.org; }
_sb_fetch_weather() {
    local w; w=$(curl -s --max-time 3 "wttr.in/?format=3") || return 1
    [[ -n "$w" && "$w" != *Unknown* && "$w" != *"<"* ]] && echo "$w"
}
_sb_fetch_docker() {
    _sb_has docker || return 1
    timeout 3 docker info &>/dev/null || return 1
    local running total
    running=$(docker ps -q | wc -l)
    total=$(docker ps -aq | wc -l)
    echo "$running $(( total - running ))"
}
_sb_fetch_updates() {
    case "$(_sb_pkg_manager)" in
        apt-get) apt-get -s upgrade 2>/dev/null | grep -c '^Inst' ;;
        dnf)     dnf -q check-update 2>/dev/null | grep -c '^[[:alnum:]]' ;;
        pacman)  if _sb_has checkupdates; then checkupdates 2>/dev/null | wc -l; else return 1; fi ;;
        zypper)  zypper -q lu 2>/dev/null | grep -c '^v ' ;;
        brew)    brew outdated -q 2>/dev/null | wc -l ;;
        *)       return 1 ;;
    esac
}

# ── Package managers ──────────────────────────────────────────────────────────
_sb_pkg_manager() {
    local pm
    for pm in apt-get dnf pacman zypper brew; do
        _sb_has "$pm" && { echo "$pm"; return 0; }
    done
    return 1
}

# _sb_pkg_install <pkg...>
_sb_pkg_install() {
    case "$(_sb_pkg_manager)" in
        apt-get) sudo apt-get install -y "$@" ;;
        dnf)     sudo dnf install -y "$@" ;;
        pacman)  sudo pacman -S --noconfirm --needed "$@" ;;
        zypper)  sudo zypper -n install "$@" ;;
        brew)    brew install "$@" ;;
        *)       echo "No supported package manager found (apt, dnf, pacman, zypper, brew)." >&2; return 1 ;;
    esac
}

_sb_pkg_upgrade_all() {
    case "$(_sb_pkg_manager)" in
        apt-get) sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y ;;
        dnf)     sudo dnf upgrade -y && sudo dnf autoremove -y ;;
        pacman)  sudo pacman -Syu --noconfirm ;;
        zypper)  sudo zypper -n refresh && sudo zypper -n update ;;
        brew)    brew update && brew upgrade && brew cleanup ;;
        *)       echo "No supported package manager found." >&2; return 1 ;;
    esac
}

# ── Environment detection (computed once, not on every prompt) ────────────────
# Sets SB_ENV_NAME, SB_ENV_ICON, SB_ENV_COLOR and SB_ENV_DETAIL
_sb_detect_env() {
    local vendor="" host=""
    [[ -r /sys/class/dmi/id/sys_vendor ]] && read -r vendor < /sys/class/dmi/id/sys_vendor
    SB_ENV_DETAIL=""
    if [[ $EUID -eq 0 ]]; then
        SB_ENV_NAME="ROOT";   SB_ENV_ICON="🔒"; SB_ENV_COLOR=$'\e[1;31m'
    elif [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ]]; then
        SB_ENV_NAME="SSH";    SB_ENV_ICON="📡"; SB_ENV_COLOR=$'\e[38;5;51m'
        SB_ENV_DETAIL="from ${SSH_CONNECTION%% *}"
    elif [[ -f /.dockerenv ]]; then
        SB_ENV_NAME="DOCKER"; SB_ENV_ICON="🐳"; SB_ENV_COLOR=$'\e[38;5;33m'
        [[ -r /etc/hostname ]] && read -r host < /etc/hostname
        SB_ENV_DETAIL="[${host:0:12}]"
    elif [[ "$vendor" =~ (VirtualBox|VMware|KVM|Hyper-V|QEMU) ]]; then
        SB_ENV_NAME="VM";     SB_ENV_ICON="💾"; SB_ENV_COLOR=$'\e[38;5;208m'
        SB_ENV_DETAIL="[${BASH_REMATCH[1]}]"
    else
        SB_ENV_NAME="LOCAL";  SB_ENV_ICON="💻"; SB_ENV_COLOR=$'\e[38;5;213m'
    fi
}

# ── On/off switches (managed with `sb on|off <feature>`) ─────────────────────
# _sb_enabled <feature> → true unless "$SB_CONFIG_DIR/<feature>.off" exists
_sb_enabled() { [[ ! -e "$SB_CONFIG_DIR/$1.off" ]]; }
