#!/bin/bash
# System Log Explorer

# shellcheck disable=SC1091
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

choice=$(printf "📜 journalctl (System Services)\n📁 /var/log/ (Log Files)" | fzf --prompt="Log Source > " --height=20% --border=rounded)

if [[ "$choice" == *"journalctl"* ]]; then
    services=$(systemctl list-units --type=service --all --plain --no-legend | awk '{print $1}')
    selected=$(echo "$services" | fzf --prompt="Select Service > " --height=50% --border=rounded \
        --preview="journalctl -u {} -n 50 --no-pager")
    if [[ -n "$selected" ]]; then
        journalctl -u "$selected" -f
    fi
elif [[ "$choice" == *"/var/log/"* ]]; then
    selected=$(find /var/log -type f \( -name "*.log" -o -name "syslog*" \) 2>/dev/null | \
        fzf --prompt="Select Log File > " --height=50% --border=rounded \
        --preview="tail -n 50 {}")
    if [[ -n "$selected" ]]; then
        tail -f "$selected"
    fi
fi
