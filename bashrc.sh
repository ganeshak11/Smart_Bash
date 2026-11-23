#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Smart Bash — main config  (https://github.com/ganeshak11/Smart_Bash)        ║
# ║                                                                              ║
# ║  Don't copy this file. ~/.bashrc just sources it:                            ║
# ║      source ~/Smart_Bash/bashrc.sh                                           ║
# ║  so `sb update` (a git pull) is all it takes to get new versions.            ║
# ║  Your personal aliases / functions go in ~/.bashrc.local (never touched).    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Parse this file WITHOUT alias expansion, so aliases you already have (say an
# alias named `reload` in ~/.bash_aliases) can't mangle the function
# definitions below. Re-enabled before ~/.bashrc.local is loaded.
shopt -u expand_aliases

# ── Core paths & shared library ───────────────────────────────────────────────
export SMART_BASH_DIR="${SMART_BASH_DIR:-$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SMART_BASH_DIR/lib.sh"

# IDE terminals (VS Code, etc.) get the config but no menu/banner/heavy extras
_SB_IDE_SHELL=false
[[ -n "${VSCODE_INJECTION:-}" || -n "${TERM_PROGRAM:-}" ]] && _SB_IDE_SHELL=true
# ──────────────────────────────────────────────────────────────────────────────

# ── Environment Variables & Paths ─────────────────────────────────────────────
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
export NVM_DIR="$HOME/.nvm"

# Load secrets securely (API keys live in ~/.secrets, never in ~/.bashrc)
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
# ──────────────────────────────────────────────────────────────────────────────

# ── Shell Options & History ───────────────────────────────────────────────────
shopt -s checkwinsize
shopt -s globstar 2>/dev/null

HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%d/%m %T "
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
# ──────────────────────────────────────────────────────────────────────────────

# ── Prompt ────────────────────────────────────────────────────────────────────
# Environment (SSH / Docker / VM / root) is detected ONCE here, not per prompt.
_sb_detect_env

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color|xterm-kitty) color_prompt=yes;;
esac

# __git_ps1 normally comes from bash-completion; load it directly if not
if ! declare -F __git_ps1 &>/dev/null; then
    for _f in /usr/lib/git-core/git-sh-prompt /usr/share/git-core/contrib/completion/git-prompt.sh \
              /usr/share/git/completion/git-prompt.sh /opt/homebrew/etc/bash_completion.d/git-prompt.sh; do
        [ -r "$_f" ] && { source "$_f"; break; }
    done
    unset _f
    declare -F __git_ps1 &>/dev/null || __git_ps1() { :; }
fi

# Runs first in PROMPT_COMMAND: records the last exit code without a subshell
_sb_prompt_status() {
    if [[ $? -eq 0 ]]; then _SB_DOT=$'\e[1;32m'; else _SB_DOT=$'\e[1;31m'; fi
}
# Sync history across all zellij/tmux panes in real time (added only once,
# so re-sourcing doesn't keep growing PROMPT_COMMAND)
if [[ "$PROMPT_COMMAND" != *_sb_prompt_status* ]]; then
    PROMPT_COMMAND="_sb_prompt_status; history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[${_SB_DOT}\]● \[${SB_ENV_COLOR}\]\u\[\e[0m\] \[\e[38;5;81m\]\w\[\e[38;5;214m\]$(__git_ps1 " (%s)")\[\e[38;5;245m\] [${SB_ENV_ICON}:${SB_ENV_NAME}]\[\e[0m\]\n\[${SB_ENV_COLOR}\]❯\[\e[38;5;81m\]❯\[\e[38;5;214m\]❯\[\e[0m\] '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

if [ -x /usr/bin/dircolors ]; then
    if [ -r ~/.dircolors ]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
# ──────────────────────────────────────────────────────────────────────────────

