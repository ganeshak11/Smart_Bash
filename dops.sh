#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  dops — Smart Docker Operations Manager                     ║
# ║  Context-aware: Compose stacks or global containers via fzf  ║
# ╚══════════════════════════════════════════════════════════════╝

# shellcheck disable=SC1091
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# ── Dependency check ───────────────────────────────────────────────────────────
_dops_check_deps() {
    if ! command -v docker &>/dev/null; then
        echo -e "${SB_BOLD_RED}❌ Docker is not installed or not in PATH.${SB_RESET}"
        return 1
    fi
    if ! docker info &>/dev/null; then
        echo -e "${SB_BOLD_RED}❌ Docker daemon is not running. Start it with: sudo systemctl start docker${SB_RESET}"
        return 1
    fi
    if ! command -v fzf &>/dev/null; then
        echo -e "${SB_BOLD_RED}❌ fzf is required but not installed. Install it with your package manager (apt/dnf/pacman/brew install fzf)${SB_RESET}"
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
    echo -e "\n${SB_BOLD_CYAN}── Container Info: $cname ──${SB_RESET}"
    echo -e "${SB_BOLD_WHITE}🔌 Ports:${SB_RESET}"
    docker port "$cname" 2>/dev/null || echo "   (none)"
    echo -e "\n${SB_BOLD_WHITE}🌐 Networks & IPs:${SB_RESET}"
    docker inspect "$cname" --format \
        '{{range $net, $cfg := .NetworkSettings.Networks}}  {{$net}}: {{$cfg.IPAddress}}{{println}}{{end}}' 2>/dev/null
    echo -e "${SB_BOLD_WHITE}📁 Volumes:${SB_RESET}"
    docker inspect "$cname" --format \
        '{{range .Mounts}}  {{.Source}} → {{.Destination}} ({{.Type}}){{println}}{{end}}' 2>/dev/null | head -10
    echo -e "${SB_BOLD_WHITE}📊 Resource Usage:${SB_RESET}"
    docker stats "$cname" --no-stream --format \
        "  CPU: {{.CPUPerc}}   MEM: {{.MemUsage}}   NET: {{.NetIO}}" 2>/dev/null
    echo ""
}

# ── Exec into container (bash fallback to sh) ──────────────────────────────────
_dops_exec() {
    local cname="$1"

    echo -e "${SB_BOLD_GREEN}🐚 Dropping into shell inside '$cname'...${SB_RESET}"

    # Check for bash first
    if docker exec "$cname" sh -c "command -v bash" >/dev/null 2>&1; then
        docker exec -it "$cname" bash
        return
    fi

    # Fallback to sh
    if docker exec "$cname" sh -c "command -v sh" >/dev/null 2>&1; then
        echo -e "${SB_DIM}bash not found, falling back to sh...${SB_RESET}"
        docker exec -it "$cname" sh
        return
    fi

    echo -e "${SB_BOLD_RED}❌ No usable shell found inside container.${SB_RESET}"
}

