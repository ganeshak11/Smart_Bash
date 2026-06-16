#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  dops — Smart Docker Operations Manager                     ║
# ║  Context-aware: Compose stacks or global containers via fzf  ║
# ╚══════════════════════════════════════════════════════════════╝

# Colors
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
BOLD_MAGENTA='\033[1;35m'
BOLD_WHITE='\033[1;37m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

# ── Dependency check ───────────────────────────────────────────────────────────
_dops_check_deps() {
    if ! command -v docker &>/dev/null; then
        echo -e "${BOLD_RED}❌ Docker is not installed or not in PATH.${RESET}"
        return 1
    fi
    if ! docker info &>/dev/null; then
        echo -e "${BOLD_RED}❌ Docker daemon is not running. Start it with: sudo systemctl start docker${RESET}"
        return 1
    fi
    if ! command -v fzf &>/dev/null; then
        echo -e "${BOLD_RED}❌ fzf is required but not installed. Install with: sudo apt install fzf${RESET}"
        return 1
    fi
    return 0
}

# ── Run arrow-key menu using fzf ──────────────────────────────────────────────
# Usage:
#   _dops_menu "prompt" "opt1" "opt2" ...   → options from args
#   echo -e "opt1\nopt2" | _dops_menu "prompt"  → options from stdin
_dops_menu() {
    local prompt="$1"
    shift
    local fzf_opts=(
        --prompt="$prompt > "
        --height=40%
        --border=rounded
        --ansi
        --no-multi
        --cycle
        --pointer="❯"
        --color="prompt:cyan,pointer:yellow,hl:green,border:cyan"
    )
    if [[ $# -gt 0 ]]; then
        # Options passed as arguments
        printf '%s\n' "$@" | fzf "${fzf_opts[@]}"
    else
        # Options piped via stdin
        fzf "${fzf_opts[@]}"
    fi
}

# ── Inspect a container ────────────────────────────────────────────────────────
_dops_inspect() {
    local cname="$1"
    echo -e "\n${BOLD_CYAN}── Container Info: $cname ──${RESET}"
    echo -e "${BOLD_WHITE}🔌 Ports:${RESET}"
    docker port "$cname" 2>/dev/null || echo "   (none)"
    echo -e "\n${BOLD_WHITE}🌐 Networks & IPs:${RESET}"
    docker inspect "$cname" --format \
        '{{range $net, $cfg := .NetworkSettings.Networks}}  {{$net}}: {{$cfg.IPAddress}}{{println}}{{end}}' 2>/dev/null
    echo -e "${BOLD_WHITE}📁 Volumes:${RESET}"
    docker inspect "$cname" --format \
        '{{range .Mounts}}  {{.Source}} → {{.Destination}} ({{.Type}}){{println}}{{end}}' 2>/dev/null | head -10
    echo -e "${BOLD_WHITE}📊 Resource Usage:${RESET}"
    docker stats "$cname" --no-stream --format \
        "  CPU: {{.CPUPerc}}   MEM: {{.MemUsage}}   NET: {{.NetIO}}" 2>/dev/null
    echo ""
}

# ── Exec into container (bash fallback to sh) ──────────────────────────────────
_dops_exec() {
    local cname="$1"

    echo -e "${BOLD_GREEN}🐚 Dropping into shell inside '$cname'...${RESET}"

    # Check for bash first
    if docker exec "$cname" sh -c "command -v bash" >/dev/null 2>&1; then
        docker exec -it "$cname" bash
        return
    fi

    # Fallback to sh
    if docker exec "$cname" sh -c "command -v sh" >/dev/null 2>&1; then
        echo -e "${DIM}bash not found, falling back to sh...${RESET}"
        docker exec -it "$cname" sh
        return
    fi

    echo -e "${BOLD_RED}❌ No usable shell found inside container.${RESET}"
}

# ── Individual container action menu ──────────────────────────────────────────
_dops_container_actions() {
    local cname="$1"
    local cimage="$2"

    while true; do
        echo -e "\n${BOLD_CYAN}🐳 Selected: ${BOLD_WHITE}$cname ${DIM}($cimage)${RESET}"
        local action
        action=$(_dops_menu "Action for $cname" \
            "🪵  Tail Logs" \
            "🐚  Exec Shell (bash/sh)" \
            "🔄  Restart Container" \
            "🛑  Stop Container" \
            "📂  Copy File (Host <-> Container)" \
            "🔍  Inspect Network / Ports / Volumes" \
            "↩️   Back to container list" \
            "❌  Exit dops"
        )
        [[ -z "$action" ]] && return

        case "$action" in
            *"Tail Logs"*)
                echo -e "${BOLD_GREEN}🪵 Streaming logs for '$cname' (Ctrl+C to stop)...${RESET}"
                docker logs -f --tail 100 "$cname"
                ;;
            *"Exec Shell"*)
                _dops_exec "$cname"
                ;;
            *"Restart"*)
                echo -e "${BOLD_YELLOW}🔄 Restarting '$cname'...${RESET}"
                docker restart "$cname" && echo -e "${BOLD_GREEN}✅ Restarted.${RESET}"
                ;;
            *"Stop"*)
                echo -e "${BOLD_YELLOW}🛑 Stopping '$cname'...${RESET}"
                docker stop "$cname" && echo -e "${BOLD_GREEN}✅ Stopped.${RESET}"
                return
                ;;
            *"Copy File"*)
                local dir
                dir=$(_dops_menu "Copy Direction" "Host ➔ Container" "Container ➔ Host" "↩️ Back")
                case "$dir" in
                    *"Host ➔ Container"*)
                        read -e -p $'\e[1;36m❯ Host file/dir path: \e[0m' hpath
                        read -p $'\e[1;36m❯ Container dest path: \e[0m' cpath
                        if [[ -n "$hpath" && -n "$cpath" ]]; then
                            docker cp "$hpath" "$cname:$cpath" && echo -e "${BOLD_GREEN}✅ Copied to container.${RESET}"
                        fi
                        ;;
                    *"Container ➔ Host"*)
                        read -p $'\e[1;36m❯ Container file/dir path: \e[0m' cpath
                        read -e -p $'\e[1;36m❯ Host dest path: \e[0m' hpath
                        if [[ -n "$hpath" && -n "$cpath" ]]; then
                            docker cp "$cname:$cpath" "$hpath" && echo -e "${BOLD_GREEN}✅ Copied to host.${RESET}"
                        fi
                        ;;
                esac
                ;;
            *"Inspect"*)
                _dops_inspect "$cname"
                ;;
            *"Back"*)
                return
                ;;
            *"Exit"*)
                exit 0
                ;;
        esac
    done
}

