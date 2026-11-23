#!/usr/bin/env bash
# shellcheck disable=SC1091
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Smart Bash — terminal banner                                                ║
# ║    bash terminal_banner_v2.sh          → header + system status (+ git)      ║
# ║    bash terminal_banner_v2.sh --stats  → status only (used in Zellij panes)  ║
# ║  Run it as a subprocess — nothing here leaks into your shell.                ║
# ║  Network / docker / update info comes from a cache refreshed in the          ║
# ║  background, so the banner never waits on the network.                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Name shown in the compact headers — override with SMART_BASH_TAG in ~/.bashrc.local
BANNER_TAG="${SMART_BASH_TAG:-GANESH@DEVOPS}"

QUOTES=(
    "Infrastructure is not magic — it's decisions with trade-offs."
    "Exit codes are not enough. Add health checks."
    "If it's not in version control, it doesn't exist."
    "A deploy without a tested rollback is a gamble."
    "I use Linux btw 😎"
    "There is no cloud, just someone else's computer."
    "It works on my machine ¯\_(ツ)_/¯"
    "Monitoring is not optional—it's insurance."
    "Every outage teaches what docs can't."
    "Logs are your conversation with the past."
    "Automation is just scripting with accountability."
    "Containers don’t remove complexity. They relocate it."
    "The bug was free. The downtime wasn’t."
    "A server without monitoring is a horror movie in slow motion."
    "SSH into prod enough times and eventually prod SSHs into your soul."
    "Backups are Schrödinger’s feature until restore is tested."
    "Scale exposes architecture lies."
    "If your infra diagram looks clean, it’s outdated."
    "Every sudo rm -rf starts with confidence."
    "YAML: where one space can destroy civilizations."
    "Kubernetes is what happens when engineers fear simplicity."
    "CI/CD without tests is just faster failure delivery."
    "The database remembers every bad decision."
    "Caching fixes performance and creates philosophy debates."
    "A 99.9% uptime SLA still allows chaos. Humans love decimals."
    "Temporary fixes have excellent survival rates."
    "Your future self is the real DevOps customer."
    "Permissions are easy until production says otherwise."
    "Infra as Code means your mistakes are now reproducible."
    "If alerts fire for everything, they matter for nothing."
    "The best optimization is deleting unnecessary systems."
    "Docker didn’t solve dependency hell. It containerized it."
    "Every manual step becomes tomorrow’s incident report."
    "Distributed systems are just computers refusing teamwork."
    "You don’t own uptime. You rent it from reality."
    "The more dashboards you have, the less anyone reads them."
    "A restart is not a root cause analysis."
    "Latency is just distance charging interest."
    "An unpatched server is basically a public challenge."
    "Real engineers fear silent failures more than loud crashes."
)
RANDOM_QUOTE="${QUOTES[$RANDOM % ${#QUOTES[@]}]}"

# ── Data collection (local reads are cheap; slow things come from the cache) ──
_banner_collect() {
    _sb_detect_env

    # Memory from /proc/meminfo (no fork); falls back to `free`
    MEM_PERCENT=0 MEM_USED="?" MEM_TOTAL="?"
    if [[ -r /proc/meminfo ]]; then
        local key val _ total=0 avail=0
        while read -r key val _; do
            case "$key" in
                MemTotal:)     total=$val ;;
                MemAvailable:) avail=$val ;;
            esac
        done < /proc/meminfo
        if (( total > 0 )); then
            MEM_PERCENT=$(( (total - avail) * 100 / total ))
            MEM_USED=$(_gib $(( total - avail )))
            MEM_TOTAL=$(_gib "$total")
        fi
    fi

    local _fs _size _used _avail _pct _mnt
    { read -r _; read -r _fs _size _used _avail _pct _mnt; } < <(df -hP / 2>/dev/null)
    DISK_TOTAL="${_size:-?}" DISK_USED="${_used:-?}" DISK_PERCENT="${_pct%\%}"
    DISK_PERCENT="${DISK_PERCENT:-0}"

    if [[ -r /proc/loadavg ]]; then read -r CPU_LOAD _ < /proc/loadavg
    else CPU_LOAD=$(uptime | awk -F'load average[s]?:' '{print $2}' | awk '{print $1}' | tr -d ','); fi
    CPU_CORES=$(nproc 2>/dev/null || echo 1)

    _sb_cached MYIP    myip    900  _sb_fetch_ip;  MYIP="${MYIP:-…}"
    _sb_cached WEATHER weather 1800 _sb_fetch_weather
    _sb_cached UPDATES updates 3600 _sb_fetch_updates
    _sb_cached DOCKER  docker  60   _sb_fetch_docker
}