# ── Individual container action menu ──────────────────────────────────────────
_dops_container_actions() {
    local cname="$1"
    local cimage="$2"

    while true; do
        echo -e "\n${SB_BOLD_CYAN}🐳 Selected: ${SB_BOLD_WHITE}$cname ${SB_DIM}($cimage)${SB_RESET}"
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
                echo -e "${SB_BOLD_GREEN}🪵 Streaming logs for '$cname' (Ctrl+C to stop)...${SB_RESET}"
                docker logs -f --tail 100 "$cname"
                ;;
            *"Exec Shell"*)
                _dops_exec "$cname"
                ;;
            *"Restart"*)
                echo -e "${SB_BOLD_YELLOW}🔄 Restarting '$cname'...${SB_RESET}"
                docker restart "$cname" && echo -e "${SB_BOLD_GREEN}✅ Restarted.${SB_RESET}"
                ;;
            *"Stop"*)
                echo -e "${SB_BOLD_YELLOW}🛑 Stopping '$cname'...${SB_RESET}"
                docker stop "$cname" && echo -e "${SB_BOLD_GREEN}✅ Stopped.${SB_RESET}"
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
                            docker cp "$hpath" "$cname:$cpath" && echo -e "${SB_BOLD_GREEN}✅ Copied to container.${SB_RESET}"
                        fi
                        ;;
                    *"Container ➔ Host"*)
                        read -p $'\e[1;36m❯ Container file/dir path: \e[0m' cpath
                        read -e -p $'\e[1;36m❯ Host dest path: \e[0m' hpath
                        if [[ -n "$hpath" && -n "$cpath" ]]; then
                            docker cp "$cname:$cpath" "$hpath" && echo -e "${SB_BOLD_GREEN}✅ Copied to host.${SB_RESET}"
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
                # dops is sourced into the interactive shell: never `exit` here,
                # it would close the terminal. Flag a quit and unwind instead.
                _DOPS_QUIT=1
                return
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
            echo -e "${SB_BOLD_YELLOW}⚠️  No running containers found.${SB_RESET}"
            return
        fi

        echo -e "\n${SB_BOLD_CYAN}🐳 Running Containers (select to manage):${SB_RESET}"
        # Pre-calculate a safe script for preview to avoid quote hell
        local preview_cmd='
            echo -e "\033[1;36m--- Live Stats ---\033[0m"
            docker stats --no-stream {1} 2>/dev/null | tail -n +2
            echo -e "\n\033[1;36m--- Recent Logs ---\033[0m"
            docker logs --tail 15 {1} 2>&1
        '
        local selected
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
        [[ "$_DOPS_QUIT" == 1 ]] && return
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
        echo -e "\n${SB_BOLD_MAGENTA}🗂️  Compose Stack: ${SB_BOLD_WHITE}$(basename "$(pwd)")${SB_RESET}"
        echo -e "${SB_DIM}File: $compose_file${SB_RESET}\n"

        # Show running services from this stack
        local services
        services=$(docker ps --filter "label=com.docker.compose.project=$project_name" \
            --format "  {{.Names}} ({{.Status}})" 2>/dev/null)
        if [[ -n "$services" ]]; then
            echo -e "${SB_BOLD_GREEN}● Running Services:${SB_RESET}"
            echo -e "$services"
        else
            echo -e "${SB_BOLD_YELLOW}● No services currently running from this stack.${SB_RESET}"
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
                echo -e "${SB_BOLD_GREEN}🪵 Streaming all logs (Ctrl+C to stop)...${SB_RESET}"
                $compose_cmd logs -f --tail=50
                ;;
            *"Tail Specific Service"*)
                local svc_list
                svc_list=$($compose_cmd config --services 2>/dev/null)
                if [[ -z "$svc_list" ]]; then
                    echo -e "${SB_BOLD_RED}❌ Could not read services from compose file.${SB_RESET}"
                else
                    local chosen_svc
                    chosen_svc=$(echo "$svc_list" | _dops_menu "Pick a service")
                    if [[ -n "$chosen_svc" ]]; then
                        echo -e "${SB_BOLD_GREEN}🪵 Streaming logs for '$chosen_svc' (Ctrl+C to stop)...${SB_RESET}"
                        $compose_cmd logs -f --tail=100 "$chosen_svc"
                    fi
                fi
                ;;
            *"Up"*)
                echo -e "${SB_BOLD_GREEN}⬆️  Building & starting stack...${SB_RESET}"
                $compose_cmd up -d --build
                ;;
            *"Restart All"*)
                echo -e "${SB_BOLD_YELLOW}🔄 Restarting all services...${SB_RESET}"
                $compose_cmd restart && echo -e "${SB_BOLD_GREEN}✅ All services restarted.${SB_RESET}"
                ;;
            *"Stop All"*)
                echo -e "${SB_BOLD_YELLOW}🛑 Stopping all services...${SB_RESET}"
                $compose_cmd stop && echo -e "${SB_BOLD_GREEN}✅ Stack stopped.${SB_RESET}"
                ;;
            *"Down"*)
                echo -e "${SB_BOLD_RED}⬇️  Tearing down stack (containers + networks)...${SB_RESET}"
                read -r -p $'\e[1;35m❯ Are you sure? [y/N]: \e[0m' confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    $compose_cmd down && echo -e "${SB_BOLD_GREEN}✅ Stack removed.${SB_RESET}"
                    return
                else
                    echo -e "${SB_DIM}Cancelled.${SB_RESET}"
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
                    echo -e "${SB_BOLD_RED}❌ No running services found for this stack.${SB_RESET}"
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
                            echo -e "${SB_BOLD_RED}❌ Service '$chosen_svc' is not running.${SB_RESET}"
                        fi
                    fi
                fi
                ;;
            *"Show Service Status"*)
                echo -e "\n${SB_BOLD_CYAN}── Stack Status ──${SB_RESET}"
                $compose_cmd ps
                echo ""
                ;;
            *"Manage Individual"*)
                _dops_global
                [[ "$_DOPS_QUIT" == 1 ]] && return
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
        echo -e "\n${SB_BOLD_CYAN}📦 Manage Images & Volumes${SB_RESET}"
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
                echo -e "${SB_BOLD_RED}⚠️  This will remove all unused containers, networks, images (both dangling and unreferenced), and optionally, volumes.${SB_RESET}"
                read -r -p $'\e[1;33m❯ Proceed with system prune? [y/N]: \e[0m' confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker system prune -a && echo -e "${SB_BOLD_GREEN}✅ Pruned.${SB_RESET}"
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
            echo -e "${SB_BOLD_YELLOW}⚠️  No images found.${SB_RESET}"
            return
        fi

        echo -e "\n${SB_BOLD_CYAN}🖼️  Docker Images:${SB_RESET}"
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
                docker rmi "$iid" && echo -e "${SB_BOLD_GREEN}✅ Removed $iid.${SB_RESET}"
                read -r -n 1 -s
                ;;
            *"Force Remove"*)
                docker rmi -f "$iid" && echo -e "${SB_BOLD_GREEN}✅ Force removed $iid.${SB_RESET}"
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
            echo -e "${SB_BOLD_YELLOW}⚠️  No volumes found.${SB_RESET}"
            return
        fi

        echo -e "\n${SB_BOLD_CYAN}💾  Docker Volumes:${SB_RESET}"
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
                docker volume rm "$vname" && echo -e "${SB_BOLD_GREEN}✅ Removed $vname.${SB_RESET}"
                read -r -n 1 -s
                ;;
        esac
    done
}

_dops_hub_search() {
    echo -e "${SB_BOLD_CYAN}🔍 Search Docker Hub${SB_RESET}"
    read -r -p $'\e[1;36m❯ Enter search term: \e[0m' query
    [[ -z "$query" ]] && return

    echo -e "${SB_DIM}Searching for '$query'...${SB_RESET}"
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
    echo -e "${SB_BOLD_GREEN}⬇️  Pulling $iname...${SB_RESET}"
    docker pull "$iname"
    read -r -n 1 -s -p "Press any key to continue..."
}

# ── Main Entry Point ───────────────────────────────────────────────────────────
dops() {
    _dops_check_deps || return 1
    _DOPS_QUIT=0

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
        echo -e "\n${SB_BOLD_MAGENTA}🐳 Docker Compose stack detected!${SB_RESET} ${SB_DIM}($compose_file)${SB_RESET}"
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