# ── Global container picker ────────────────────────────────────────────────────
_dops_global() {
    while true; do
        local running
        running=$(docker ps --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)

        if [[ -z "$running" ]]; then
            echo -e "${BOLD_YELLOW}⚠️  No running containers found.${RESET}"
            return
        fi

        echo -e "\n${BOLD_CYAN}🐳 Running Containers (select to manage):${RESET}"
        # Pre-calculate a safe script for preview to avoid quote hell
        local preview_cmd='
            echo -e "\033[1;36m--- Live Stats ---\033[0m"
            docker stats --no-stream {1} 2>/dev/null | tail -n +2
            echo -e "\n\033[1;36m--- Recent Logs ---\033[0m"
            docker logs --tail 15 {1} 2>&1
        '
        selected=$(echo "$running" | awk -F'|' '{printf "%-14s  %-28s  %-28s  %s\n", $1, $2, $3, $4}' | \
            fzf \
                --prompt="Select container > " \
                --height=50% \
                --border=rounded \
                --ansi \
                --no-multi \
                --cycle \
                --pointer="❯" \
                --header="ID             NAME                          IMAGE                         STATUS" \
                --color="prompt:cyan,pointer:yellow,hl:green,border:cyan,header:bright-cyan" \
                --preview="$preview_cmd"
        )

        [[ -z "$selected" ]] && return

        local cid cname cimage
        cid=$(echo "$selected" | awk '{print $1}')
        cname=$(docker inspect "$cid" --format '{{.Name}}' 2>/dev/null | sed 's|/||')
        cimage=$(docker inspect "$cid" --format '{{.Config.Image}}' 2>/dev/null)

        _dops_container_actions "$cname" "$cimage"
    done
}

