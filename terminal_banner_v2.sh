#!/bin/bash

# Colors
CYAN='\033[0;36m'
BOLD_CYAN='\033[1;36m'
BOLD_YELLOW='\033[1;33m'
BOLD_GREEN='\033[1;32m'
BOLD_WHITE='\033[1;37m'
BOLD_MAGENTA='\033[1;35m'
BOLD_RED='\033[1;31m'
DIM='\033[2m'
RESET='\033[0m'
NEON_GREEN='\033[38;5;46m'
NEON_PINK='\033[38;5;201m'
WHITE='\033[0;37m'

# Random hacker quotes
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

# Get terminal dimensions
TERM_ROWS=$(tput lines 2>/dev/null || echo 24)

# Environment detection helper
_DETECT_ENV_BANNER() {
    local env_info=""
    if [[ $EUID -eq 0 ]]; then
        env_info="🔒 ROOT MODE"
    elif [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
        local remote_ip=$(echo $SSH_CONNECTION | awk '{print $3}')
        env_info="📡 SSH from $remote_ip"
    elif [ -f /.dockerenv ]; then
        local container_id=$(cat /etc/hostname 2>/dev/null | head -c 12)
        env_info="🐳 DOCKER [$container_id]"
    elif grep -qi "VirtualBox\|VMware\|KVM\|Hyper-V\|QEMU" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        local vm_type=$(grep -oE 'VirtualBox|VMware|KVM|Hyper-V|QEMU' /sys/class/dmi/id/sys_vendor | head -1)
        env_info="💾 VM [$vm_type]"
    else
        env_info="💻 LOCAL MACHINE"
    fi
    echo "$env_info"
}

# Smart Alerts helper
_CHECK_ALERTS() {
    local alerts_found=0
    local alert_line=""
    
    # Check memory
    local MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$MEM_PCT" -gt 85 ]; then
        alert_line="${alert_line}${BOLD_YELLOW}🧠 Mem ${MEM_PCT}%${RESET}"
        alerts_found=1
    fi
    
    # Check disk
    local DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$DISK_PCT" -gt 85 ]; then
        if [ -n "$alert_line" ]; then
            alert_line="${alert_line}${CYAN} | ${RESET}"
        fi
        alert_line="${alert_line}${BOLD_YELLOW}💾 Disk ${DISK_PCT}%${RESET}"
        alerts_found=1
    fi
    
    # Check CPU load
    local CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local CPU_CORES=$(nproc 2>/dev/null || echo 1)
    if (( $(echo "$CPU_LOAD > $CPU_CORES * 0.8" | bc -l 2>/dev/null) )); then
        if [ -n "$alert_line" ]; then
            alert_line="${alert_line}${CYAN} | ${RESET}"
        fi
        alert_line="${alert_line}${BOLD_YELLOW}⚡ CPU ${CPU_LOAD}${RESET}"
        alerts_found=1
    fi
    
    # Check apt updates (fast cached check)
    local updates=0
    if [ -f /var/lib/update-notifier/updates-available ]; then
        updates=$(awk '/packages can be updated/ {print $1}' /var/lib/update-notifier/updates-available 2>/dev/null || echo 0)
    else
        local cache_file="/tmp/.apt_updates_count"
        if [ ! -f "$cache_file" ] || [ -n "$(find "$cache_file" -mmin +60 2>/dev/null)" ]; then
            touch "$cache_file"
            ( apt-get -s upgrade 2>/dev/null | grep -oP '\d+(?= upgraded)' > "$cache_file" ) & disown
        fi
        if [ -s "$cache_file" ]; then
            updates=$(cat "$cache_file" 2>/dev/null || echo 0)
        fi
    fi

    if [[ "$updates" =~ ^[0-9]+$ ]] && [ "$updates" -gt 0 ]; then
        if [ -n "$alert_line" ]; then
            alert_line="${alert_line}${CYAN} | ${RESET}"
        fi
        alert_line="${alert_line}${BOLD_YELLOW}📦 ${updates} Updates Available${RESET}"
        alerts_found=1
    fi

    if [ $alerts_found -eq 1 ]; then
        echo -e "${BOLD_CYAN}├─[ ⚠ ALERTS ]${RESET}"
        echo -e "${CYAN}├─${RESET} ${alert_line}"
        echo -e "${CYAN}│${RESET}"
    fi
}

# ─── Stats-only view (no ASCII art) — used by Zellij / Browse ────────────────
_show_stats_only() {
    local TERM_ROWS_LOCAL
    TERM_ROWS_LOCAL=$(tput lines 2>/dev/null || echo 24)

    echo ""
    if [ "$TERM_ROWS_LOCAL" -ge 22 ]; then
        echo -e "  ${BOLD_YELLOW}💭  ${RANDOM_QUOTE}${RESET}"
        echo ""

        ENV_INFO=$(_DETECT_ENV_BANNER)
        echo -e "${BOLD_MAGENTA}[Environment]${RESET} ${BOLD_WHITE}${ENV_INFO}${RESET}"
        echo ""

        echo -e "${BOLD_CYAN}┌─[ SYSTEM STATUS ]${RESET}"
        echo -e "${CYAN}│${RESET}"

        echo -e "${CYAN}├─${RESET} ${WHITE}📅  $(date '+%A, %B %d %Y')   🕐  $(date '+%I:%M %p')${RESET}"

        local UPTIME
        UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6"h "$7"m"}')
        echo -e "${CYAN}├─${RESET} ${BOLD_GREEN}⏱️ Uptime: ${UPTIME}${RESET}"

        local OS
        OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
        echo -e "${CYAN}├─${RESET} ${CYAN}💻  OS: ${OS}${RESET}"

        local WEATHER
        WEATHER=$(curl -s --max-time 1 "wttr.in/?format=3" 2>/dev/null)
        if [ -n "$WEATHER" ] && [[ ! "$WEATHER" =~ "Unknown" ]]; then
            echo -e "${CYAN}├─${RESET} ${CYAN}⛅  Weather: ${WEATHER}${RESET}"
        fi

        echo -e "${CYAN}├─${RESET} ${CYAN}🔧  Kernel: $(uname -r)${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}🐚  Shell: $SHELL${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}🌐  IP: ${myip}${RESET}"

        local MEM_USED MEM_TOTAL MEM_PERCENT MEM_BAR MEM_EMPTY
        MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
        MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
        MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
        MEM_BAR=$(printf '█%.0s' $(seq 1 $((MEM_PERCENT/5))) 2>/dev/null)
        MEM_EMPTY=$(printf '░%.0s' $(seq 1 $((20-MEM_PERCENT/5))) 2>/dev/null)
        echo -e "${CYAN}├─${RESET} ${CYAN}🧠  Memory: ${MEM_USED} / ${MEM_TOTAL} ${BOLD_GREEN}[${MEM_BAR}${MEM_EMPTY}] ${MEM_PERCENT}%${RESET}"

        local DISK_PERCENT DISK_USED DISK_TOTAL DISK_BAR DISK_EMPTY DISK_COLOR
        DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
        DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
        DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
        DISK_BAR=$(printf '█%.0s' $(seq 1 $((DISK_PERCENT/5))) 2>/dev/null)
        DISK_EMPTY=$(printf '░%.0s' $(seq 1 $((20-DISK_PERCENT/5))) 2>/dev/null)
        if [ "$DISK_PERCENT" -gt 80 ]; then DISK_COLOR="${BOLD_YELLOW}"; else DISK_COLOR="${BOLD_GREEN}"; fi
        echo -e "${CYAN}├─${RESET} ${CYAN}💾  Disk: ${DISK_USED} / ${DISK_TOTAL} ${DISK_COLOR}[${DISK_BAR}${DISK_EMPTY}] ${DISK_PERCENT}%${RESET}"

        local CPU_LOAD
        CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
        echo -e "${CYAN}├─${RESET} ${CYAN}⚡  CPU Load: ${CPU_LOAD}${RESET}"

        echo -e "${CYAN}├─${RESET} ${CYAN}👤  User: $(whoami)@$(hostname)${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}🔄  Processes: $(ps aux | wc -l)${RESET}"

        if command -v docker &>/dev/null && docker info &>/dev/null; then
            local DOCKER_RUNNING DOCKER_TOTAL DOCKER_STOPPED
            DOCKER_RUNNING=$(docker ps -q | wc -l)
            DOCKER_TOTAL=$(docker ps -a -q | wc -l)
            DOCKER_STOPPED=$((DOCKER_TOTAL - DOCKER_RUNNING))
            echo -e "${CYAN}├─${RESET} ${CYAN}🐳  Docker: ${BOLD_GREEN}${DOCKER_RUNNING} Running${RESET} | ${DIM}${DOCKER_STOPPED} Stopped${RESET}"
        fi

        echo -e "${CYAN}│${RESET}"
        _CHECK_ALERTS
        echo -e "${BOLD_CYAN}└─────────────────────────────────────────────────────────${RESET}"
        echo ""
    else
        local MEM_PERCENT DISK_PERCENT CPU_LOAD ENV_INFO
        MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
        DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
        CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
        ENV_INFO=$(_DETECT_ENV_BANNER)
        echo -e "  ${BOLD_YELLOW}💭  ${RANDOM_QUOTE}${RESET}"
        echo -e "${BOLD_MAGENTA}[$ENV_INFO]${RESET} ${CYAN}🧠 Mem: ${MEM_PERCENT}%${RESET} | ${CYAN}💾 Disk: ${DISK_PERCENT}%${RESET} | ${CYAN}⚡ CPU: ${CPU_LOAD}${RESET} | ${CYAN}🌐 IP: ${myip}${RESET}"
        echo ""
    fi
}