# ── Pieces ────────────────────────────────────────────────────────────────────
_bar() {  # _bar <percent> → 20-cell bar (pure bash, no forks)
    local pct="$1" i out=""
    for (( i = 0; i < 20; i++ )); do
        if (( i < pct / 5 )); then out+="█"; else out+="░"; fi
    done
    printf '%s' "$out"
}

_gib() {  # _gib <KiB> → "4.1Gi"
    local tenths=$(( $1 * 10 / 1048576 ))
    printf '%d.%dGi' $(( tenths / 10 )) $(( tenths % 10 ))
}

_uptime_pretty() {  # sets UPTIME_S
    local secs _ d h m
    if [[ -r /proc/uptime ]]; then
        read -r secs _ < /proc/uptime; secs=${secs%.*}
        d=$(( secs / 86400 )); h=$(( secs % 86400 / 3600 )); m=$(( secs % 3600 / 60 ))
        UPTIME_S="up "
        (( d == 1 )) && UPTIME_S+="1 day, ";  (( d > 1 )) && UPTIME_S+="$d days, "
        (( h == 1 )) && UPTIME_S+="1 hour, "; (( h > 1 )) && UPTIME_S+="$h hours, "
        if (( m == 1 )); then UPTIME_S+="1 minute"; else UPTIME_S+="$m minutes"; fi
    else
        UPTIME_S=$(uptime | sed 's/.*up \([^,]*\),.*/up \1/')
    fi
}

_line() { echo -e "${SB_CYAN}├─${SB_RESET} $*${SB_RESET}"; }

_banner_header() {
    local rows="$1"
    if (( rows >= 30 )); then
        echo -e "${SB_NEON_PINK}"
        cat << 'EOF'
  ██████╗  █████╗ ███╗   ██╗███████╗███████╗██╗  ██╗
 ██╔════╝ ██╔══██╗████╗  ██║██╔════╝██╔════╝██║  ██║
 ██║  ███╗███████║██╔██╗ ██║█████╗  ███████╗███████║
 ██║   ██║██╔══██║██║╚██╗██║██╔══╝  ╚════██║██╔══██║
 ╚██████╔╝██║  ██║██║ ╚████║███████╗███████║██║  ██║
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═╝
EOF
        echo -e "${SB_RESET}"
        echo -e "  ${SB_DIM}${SB_CYAN}DevOps Engineer | System Thinker | Failure-Aware Architect${SB_RESET}"
        echo -e "${SB_DIM}${SB_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${SB_RESET}"
        echo -e "  ${SB_BOLD_YELLOW}💭  ${RANDOM_QUOTE}${SB_RESET}"
        echo ""
    elif (( rows >= 22 )); then
        echo -e "  ${SB_BOLD_CYAN}🤖 ${BANNER_TAG}${SB_RESET} ${SB_DIM}— DevOps Engineer | System Thinker${SB_RESET}"
        echo -e "  ${SB_BOLD_YELLOW}💭  ${RANDOM_QUOTE}${SB_RESET}"
        echo ""
    else
        echo -e "  ${SB_BOLD_CYAN}🤖 ${BANNER_TAG}${SB_RESET} ${SB_DIM}| ${SB_BOLD_YELLOW}💭  ${RANDOM_QUOTE}${SB_RESET}"
    fi
}