# ── Docker Compose stack manager ───────────────────────────────────────────────
_dops_compose() {
    local compose_file="$1"
    local compose_cmd

    # Support both old and new compose syntax
    if docker compose version &>/dev/null 2>&1; then
        compose_cmd="docker compose"
    else
        compose_cmd="docker-compose"
    fi

    # Get project name from compose file directory
    # Docker Compose always lowercases the project name for labels
    local project_name
    project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')

    while true; do
        echo -e "\n${BOLD_MAGENTA}🗂️  Compose Stack: ${BOLD_WHITE}$(basename "$(pwd)")${RESET}"
        echo -e "${DIM}File: $compose_file${RESET}\n"

        # Show running services from this stack
        local services
        services=$(docker ps --filter "label=com.docker.compose.project=$project_name" \
            --format "  {{.Names}} ({{.Status}})" 2>/dev/null)
        if [[ -n "$services" ]]; then
            echo -e "${BOLD_GREEN}● Running Services:${RESET}"
            echo -e "$services"
        else
            echo -e "${BOLD_YELLOW}● No services currently running from this stack.${RESET}"
        fi

        echo ""
        local action
        action=$(_dops_menu "Compose Action for $project_name" \
            "🪵  Tail All Logs (live)" \
            "🪵  Tail Specific Service Logs" \
            "⬆️   Up (Build & Start all)" \
            "🔄  Restart All Services" \
            "🛑  Stop All Services" \
            "⬇️   Down (Remove containers + networks)" \
            "🐚  Exec into a Service Shell" \
            "📋  Show Service Status" \
            "🌍  Manage Individual Container Globally" \
            "❌  Exit dops"
        )
        [[ -z "$action" ]] && return

        case "$action" in
            *"Tail All Logs"*)
                echo -e "${BOLD_GREEN}🪵 Streaming all logs (Ctrl+C to stop)...${RESET}"
                $compose_cmd logs -f --tail=50
                ;;
            *"Tail Specific Service"*)
                local svc_list
                svc_list=$($compose_cmd config --services 2>/dev/null)
                if [[ -z "$svc_list" ]]; then
                    echo -e "${BOLD_RED}❌ Could not read services from compose file.${RESET}"
                else
                    local chosen_svc
                    chosen_svc=$(echo "$svc_list" | _dops_menu "Pick a service")
                    if [[ -n "$chosen_svc" ]]; then
                        echo -e "${BOLD_GREEN}🪵 Streaming logs for '$chosen_svc' (Ctrl+C to stop)...${RESET}"
                        $compose_cmd logs -f --tail=100 "$chosen_svc"
                    fi
                fi
                ;;
            *"Up"*)
                echo -e "${BOLD_GREEN}⬆️  Building & starting stack...${RESET}"
                $compose_cmd up -d --build
                ;;
            *"Restart All"*)
                echo -e "${BOLD_YELLOW}🔄 Restarting all services...${RESET}"
                $compose_cmd restart && echo -e "${BOLD_GREEN}✅ All services restarted.${RESET}"
                ;;
            *"Stop All"*)
                echo -e "${BOLD_YELLOW}🛑 Stopping all services...${RESET}"
                $compose_cmd stop && echo -e "${BOLD_GREEN}✅ Stack stopped.${RESET}"
                ;;
            *"Down"*)
                echo -e "${BOLD_RED}⬇️  Tearing down stack (containers + networks)...${RESET}"
                read -r -p $'\e[1;35m❯ Are you sure? [y/N]: \e[0m' confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    $compose_cmd down && echo -e "${BOLD_GREEN}✅ Stack removed.${RESET}"
                    return
                else
                    echo -e "${DIM}Cancelled.${RESET}"
                fi
                ;;
            *"Exec"*)
                # Try compose config first, fall back to reading live container labels
                local svc_list
                svc_list=$($compose_cmd config --services 2>/dev/null)
                if [[ -z "$svc_list" ]]; then
                    # Fallback: get services from running containers by label
                    svc_list=$(docker ps \
                        --filter "label=com.docker.compose.project=$project_name" \
                        --format '{{index .Labels "com.docker.compose.service"}}' 2>/dev/null | sort -u)
                fi
                if [[ -z "$svc_list" ]]; then
                    echo -e "${BOLD_RED}❌ No running services found for this stack.${RESET}"
                else
                    local chosen_svc
                    chosen_svc=$(echo "$svc_list" | _dops_menu "Pick a service to exec into")
                    if [[ -n "$chosen_svc" ]]; then
                        local cname
                        cname=$(docker ps \
                            --filter "label=com.docker.compose.service=$chosen_svc" \
                            --filter "label=com.docker.compose.project=$project_name" \
                            --format "{{.Names}}" | head -1)
                        if [[ -n "$cname" ]]; then
                            _dops_exec "$cname"
                        else
                            echo -e "${BOLD_RED}❌ Service '$chosen_svc' is not running.${RESET}"
                        fi
                    fi
                fi
                ;;
            *"Show Service Status"*)
                echo -e "\n${BOLD_CYAN}── Stack Status ──${RESET}"
                $compose_cmd ps
                echo ""
                ;;
            *"Manage Individual"*)
                _dops_global
                ;;
            *"Exit"*)
                return
                ;;
        esac
    done
}