# ── Autocompletions & Integrations ────────────────────────────────────────────
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Cargo
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# SSH agent — ONE shared agent on a fixed socket, reused by every shell.
# (Previously each new shell without SSH_AUTH_SOCK spawned its own agent and
#  never stopped it, so agents piled up.)
if [ -z "$SSH_AUTH_SOCK" ] && _sb_has ssh-agent; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-$HOME/.ssh}/smart-bash-ssh-agent.sock"
    ssh-add -l &>/dev/null; _sb_rc=$?
    if [ "$_sb_rc" -eq 2 ]; then
        # 2 = no agent listening on the socket: clear a stale socket, start one
        command rm -f -- "$SSH_AUTH_SOCK"
        ssh-agent -a "$SSH_AUTH_SOCK" &>/dev/null
        ssh-add -l &>/dev/null; _sb_rc=$?
    fi
    # 1 = agent running but empty: load the default key once
    [ "$_sb_rc" -eq 1 ] && [ -f ~/.ssh/id_ed25519 ] && ssh-add ~/.ssh/id_ed25519 2>/dev/null
    unset _sb_rc
fi

# zoxide: smart cd
_sb_has zoxide && eval "$(zoxide init bash)"

# fzf: fuzzy finder (Ctrl+R history, Ctrl+T files, Alt+C dirs)
for _f in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/key-bindings.bash \
          /usr/share/fzf/shell/key-bindings.bash /opt/homebrew/opt/fzf/shell/key-bindings.bash; do
    [ -f "$_f" ] && { source "$_f"; break; }
done
unset _f
[ -f /usr/share/bash-completion/completions/fzf ] && source /usr/share/bash-completion/completions/fzf
export FZF_DEFAULT_OPTS="
  --height 40% --border rounded --layout=reverse --info=inline
  --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
  --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
  --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
_sb_has rg && export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'

# Kali-style command-not-found auto-installer (Debian/Ubuntu helper; other
# distros fall back to a plain message)
command_not_found_handle() {
    local cmd="$1" pkg=""
    if [ -x /usr/lib/command-not-found ]; then
        pkg=$(/usr/lib/command-not-found "$cmd" 2>&1 | grep -oP 'apt install \K\S+' | head -1)
    fi
    if [ -n "$pkg" ] && [ -t 0 ]; then
        echo -e "\n\e[1;33m⚠️  Command '\e[1;37m$cmd\e[1;33m' not found.\e[0m"
        echo -e "\e[1;36m📦 Available as package: \e[1;32m$pkg\e[0m\n"
        read -r -p $'\e[1;35m❯ Install now? [y/N]: \e[0m' answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo ""
            _sb_pkg_install "$pkg"
            return
        fi
        echo -e "\e[1;31m✖ Cancelled.\e[0m"
    else
        echo -e "\e[1;31m❌ '$cmd': command not found\e[0m"
    fi
    return 127
}
# ──────────────────────────────────────────────────────────────────────────────

# ── Aliases ───────────────────────────────────────────────────────────────────
if [ -f ~/.bash_aliases ]; then
    shopt -s expand_aliases; . ~/.bash_aliases; shopt -u expand_aliases
fi

# Core Utils
alias cp='cp -i'
alias mv='mv -i'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# reload: re-read the config without re-opening the startup menu
unalias reload 2>/dev/null
reload() { clear; local SB_NO_GREET=1; source ~/.bashrc; }

# lsd
if _sb_has lsd; then
    alias ls='lsd'
    alias ll='lsd -alF'
    alias la='lsd -A'
    alias l='lsd -CF'
    alias lt='lsd --tree'
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

# bat: syntax-highlighted cat (theme overridable with SB_BAT_THEME)
export SB_BAT_THEME="${SB_BAT_THEME:-Dracula}"
if _sb_has batcat; then
    alias cat='batcat --paging=never --theme="$SB_BAT_THEME"'
    alias bat='batcat --theme="$SB_BAT_THEME"'
    alias ccat='/usr/bin/cat'
    alias batdiff='batcat --diff'
    export MANPAGER="sh -c 'col -bx | batcat -l man -p --theme=\"\$SB_BAT_THEME\"'"
elif _sb_has bat; then
    alias cat='bat --paging=never --theme="$SB_BAT_THEME"'
    alias ccat='/usr/bin/cat'
    export MANPAGER="sh -c 'col -bx | bat -l man -p --theme=\"\$SB_BAT_THEME\"'"
fi

# ripgrep
alias rgh='rg --hidden'
alias rgi='rg -i'