# ─── Main auto-run block (skipped when TERMINAL_BANNER_FUNCTIONS_ONLY=1) ───────
if [[ "${TERMINAL_BANNER_FUNCTIONS_ONLY:-0}" != "1" ]]; then

# 1. Print Header
if [ "$TERM_ROWS" -ge 30 ]; then
    # Full ASCII art banner
    echo -e "${NEON_PINK}"
    cat << 'EOF'
  ██████╗  █████╗ ███╗   ██╗███████╗███████╗██╗  ██╗
 ██╔════╝ ██╔══██╗████╗  ██║██╔════╝██╔════╝██║  ██║
 ██║  ███╗███████║██╔██╗ ██║█████╗  ███████╗███████║
 ██║   ██║██╔══██║██║╚██╗██║██╔══╝  ╚════██║██╔══██║
 ╚██████╔╝██║  ██║██║ ╚████║███████╗███████║██║  ██║
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${RESET}"
    echo -e "  ${DIM}${CYAN}DevOps Engineer | System Thinker | Failure-Aware Architect${RESET}"
    echo -e "${DIM}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD_YELLOW}💭  ${RANDOM_QUOTE}${RESET}"
    echo ""
elif [ "$TERM_ROWS" -ge 22 ]; then
    # Compact header (no big ASCII art)
    echo -e "  ${BOLD_CYAN}🤖 GANESH@DEVOPS${RESET} ${DIM}— DevOps Engineer | System Thinker${RESET}"
    echo -e "  ${BOLD_YELLOW}💭  ${RANDOM_QUOTE}${RESET}"
    echo ""
