#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  sb — the Smart Bash command                                                 ║
# ║    sb help | update | doctor | on/off <menu|banner> | cache clear | uninstall ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
# Sourced by bashrc.sh (needs to be a function so `sb update` can reload the shell).

[[ -z "${SB_RESET:-}" ]] && source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

_sb_help() {
    cat << EOF
${SB_BOLD_MAGENTA}Smart Bash${SB_RESET} ${SB_DIM}($SMART_BASH_DIR)${SB_RESET}

${SB_BOLD_CYAN}sb commands${SB_RESET}
  sb help                 This list
  sb update               Pull the latest Smart Bash and reload the shell
  sb doctor               Check dependencies, install state and startup time
  sb off menu|banner      Stop showing the startup menu / banner
  sb on  menu|banner      Show it again
  sb cache clear          Forget cached IP, weather, update count, docker stats
  sb uninstall            Restore your old ~/.bashrc

${SB_BOLD_CYAN}Navigation${SB_RESET}
  ld [-a] [-l]            Numbered listing (dirs first)
  cd N                    Jump to dir #N from the last ld
  cd <new-dir>            Offers to create it
  mkcd <dir>              Create a directory and enter it
  cdf                     Pick a sub-directory from a list
  y                       Yazi file manager, cd to where you quit
  z <name>                Zoxide smart jump

${SB_BOLD_CYAN}Tools${SB_RESET}
  menu                    Open the Smart Menu
  dops                    Docker manager (compose-aware)
  sgit                    Git: stage / branches / log via fzf
  netops                  Listening ports → inspect / kill
  slog                    journalctl / /var/log explorer
  cheat                   Personal cheat sheet (copy to clipboard)
  ask <question>          Ask Gemini (needs GEMINI_API_KEY in ~/.secrets)
  zgen                    Zellij layout wizard
  syncenv                 Back up dotfiles to ~/dotfiles (git)
  hack                    Zellij "hacker" layout

${SB_BOLD_CYAN}Utilities${SB_RESET}
  extract <archive>       Unpack anything
  weather [city]          Current weather
  countdown <sec>         Visual timer
  myip | ports | pid <port> | killport <port> | scan
  autopush ["note"]       git add . && commit (timestamped) && push
  reload                  Re-read the config (no menu)

${SB_BOLD_CYAN}Git aliases${SB_RESET}
  gs ga gc gp gpl gd gl gco gb gst gstp

${SB_DIM}Personal aliases go in ~/.bashrc.local · secrets in ~/.secrets${SB_RESET}
EOF
}

_sb_update() {
    if ! git -C "$SMART_BASH_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${SB_BOLD_RED}❌ $SMART_BASH_DIR is not a git checkout — can't update.${SB_RESET}"
        return 1
    fi
    local before after
    before=$(git -C "$SMART_BASH_DIR" rev-parse HEAD)
    echo -e "${SB_BOLD_CYAN}⬇️  Pulling latest Smart Bash...${SB_RESET}"
    git -C "$SMART_BASH_DIR" pull --ff-only || {
        echo -e "${SB_BOLD_RED}❌ Pull failed (local changes or diverged branch). Check: git -C $SMART_BASH_DIR status${SB_RESET}"
        return 1
    }
    after=$(git -C "$SMART_BASH_DIR" rev-parse HEAD)
    if [[ "$before" == "$after" ]]; then
        echo -e "${SB_BOLD_GREEN}✅ Already up to date.${SB_RESET}"
        return 0
    fi
    git -C "$SMART_BASH_DIR" log --oneline "$before..$after"
    local SB_NO_GREET=1
    source ~/.bashrc
    echo -e "${SB_BOLD_GREEN}✅ Updated and reloaded.${SB_RESET}"
}