# Dev & Git
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate --all'
alias gco='git checkout'
alias gb='git branch -a'
alias gst='git stash'
alias gstp='git stash pop'

# autopush: stage everything, commit with a timestamp, and push
# Usage: autopush            → uses "auto: YYYY-MM-DD HH:MM:SS"
#        autopush "my note"  → uses "auto: my note — YYYY-MM-DD HH:MM:SS"
autopush() {
    local timestamp; timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local msg="auto: $timestamp"
    [ -n "$1" ] && msg="auto: $* — $timestamp"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "\e[1;31m❌ Not inside a git repository.\e[0m"
        return 1
    fi

    if git add . && git commit -m "$msg" && git push; then
        echo -e "\e[1;32m✅ Pushed: \"$msg\"\e[0m"
    else
        echo -e "\e[1;31m❌ autopush failed. Check git status.\e[0m"
        return 1
    fi
}

# Media & Applications
alias brave='brave-browser > /dev/null 2>&1 &'
alias music='audacious > /dev/null 2>&1 &'

# TUI & Aesthetics
alias zj='zellij'
alias hack='zellij --layout ~/.config/zellij/layouts/hacker.kdl'
alias matrix='cmatrix -C cyan'
alias neo='btop'
alias lg='lazygit'
alias v='vim'
alias nv='nvim'
alias r='ranger'

# Smart Bash tools
alias cheat='$SMART_BASH_DIR/cheat.sh'
alias cheats='$SMART_BASH_DIR/cheat.sh'
alias sgit='$SMART_BASH_DIR/sgit.sh'
alias ask='$SMART_BASH_DIR/ask.sh'
alias netops='$SMART_BASH_DIR/netops.sh'
alias zgen='$SMART_BASH_DIR/zgen.sh'
alias slog='$SMART_BASH_DIR/slog.sh'
alias syncenv='$SMART_BASH_DIR/sync_env.sh'
alias menu='smart_menu_run'
# ──────────────────────────────────────────────────────────────────────────────

# ── Functions ─────────────────────────────────────────────────────────────────
# mkcd: create a directory and enter it (mkdir itself is left untouched)
mkcd() {
    [ -z "$1" ] && { echo "Usage: mkcd <dir>"; return 1; }
    command mkdir -p -- "$1" && builtin cd -- "$1" && echo "📁 Created and entered: $(pwd)"
}

# cdf: Interactive dir picker
cdf() {
    local dirs=(*/)
    select dir in "${dirs[@]}"; do
        [ -n "$dir" ] && builtin cd "$dir" || return
        break
    done
}

# y: Yazi file manager with cwd support
y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd" || return
    fi
    command rm -f -- "$tmp"
}

