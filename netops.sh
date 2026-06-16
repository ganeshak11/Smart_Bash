#!/bin/bash
# Network & Port Manager using fzf

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

while true; do
    echo -e "${BOLD_CYAN}🌐 Network Connections & Listening Ports${RESET}"
    
    selected=$(sudo ss -tulnp | tail -n +2 | \
        fzf --prompt="Select Port > " \
            --height=50% --border=rounded \
            --header="Netid  State   Recv-Q  Send-Q   Local Address:Port   Peer Address:Port  Process" \
            --pointer="❯" \
            --color="prompt:cyan,pointer:yellow,hl:green,border:cyan" \
            --preview="echo {} | grep -oP 'pid=\K\d+' | xargs -I PID bash -c 'echo -e \"\033[1;36mProcess Info:\033[0m\"; ps -f -p PID; echo -e \"\n\033[1;36mOpen Files:\033[0m\"; sudo lsof -p PID | head -20'")
    
    [[ -z "$selected" ]] && exit 0
    
    # Extract PID
    pid=$(echo "$selected" | grep -oP 'pid=\K\d+' | head -1)
    port=$(echo "$selected" | awk '{print $5}')
    
    if [[ -z "$pid" ]]; then
        echo -e "${BOLD_YELLOW}⚠️  No PID found. You might need sudo privileges.${RESET}"
        read -r -n 1 -s
        continue
    fi
    
    action=$(printf "🔍 Inspect Process\n💀 Kill Process\n↩️  Back" | \
        fzf --prompt="Action for $port (PID $pid) > " --height=30% --border=rounded)
        
    case "$action" in
        *"Inspect"*)
            clear
            echo -e "${BOLD_CYAN}Process Tree for PID $pid:${RESET}"
            pstree -p "$pid"
            echo -e "\n${BOLD_CYAN}Detailed ps info:${RESET}"
            ps -f -p "$pid"
            read -r -n 1 -s -p "Press any key to continue..."
            ;;
        *"Kill"*)
            echo -e "${BOLD_RED}⚠️  Killing PID $pid...${RESET}"
            sudo kill -9 "$pid" && echo -e "${BOLD_GREEN}✅ Process killed.${RESET}"
            read -r -n 1 -s
            ;;
    esac
done