_banner_alerts() {
    local alerts=()
    (( MEM_PERCENT > 85 ))  && alerts+=("${SB_BOLD_YELLOW}🧠 Mem ${MEM_PERCENT}%${SB_RESET}")
    (( DISK_PERCENT > 85 )) && alerts+=("${SB_BOLD_YELLOW}💾 Disk ${DISK_PERCENT}%${SB_RESET}")
    if awk -v l="$CPU_LOAD" -v c="$CPU_CORES" 'BEGIN{exit !(l > c * 0.8)}'; then
        alerts+=("${SB_BOLD_YELLOW}⚡ CPU ${CPU_LOAD}${SB_RESET}")
    fi
    [[ "$UPDATES" =~ ^[0-9]+$ ]] && (( UPDATES > 0 )) && alerts+=("${SB_BOLD_YELLOW}📦 ${UPDATES} Updates Available${SB_RESET}")

    (( ${#alerts[@]} == 0 )) && return
    local joined="" a
    for a in "${alerts[@]}"; do joined+="${joined:+${SB_CYAN} | ${SB_RESET}}$a"; done
    echo -e "${SB_BOLD_CYAN}├─[ ⚠ ALERTS ]${SB_RESET}"
    _line "$joined"
    echo -e "${SB_CYAN}│${SB_RESET}"
}

_banner_git() {
    git -C "$PWD" rev-parse --is-inside-work-tree &>/dev/null || return
    local branch staged modified untracked
    branch=$(git -C "$PWD" branch --show-current 2>/dev/null)
    staged=$(git -C "$PWD" diff --cached --name-only 2>/dev/null | wc -l)
    modified=$(git -C "$PWD" diff --name-only 2>/dev/null | wc -l)
    untracked=$(git -C "$PWD" ls-files --others --exclude-standard 2>/dev/null | wc -l)
    echo -e "${SB_BOLD_CYAN}├─[ GIT REPOSITORY ]${SB_RESET}"
    echo -e "${SB_CYAN}│${SB_RESET}"
    _line "${SB_BOLD_GREEN}🌿  Branch   : ${branch}"
    _line "${SB_CYAN}   Staged   : ${staged} file(s)"
    _line "${SB_CYAN}   Modified : ${modified} file(s)"
    _line "${SB_CYAN}   Untracked: ${untracked} file(s)"
    echo -e "${SB_CYAN}│${SB_RESET}"
}

# _banner_status <with_git:0|1>
_banner_status() {
    local with_git="$1"
    echo -e "${SB_BOLD_MAGENTA}[Environment]${SB_RESET} ${SB_BOLD_WHITE}${SB_ENV_ICON} ${SB_ENV_NAME} ${SB_ENV_DETAIL}${SB_RESET}"
    echo ""
    echo -e "${SB_BOLD_CYAN}┌─[ SYSTEM STATUS ]${SB_RESET}"
    echo -e "${SB_CYAN}│${SB_RESET}"

    local now uptime_s os
    printf -v now '%(%A, %B %d %Y   🕐  %I:%M %p)T' -1
    _line "${SB_WHITE}📅  ${now}"

    _uptime_pretty; uptime_s="$UPTIME_S"
    _line "${SB_BOLD_GREEN}⏱️ Uptime: ${uptime_s}"

    if [[ -r /etc/os-release ]]; then os=$(. /etc/os-release && echo "$PRETTY_NAME"); else os=$(uname -s); fi
    local kernel; if [[ -r /proc/sys/kernel/osrelease ]]; then read -r kernel < /proc/sys/kernel/osrelease; else kernel=$(uname -r); fi
    _line "${SB_CYAN}💻  OS: ${os}"
    [[ -n "$WEATHER" ]] && _line "${SB_CYAN}⛅  Weather: ${WEATHER}"
    _line "${SB_CYAN}🔧  Kernel: ${kernel}"
    _line "${SB_CYAN}🐚  Shell: $SHELL"
    _line "${SB_CYAN}🌐  IP: ${MYIP}"
    _line "${SB_CYAN}🧠  Memory: ${MEM_USED} / ${MEM_TOTAL} ${SB_BOLD_GREEN}[$(_bar "$MEM_PERCENT")] ${MEM_PERCENT}%"

    local disk_color="$SB_BOLD_GREEN"; (( DISK_PERCENT > 80 )) && disk_color="$SB_BOLD_YELLOW"
    _line "${SB_CYAN}💾  Disk: ${DISK_USED} / ${DISK_TOTAL} ${disk_color}[$(_bar "$DISK_PERCENT")] ${DISK_PERCENT}%"
    _line "${SB_CYAN}⚡  CPU Load: ${CPU_LOAD}"
    _line "${SB_CYAN}👤  User: ${USER:-$(whoami)}@${HOSTNAME:-$(hostname)}"

    local procs=(/proc/[0-9]*)
    [[ -e "${procs[0]}" ]] && _line "${SB_CYAN}🔄  Processes: ${#procs[@]}"

    if [[ -n "$DOCKER" ]]; then
        local running stopped
        read -r running stopped <<< "$DOCKER"
        _line "${SB_CYAN}🐳  Docker: ${SB_BOLD_GREEN}${running} Running${SB_RESET} | ${SB_DIM}${stopped} Stopped"
    fi

    # Connection quality (SSH only)
    if [[ "$SB_ENV_NAME" == SSH ]]; then
        local latency
        latency=$(timeout 1 ping -c 1 8.8.8.8 2>/dev/null | awk -F'time=' '/time=/{print int($2)}')
        if [[ -n "$latency" ]]; then
            if   (( latency < 50 ));  then _line "${SB_BOLD_GREEN}✓ Excellent (${latency}ms)"
            elif (( latency < 150 )); then _line "${SB_BOLD_YELLOW}⚠ Good (${latency}ms)"
            else                           _line "${SB_BOLD_RED}⚠ Slow (${latency}ms)"
            fi
        fi
    fi

    echo -e "${SB_CYAN}│${SB_RESET}"
    _banner_alerts
    [[ "$with_git" == 1 ]] && _banner_git
    echo -e "${SB_BOLD_CYAN}└─────────────────────────────────────────────────────────${SB_RESET}"
    echo ""
}

# One line for tiny panes
_banner_oneline() {
    echo -e "${SB_BOLD_MAGENTA}[${SB_ENV_ICON} ${SB_ENV_NAME}]${SB_RESET} ${SB_CYAN}🧠 Mem: ${MEM_PERCENT}%${SB_RESET} | ${SB_CYAN}💾 Disk: ${DISK_PERCENT}%${SB_RESET} | ${SB_CYAN}⚡ CPU: ${CPU_LOAD}${SB_RESET} | ${SB_CYAN}🌐 IP: ${MYIP}${SB_RESET}"
    echo ""
}

# Stats-only view (no ASCII art) — used inside Zellij panes
_show_stats_only() {
    local rows; rows=$(tput lines 2>/dev/null || echo 24)
    _banner_collect
    echo ""
    echo -e "  ${SB_BOLD_YELLOW}💭  ${RANDOM_QUOTE}${SB_RESET}"
    if (( rows >= 22 )); then
        echo ""
        _banner_status 0
    else
        _banner_oneline
    fi
}

_show_full_banner() {
    local rows; rows=$(tput lines 2>/dev/null || echo 24)
    _banner_collect
    _banner_header "$rows"
    if (( rows >= 22 )); then
        _banner_status 1
    else
        _banner_oneline
    fi
}

# ── Entry point ───────────────────────────────────────────────────────────────
# (TERMINAL_BANNER_FUNCTIONS_ONLY=1 kept for older ~/.bashrc files that source
#  this and call _show_stats_only themselves.)
if [[ "${TERMINAL_BANNER_FUNCTIONS_ONLY:-0}" != "1" ]]; then
    case "${1:-}" in
        --stats) _show_stats_only ;;
        *)       _show_full_banner ;;
    esac
fi