else
    # Minimal header (for very small panes)
    echo -e "  ${BOLD_CYAN}🤖 GANESH@DEVOPS${RESET} ${DIM}| ${BOLD_YELLOW}💭  ${RANDOM_QUOTE}${RESET}"
fi

# 2. Print System Info Block
if [ "$TERM_ROWS" -ge 22 ]; then
    ENV_INFO=$(_DETECT_ENV_BANNER)
    echo -e "${BOLD_MAGENTA}[Environment]${RESET} ${BOLD_WHITE}${ENV_INFO}${RESET}"
    echo ""

    # System info grid
    echo -e "${BOLD_CYAN}┌─[ SYSTEM STATUS ]${RESET}"
    echo -e "${CYAN}│${RESET}"
    
    # Date & Time
    echo -e "${CYAN}├─${RESET} ${WHITE}📅  $(date '+%A, %B %d %Y')   🕐  $(date '+%I:%M %p')${RESET}"
    
    # Uptime
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6"h "$7"m"}')
    echo -e "${CYAN}├─${RESET} ${BOLD_GREEN}⏱️ Uptime: ${UPTIME}${RESET}"
    
    # OS Info
    OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    echo -e "${CYAN}├─${RESET} ${CYAN}💻  OS: ${OS}${RESET}"
    
    # Weather
    WEATHER=$(curl -s --max-time 1 "wttr.in/?format=3" 2>/dev/null)
    if [ -n "$WEATHER" ] && [[ ! "$WEATHER" =~ "Unknown" ]]; then
        echo -e "${CYAN}├─${RESET} ${CYAN}⛅  Weather: ${WEATHER}${RESET}"
    fi

    # Kernel
    KERNEL=$(uname -r)
    echo -e "${CYAN}├─${RESET} ${CYAN}🔧  Kernel: ${KERNEL}${RESET}"
    
    # Shell
    echo -e "${CYAN}├─${RESET} ${CYAN}🐚  Shell: $SHELL${RESET}"
    
    # My IP
    echo -e "${CYAN}├─${RESET} ${CYAN}🌐  IP: ${myip}${RESET}"
    
    # Memory usage with bar
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    MEM_BAR=$(printf '█%.0s' $(seq 1 $((MEM_PERCENT/5))) 2>/dev/null)
    MEM_EMPTY=$(printf '░%.0s' $(seq 1 $((20-MEM_PERCENT/5))) 2>/dev/null)
    echo -e "${CYAN}├─${RESET} ${CYAN}🧠  Memory: ${MEM_USED} / ${MEM_TOTAL} ${BOLD_GREEN}[${MEM_BAR}${MEM_EMPTY}] ${MEM_PERCENT}%${RESET}"
    
    # Disk usage with bar
    DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_BAR=$(printf '█%.0s' $(seq 1 $((DISK_PERCENT/5))) 2>/dev/null)
    DISK_EMPTY=$(printf '░%.0s' $(seq 1 $((20-DISK_PERCENT/5))) 2>/dev/null)
    if [ "$DISK_PERCENT" -gt 80 ]; then
        DISK_COLOR="${BOLD_YELLOW}"
    else
        DISK_COLOR="${BOLD_GREEN}"
    fi
    echo -e "${CYAN}├─${RESET} ${CYAN}💾  Disk: ${DISK_USED} / ${DISK_TOTAL} ${DISK_COLOR}[${DISK_BAR}${DISK_EMPTY}] ${DISK_PERCENT}%${RESET}"
    
    # CPU Load
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    echo -e "${CYAN}├─${RESET} ${CYAN}⚡  CPU Load: ${CPU_LOAD}${RESET}"
    
    # Logged in user
    echo -e "${CYAN}├─${RESET} ${CYAN}👤  User: $(whoami)@$(hostname)${RESET}"
    
    # Active processes
    PROC_COUNT=$(ps aux | wc -l)
    echo -e "${CYAN}├─${RESET} ${CYAN}🔄  Processes: ${PROC_COUNT}${RESET}"
    
    # Docker Status
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        DOCKER_RUNNING=$(docker ps -q | wc -l)
        DOCKER_TOTAL=$(docker ps -a -q | wc -l)
        DOCKER_STOPPED=$((DOCKER_TOTAL - DOCKER_RUNNING))
        echo -e "${CYAN}├─${RESET} ${CYAN}🐳  Docker: ${BOLD_GREEN}${DOCKER_RUNNING} Running${RESET} | ${DIM}${DOCKER_STOPPED} Stopped${RESET}"
    fi

    # Connection quality (SSH only)
    if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
        LATENCY=$(timeout 1 ping -c 1 8.8.8.8 2>/dev/null | grep time= | awk -F'time=' '{print $2}' | awk '{print $1}' | cut -d'.' -f1)
        if [ -n "$LATENCY" ]; then
            if [ "$LATENCY" -lt 50 ]; then
                CONN_STATUS="${BOLD_GREEN}✓ Excellent (${LATENCY}ms)"
            elif [ "$LATENCY" -lt 150 ]; then
                CONN_STATUS="${BOLD_YELLOW}⚠ Good (${LATENCY}ms)"
            else
                CONN_STATUS="${BOLD_RED}⚠ Slow (${LATENCY}ms)"
            fi
            echo -e "${CYAN}├─${RESET} ${CONN_STATUS}${RESET}"
        fi
    fi
    
    echo -e "${CYAN}│${RESET}"
    
    _CHECK_ALERTS
    
    # Git status (only if current folder is a git repo)
    if git -C "$PWD" rev-parse --is-inside-work-tree &>/dev/null; then
        BRANCH=$(git -C "$PWD" branch --show-current 2>/dev/null)
        STAGED=$(git -C "$PWD" diff --cached --name-only 2>/dev/null | wc -l)
        MODIFIED=$(git -C "$PWD" diff --name-only 2>/dev/null | wc -l)
        UNTRACKED=$(git -C "$PWD" ls-files --others --exclude-standard 2>/dev/null | wc -l)
        echo -e "${BOLD_CYAN}├─[ GIT REPOSITORY ]${RESET}"
        echo -e "${CYAN}│${RESET}"
        echo -e "${CYAN}├─${RESET} ${BOLD_GREEN}🌿  Branch   : ${BRANCH}${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}   Staged   : ${STAGED} file(s)${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}   Modified : ${MODIFIED} file(s)${RESET}"
        echo -e "${CYAN}├─${RESET} ${CYAN}   Untracked: ${UNTRACKED} file(s)${RESET}"
        echo -e "${CYAN}│${RESET}"
    fi
    echo -e "${BOLD_CYAN}└─────────────────────────────────────────────────────────${RESET}"
    echo ""
else
    # Minimal / Small Pane View (single line stats)
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    ENV_INFO=$(_DETECT_ENV_BANNER)
    
    echo -e "${BOLD_MAGENTA}[$ENV_INFO]${RESET} ${CYAN}🧠 Mem: ${MEM_PERCENT}%${RESET} | ${CYAN}💾 Disk: ${DISK_PERCENT}%${RESET} | ${CYAN}⚡ CPU: ${CPU_LOAD}${RESET} | ${CYAN}🌐 IP: ${myip}${RESET}"
    echo ""
fi

fi # end TERMINAL_BANNER_FUNCTIONS_ONLY guard