# ── Image and Volume Management ────────────────────────────────────────────────
_dops_images_and_volumes() {
    while true; do
        echo -e "\n${BOLD_CYAN}📦 Manage Images & Volumes${RESET}"
        local choice
        choice=$(_dops_menu "Select operation" \
            "🖼️  Manage Images" \
            "💾  Manage Volumes" \
            "🔍  Search & Pull from Docker Hub" \
            "🧹  System Prune (Clean up everything)" \
            "↩️   Back to main menu"
        )
        [[ -z "$choice" ]] && return

        case "$choice" in
            *"Images"*)
                _dops_images
                ;;
            *"Volumes"*)
                _dops_volumes
                ;;
            *"Search & Pull"*)
                _dops_hub_search
                ;;
            *"System Prune"*)
                echo -e "${BOLD_RED}⚠️  This will remove all unused containers, networks, images (both dangling and unreferenced), and optionally, volumes.${RESET}"
                read -r -p $'\e[1;33m❯ Proceed with system prune? [y/N]: \e[0m' confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker system prune -a && echo -e "${BOLD_GREEN}✅ Pruned.${RESET}"
                fi
                ;;
            *"Back"*)
                return
                ;;
        esac
    done
}

_dops_images() {
    while true; do
        local images
        images=$(docker images --format "{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}" 2>/dev/null)
        if [[ -z "$images" ]]; then
            echo -e "${BOLD_YELLOW}⚠️  No images found.${RESET}"
            return
        fi

        echo -e "\n${BOLD_CYAN}🖼️  Docker Images:${RESET}"
        local selected
        selected=$(echo "$images" | awk -F'|' '{printf "%-14s  %-40s  %-15s  %s\n", $1, $2, $3, $4}' | \
            fzf --prompt="Select image > " \
                --height=50% --border=rounded --ansi --no-multi --cycle --pointer="❯" \
                --header="ID             REPOSITORY                                TAG              SIZE" \
                --color="prompt:cyan,pointer:yellow,hl:green,border:cyan,header:bright-cyan" \
                --preview="docker history {1} | head -n 20"
        )
        [[ -z "$selected" ]] && return

        local iid
        iid=$(echo "$selected" | awk '{print $1}')
        
        local action
        action=$(_dops_menu "Action for $iid" \
            "🗑️  Remove Image" \
            "🛑  Force Remove Image" \
            "↩️   Back"
        )
        case "$action" in
            *"Remove Image"*)
                docker rmi "$iid" && echo -e "${BOLD_GREEN}✅ Removed $iid.${RESET}"
                read -r -n 1 -s
                ;;
            *"Force Remove"*)
                docker rmi -f "$iid" && echo -e "${BOLD_GREEN}✅ Force removed $iid.${RESET}"
                read -r -n 1 -s
                ;;
        esac
    done
}