# ld: Numbered directory list with lsd icons
# Usage: ld         → list with numbers
#        ld -a      → include hidden files
#        ld -l      → detailed view
#        ld -la     → detailed + hidden
unalias ld 2>/dev/null  # grc and others alias ld; keep our function
ld() {
    local show_hidden=false show_details=false arg
    for arg in "$@"; do
        case "$arg" in
            -*)
                [[ "$arg" == *a* ]] && show_hidden=true
                [[ "$arg" == *l* ]] && show_details=true
                ;;
        esac
    done

    local dotglob_status nullglob_status
    dotglob_status=$(shopt -p dotglob)
    nullglob_status=$(shopt -p nullglob)
    [ "$show_hidden" = true ] && shopt -s dotglob
    shopt -s nullglob

    local dirs=(*/) all_files=(*)
    eval "$dotglob_status"; eval "$nullglob_status"

    local pure_files=() f
    for f in "${all_files[@]}"; do [[ ! -d "$f" ]] && pure_files+=("$f"); done
    __LD_DIRS=("${dirs[@]}")   # global, read by `cd N`

    [ ${#all_files[@]} -eq 0 ] && { echo "Directory is empty."; return; }

    if [ ${#dirs[@]} -gt 0 ]; then
        if _sb_has lsd; then
            local flag=-1d; [ "$show_details" = true ] && flag=-ld
            lsd "$flag" --color=always --icon=always "${dirs[@]}" 2>/dev/null | awk '{printf "\033[1;36m%3d\033[0m %s\n", NR, $0}'
        else
            local i=1 d
            for d in "${dirs[@]}"; do printf "\e[1;36m%3d\e[0m \e[1;34m%s\e[0m\n" "$i" "$d"; ((i++)); done
        fi
    fi

    if [ ${#pure_files[@]} -gt 0 ]; then
        if _sb_has lsd; then
            local flag=-1d; [ "$show_details" = true ] && flag=-ld
            lsd "$flag" --color=always --icon=always "${pure_files[@]}" 2>/dev/null | awk '{print "    " $0}'
        else
            for f in "${pure_files[@]}"; do printf "    %s\n" "$f"; done
        fi
    fi
}

# List directory contents after a jump — lsd if available, plain ls otherwise
_cd_list() {
    if _sb_has lsd; then lsd; else command ls --color=auto; fi
}

# cd: Numbered jump (use after ld) + auto-create missing directories
cd() {
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ ! -d "$1" ]]; then
        [ ${#__LD_DIRS[@]} -eq 0 ] && { echo -e "\e[1;31m❌ No directories cached. Run 'ld' first.\e[0m"; return 1; }
        { [ "$1" -gt ${#__LD_DIRS[@]} ] || [ "$1" -lt 1 ]; } && { echo -e "\e[1;31m❌ Invalid number: $1\e[0m"; return 1; }
        builtin cd "${__LD_DIRS[$(( $1 - 1 ))]}" && _cd_list; return
    fi
    if [ -d "$1" ] || [ -z "$1" ] || [[ "$1" =~ ^- ]]; then
        builtin cd "$@" && _cd_list
    elif [ -t 0 ]; then
        echo -e "\e[1;33m⚠️  Directory '$1' does not exist.\e[0m"
        read -r -p $'\e[1;35m❯ Create it now? [y/N]: \e[0m' answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            command mkdir -p -- "$1" && builtin cd -- "$1" && _cd_list
        else
            return 1
        fi
    else
        builtin cd "$@" || return
    fi
}

# extract: universal archive extractor
extract() {
    [ -f "$1" ] || { echo "❌ '$1' is not a valid file"; return 1; }
    case "$1" in
        *.tar.bz2) tar xjf "$1" ;; *.tar.gz)  tar xzf "$1" ;; *.tar.xz)  tar xJf "$1" ;;
        *.bz2)     bunzip2 "$1"  ;; *.rar)     unrar x "$1" ;; *.gz)      gunzip "$1"   ;;
        *.tar)     tar xf "$1"   ;; *.tbz2)    tar xjf "$1" ;; *.tgz)     tar xzf "$1"  ;;
        *.zip)     unzip "$1"    ;; *.Z)       uncompress "$1" ;; *.7z)   7z x "$1"     ;;
        *) echo "❌ Don't know how to extract '$1'"; return 1 ;;
    esac && echo "✅ Extracted: $1"
}

# weather: show current weather for a city
weather() {
    curl -s --max-time 5 "wttr.in/${1:-}?format=3" 2>/dev/null || echo "🌐 No internet connection"
}

# System Info
alias myip='curl -s --max-time 5 https://api.ipify.org && echo ""'
alias ports='ss -tulnp | grep LISTEN'

pid() {
    local result; result=$(fuser "${1}/tcp" 2>/dev/null)
    if [ -n "$result" ]; then echo "🔍 Port $1 → PID: $result"; else echo "❌ Nothing is running on port $1"; fi
}

killport() {
    [ -z "$1" ] && { echo -e "\e[1;31m❌ Specify a port (e.g., killport 3000)\e[0m"; return 1; }
    local pid; pid=$(lsof -t -i:"$1" 2>/dev/null)
    [ -z "$pid" ] && { echo -e "\e[1;33m⚠️  No process on port $1.\e[0m"; return 1; }
    local proc_name; proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    echo -e "\e[1;36m🔍 '\e[1;32m$proc_name\e[1;36m' (PID: $pid) is on port $1.\e[0m"
    read -r -p $'\e[1;35m❯ Kill it? [y/N]: \e[0m' answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        kill -9 "$pid" && echo -e "\e[1;32m✅ Killed.\e[0m"
    else
        echo -e "\e[1;31m✖ Cancelled.\e[0m"
    fi
}