_sb_doctor() {
    local ok="${SB_BOLD_GREEN}✔${SB_RESET}" warn="${SB_BOLD_YELLOW}⚠${SB_RESET}" bad="${SB_BOLD_RED}✘${SB_RESET}"
    local t

    echo -e "${SB_BOLD_CYAN}── Install ──${SB_RESET}"
    if grep -qs "bashrc.sh" ~/.bashrc; then
        echo -e "  $ok ~/.bashrc sources Smart Bash"
    else
        echo -e "  $bad ~/.bashrc does not source bashrc.sh — run: bash $SMART_BASH_DIR/install.sh"
    fi
    if [[ -f ~/.bashrc.local ]]; then echo -e "  $ok ~/.bashrc.local present"; else echo -e "  $warn no ~/.bashrc.local (optional)"; fi
    if [[ -f ~/.smart_menu.conf ]]; then echo -e "  $ok ~/.smart_menu.conf present"; else echo -e "  $warn no ~/.smart_menu.conf (menu will create a default)"; fi
    if [[ -f ~/.config/zellij/layouts/hacker.kdl ]]; then echo -e "  $ok zellij hacker layout installed"; else echo -e "  $warn zellij hacker layout missing"; fi
    if [[ -f ~/.secrets ]]; then
        local perm; perm=$(stat -c %a ~/.secrets 2>/dev/null || stat -f %Lp ~/.secrets 2>/dev/null)
        if [[ "$perm" == 600 ]]; then echo -e "  $ok ~/.secrets is private (600)"; else echo -e "  $warn ~/.secrets is $perm — run: chmod 600 ~/.secrets"; fi
    fi
    _sb_enabled menu   || echo -e "  $warn startup menu is off (sb on menu)"
    _sb_enabled banner || echo -e "  $warn startup banner is off (sb on banner)"

    echo -e "\n${SB_BOLD_CYAN}── Dependencies ──${SB_RESET}"
    for t in git curl fzf; do
        if _sb_has "$t"; then echo -e "  $ok $t"; else echo -e "  $bad $t (required)"; fi
    done
    for t in lsd rg zoxide zellij jq nmap docker; do
        if _sb_has "$t"; then echo -e "  $ok $t"; else echo -e "  $warn $t (optional)"; fi
    done
    if _sb_has bat || _sb_has batcat; then echo -e "  $ok bat"; else echo -e "  $warn bat (optional)"; fi
    echo -e "  ${SB_DIM}package manager: $(_sb_pkg_manager || echo none)${SB_RESET}"

    echo -e "\n${SB_BOLD_CYAN}── Startup time ──${SB_RESET}"
    local start end ms
    start=$(date +%s%N)
    SB_NO_GREET=1 bash -i -c exit &>/dev/null < /dev/null
    end=$(date +%s%N)
    ms=$(( (end - start) / 1000000 ))
    if (( ms < 150 )); then echo -e "  $ok new shell in ${ms} ms"
    elif (( ms < 400 )); then echo -e "  $warn new shell in ${ms} ms"
    else echo -e "  $bad new shell in ${ms} ms — try: bash -x -i -c exit 2>&1 | less"
    fi

    echo -e "\n${SB_BOLD_CYAN}── SSH agent ──${SB_RESET}"
    local agents; agents=$(pgrep -u "$USER" -c ssh-agent 2>/dev/null || echo 0)
    if (( agents <= 1 )); then echo -e "  $ok $agents ssh-agent running"
    else echo -e "  $warn $agents ssh-agents running — stale ones can go: pkill -u $USER ssh-agent (then open a new shell)"
    fi
}

sb() {
    local cmd="${1:-help}"; shift 2>/dev/null
    case "$cmd" in
        help|-h|--help) _sb_help ;;
        update)         _sb_update ;;
        doctor)         _sb_doctor ;;
        on|off)
            local feature="$1"
            if [[ "$feature" != menu && "$feature" != banner ]]; then
                echo "Usage: sb $cmd menu|banner"; return 1
            fi
            command mkdir -p "$SB_CONFIG_DIR"
            if [[ "$cmd" == off ]]; then
                touch "$SB_CONFIG_DIR/$feature.off"
            else
                command rm -f -- "$SB_CONFIG_DIR/$feature.off"
            fi
            echo -e "${SB_BOLD_GREEN}✅ Startup $feature: $cmd${SB_RESET}"
            ;;
        cache)
            if [[ "$1" == clear ]]; then
                [[ -d "${SB_CACHE_DIR:?}" ]] && command rm -f -- "${SB_CACHE_DIR:?}"/* 2>/dev/null
                echo -e "${SB_BOLD_GREEN}✅ Cache cleared.${SB_RESET}"
            else
                echo "Usage: sb cache clear"; return 1
            fi
            ;;
        uninstall)      bash "$SMART_BASH_DIR/uninstall.sh" ;;
        *)              echo "Unknown command: $cmd"; _sb_help; return 1 ;;
    esac
}

# Tab completion for sb
_sb_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
        sb)     mapfile -t COMPREPLY < <(compgen -W "help update doctor on off cache uninstall" -- "$cur") ;;
        on|off) mapfile -t COMPREPLY < <(compgen -W "menu banner" -- "$cur") ;;
        cache)  mapfile -t COMPREPLY < <(compgen -W "clear" -- "$cur") ;;
    esac
}
complete -F _sb_complete sb