_dops_volumes() {
    while true; do
        local volumes
        volumes=$(docker volume ls --format "{{.Name}}|{{.Driver}}" 2>/dev/null)
        if [[ -z "$volumes" ]]; then
            echo -e "${BOLD_YELLOW}⚠️  No volumes found.${RESET}"
            return
        fi

        echo -e "\n${BOLD_CYAN}💾  Docker Volumes:${RESET}"
        local selected
        selected=$(echo "$volumes" | awk -F'|' '{printf "%-50s  %s\n", $1, $2}' | \
            fzf --prompt="Select volume > " \
                --height=50% --border=rounded --ansi --no-multi --cycle --pointer="❯" \
                --header="NAME                                                DRIVER" \
                --color="prompt:cyan,pointer:yellow,hl:green,border:cyan,header:bright-cyan" \
                --preview="docker volume inspect {1} | head -n 20"
        )
        [[ -z "$selected" ]] && return

        local vname
        vname=$(echo "$selected" | awk '{print $1}')
        
        local action
        action=$(_dops_menu "Action for $vname" \
            "🔍  Inspect Volume" \
            "🗑️  Remove Volume" \
            "↩️   Back"
        )
        case "$action" in
            *"Inspect"*)
                docker volume inspect "$vname"
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            *"Remove Volume"*)
                docker volume rm "$vname" && echo -e "${BOLD_GREEN}✅ Removed $vname.${RESET}"
                read -r -n 1 -s
                ;;
        esac
    done
}

_dops_hub_search() {
    echo -e "${BOLD_CYAN}🔍 Search Docker Hub${RESET}"
    read -r -p $'\e[1;36m❯ Enter search term: \e[0m' query
    [[ -z "$query" ]] && return

    echo -e "${DIM}Searching for '$query'...${RESET}"
    local selected
    selected=$(docker search "$query" | \
        fzf --prompt="Select image to pull > " \
            --height=50% --border=rounded --ansi --no-multi --cycle --pointer="❯" \
            --header-lines=1 \
            --color="prompt:cyan,pointer:yellow,hl:green,border:cyan,header:bright-cyan"
    )
    [[ -z "$selected" ]] && return

    local iname
    iname=$(echo "$selected" | awk '{print $1}')
    echo -e "${BOLD_GREEN}⬇️  Pulling $iname...${RESET}"
    docker pull "$iname"
    read -r -n 1 -s -p "Press any key to continue..."
}

# ── Main Entry Point ───────────────────────────────────────────────────────────
dops() {
    _dops_check_deps || return 1

    # Look for compose file in current directory
    local compose_file=""
    for f in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if [[ -f "$f" ]]; then
            compose_file="$f"
            break
        fi
    done

    local choice
    if [[ -n "$compose_file" ]]; then
        echo -e "\n${BOLD_MAGENTA}🐳 Docker Compose stack detected!${RESET} ${DIM}($compose_file)${RESET}"
        choice=$(_dops_menu "What do you want to manage?" \
            "🗂️  Manage Compose Stack (logs, restart, up, down, exec)" \
            "🌍  Manage Individual Containers (all running containers)" \
            "📦  Manage Images & Volumes" \
            "❌  Exit"
        )
    else
        choice=$(_dops_menu "What do you want to manage?" \
            "🌍  Manage Individual Containers (all running containers)" \
            "📦  Manage Images & Volumes" \
            "❌  Exit"
        )
    fi

    case "$choice" in
        *"Compose Stack"*)   _dops_compose "$compose_file" ;;
        *"Individual"*)      _dops_global ;;
        *"Images & Volumes"*) _dops_images_and_volumes ;;
        *"Exit"*|"")         return ;;
    esac
}