countdown() {
    local total="${1:-10}" i
    for (( i=total; i>=0; i-- )); do
        local pct=$(( i * 100 / total ))
        local color
        if   (( pct > 50 )); then color="\e[1;32m"
        elif (( pct > 25 )); then color="\e[1;33m"
        else                      color="\e[1;31m"
        fi
        local filled=$(( (total - i) * 20 / total )) empty
        empty=$(( 20 - filled ))
        local bar
        bar=$(printf '%*s' "$filled" '' | sed 's/ /█/g')
        bar+=$(printf '%*s' "$empty" '' | sed 's/ /░/g')
        printf "\r${color}⏱  [%s] %3ds remaining\e[0m" "$bar" "$i"
        sleep 1
    done
    printf "\r\e[1;32m✅  Done!%-30s\e[0m\n" " "; printf "\a"
}

unalias scan 2>/dev/null
scan() {
    _sb_has nmap || { echo -e "\e[1;31m❌ nmap not installed.\e[0m"; return 1; }
    local route_info; route_info=$(ip route get 8.8.8.8 2>/dev/null)
    [ -z "$route_info" ] && { echo -e "\e[1;31m❌ No active routing interface.\e[0m"; return 1; }
    local interface; interface=$(echo "$route_info" | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}')
    local subnet; subnet=$(ip addr show "$interface" | grep -w inet | awk '{print $2}' | head -1)
    echo -e "\e[1;36m🔍 Scanning $subnet on $interface...\e[0m"
    nmap -sn "$subnet"
}
# ──────────────────────────────────────────────────────────────────────────────

# ── Lazy Loaders ──────────────────────────────────────────────────────────────
_sb_load_nvm() {
    unset -f nvm node npm npx _sb_load_nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _sb_load_nvm; nvm  "$@"; }
node() { _sb_load_nvm; node "$@"; }
npm()  { _sb_load_nvm; npm  "$@"; }
npx()  { _sb_load_nvm; npx  "$@"; }
# ──────────────────────────────────────────────────────────────────────────────

# ── Smart Bash modules ────────────────────────────────────────────────────────
source "$SMART_BASH_DIR/sb.sh"     # the `sb` command
source "$SMART_BASH_DIR/dops.sh"   # Smart Docker Manager

smart_menu_run() {
    source "$SMART_BASH_DIR/smart_menu.sh"
    source "$SMART_BASH_DIR/launch.sh"
}
# ──────────────────────────────────────────────────────────────────────────────

# ── Personal config (aliases, paths, extra tools) — survives updates ──────────
shopt -s expand_aliases
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
# ──────────────────────────────────────────────────────────────────────────────

# ── Startup: menu / banner ────────────────────────────────────────────────────
# Only in a real interactive terminal: not in IDEs, not on raw VT consoles
# (tty2-9), not in yakuake, not when SB_NO_GREET=1 (used by `reload`, `sb`).
_sb_should_greet() {
    [[ $- == *i* && -t 0 && -t 1 ]] || return 1
    [[ -z "${SB_NO_GREET:-}" && "$_SB_IDE_SHELL" == false ]] || return 1
    [[ "$(tty 2>/dev/null)" == /dev/tty[2-9]* ]] && return 1
    [[ "$(ps -p $PPID -o comm= 2>/dev/null)" == yakuake ]] && return 1
    return 0
}

if _sb_should_greet; then
    if [[ -n "${ZELLIJ:-}" ]]; then
        # Stats in Zellij panes (Browse / Give me Zellij) — shown once, then reset
        if [[ "${SMART_MENU_SHOW_STATS:-0}" == "1" ]]; then
            bash "$SMART_BASH_DIR/terminal_banner_v2.sh" --stats
            export SMART_MENU_SHOW_STATS=0
        fi
    elif _sb_enabled menu; then
        smart_menu_run
    elif _sb_enabled banner; then
        bash "$SMART_BASH_DIR/terminal_banner_v2.sh"
    fi
fi
# ──────────────────────────────────────────────────────────────────────────────
