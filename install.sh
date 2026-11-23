#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                      Smart Bash — Installer v2.0                             ║
# ║          https://github.com/ganeshak11/Smart_Bash                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   git clone https://github.com/ganeshak11/Smart_Bash.git ~/Smart_Bash
#   bash ~/Smart_Bash/install.sh
#
# What it does:
#   • installs dependencies with apt, dnf, pacman, zypper or brew
#   • backs up ~/.bashrc and replaces it with a 3-line stub that SOURCES this
#     repo's bashrc.sh — nothing is copied, so `sb update` (git pull) is enough
#   • creates ~/.bashrc.local for your own aliases (never overwritten)
#
# Flags: --no-deps  skip dependency installation

set -e

SMART_BASH_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SMART_BASH_DIR/lib.sh"

BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
STUB_MARKER="# >>> smart-bash >>>"

BOLD=$'\e[1m'

banner() {
    echo ""
    echo -e "${SB_BOLD_MAGENTA}"
    echo "  ███████╗███╗   ███╗ █████╗ ██████╗ ████████╗    ██████╗  █████╗ ███████╗██╗  ██╗"
    echo "  ██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██╔════╝██║  ██║"
    echo "  ███████╗██╔████╔██║███████║██████╔╝   ██║       ██████╔╝███████║███████╗███████║"
    echo "  ╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║       ██╔══██╗██╔══██║╚════██║██╔══██║"
    echo "  ███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║       ██████╔╝██║  ██║███████║██║  ██║"
    echo "  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
    echo -e "${SB_RESET}"
    echo -e "  ${SB_BOLD_CYAN}A powerful, aesthetic, and organized Bash configuration${SB_RESET}"
    echo -e "  ${SB_BOLD_YELLOW}──────────────────────────────────────────────────────${SB_RESET}"
    echo ""
}

info()    { echo -e "  ${SB_BOLD_CYAN}→${SB_RESET}  $1"; }
success() { echo -e "  ${SB_BOLD_GREEN}✔${SB_RESET}  $1"; }
warning() { echo -e "  ${SB_BOLD_YELLOW}⚠${SB_RESET}  $1"; }
error()   { echo -e "  ${SB_BOLD_RED}✘${SB_RESET}  $1"; exit 1; }
step()    { echo -e "\n  ${SB_BOLD_MAGENTA}[$1]${SB_RESET}  $2"; }

# ── Dependencies ──────────────────────────────────────────────────────────────
# install_if_missing <command> <package>   (package name is the same on all
# supported managers for everything we need, except bat → batcat on Debian)
install_if_missing() {
    local cmd="$1" pkg="$2"
    if _sb_has "$cmd"; then
        success "$cmd is already installed"
    else
        warning "$cmd not found — installing $pkg..."
        if _sb_pkg_install "$pkg" &>/dev/null; then
            success "$cmd installed"
        else
            warning "Could not auto-install $cmd. Please install '$pkg' manually."
        fi
    fi
}

install_zellij() {
    if _sb_has zellij; then success "zellij is already installed"; return; fi
    local pm; pm=$(_sb_pkg_manager || true)
    if [[ "$pm" == pacman || "$pm" == brew ]]; then
        install_if_missing zellij zellij
        return
    fi
    # Others: official release binary into ~/.local/bin (no sudo needed)
    warning "zellij not found — downloading the latest release..."
    local arch os url tmp
    arch=$(uname -m); [[ "$arch" == arm64 ]] && arch=aarch64
    case "$(uname -s)" in
        Darwin) os="apple-darwin" ;;
        *)      os="unknown-linux-musl" ;;
    esac
    url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-${os}.tar.gz"
    tmp=$(mktemp -d)
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL "$url" | tar xz -C "$tmp" && mv "$tmp/zellij" "$HOME/.local/bin/zellij"; then
        success "zellij installed to ~/.local/bin"
    else
        warning "Could not install zellij automatically. See: https://zellij.dev/documentation/installation"
    fi
    rm -rf -- "${tmp:?}"
}

check_dependencies() {
    step "1/4" "Checking & installing dependencies"

    local pm; pm=$(_sb_pkg_manager || true)
    if [[ -z "$pm" ]]; then
        warning "No supported package manager found (apt, dnf, pacman, zypper, brew) — skipping."
        warning "Install manually: git curl fzf lsd bat ripgrep zoxide jq nmap zellij"
        return
    fi
    info "Package manager: $pm"

    info "Updating package index..."
    case "$pm" in
        apt-get) sudo apt-get update -qq ;;
        pacman)  sudo pacman -Sy --noconfirm &>/dev/null ;;
        zypper)  sudo zypper -n refresh &>/dev/null ;;
        brew)    brew update &>/dev/null ;;
    esac || warning "Package index update failed — continuing"

    install_if_missing git     git
    install_if_missing curl    curl
    install_if_missing fzf     fzf
    install_if_missing lsd     lsd
    if [[ "$pm" == apt-get ]]; then install_if_missing batcat bat; else install_if_missing bat bat; fi
    install_if_missing rg      ripgrep
    install_if_missing zoxide  zoxide
    install_if_missing jq      jq
    install_if_missing nmap    nmap
    install_zellij
}

# ── ~/.bashrc stub ────────────────────────────────────────────────────────────
install_bashrc() {
    step "2/4" "Hooking Smart Bash into ~/.bashrc"

    if [[ -f "$BASHRC" ]] && grep -qF "$STUB_MARKER" "$BASHRC"; then
        success "~/.bashrc already sources Smart Bash — leaving it alone"
        BACKUP=""
        return
    fi

    if [[ -f "$BASHRC" ]]; then
        cp "$BASHRC" "$BACKUP"
        success "Backup saved to: $BACKUP"
    else
        BACKUP=""
    fi

    cat > "$BASHRC" << EOF
$STUB_MARKER
# Smart Bash lives in $SMART_BASH_DIR — update it with: sb update
# Put your own aliases and settings in ~/.bashrc.local, not here.
export SMART_BASH_DIR="$SMART_BASH_DIR"
[ -f "\$SMART_BASH_DIR/bashrc.sh" ] && source "\$SMART_BASH_DIR/bashrc.sh"
# <<< smart-bash <<<
EOF
    success "~/.bashrc now sources $SMART_BASH_DIR/bashrc.sh"

    if [[ ! -f "$HOME/.bashrc.local" ]]; then
        cat > "$HOME/.bashrc.local" << EOF
# ~/.bashrc.local — your personal Bash config. Smart Bash never overwrites this.
# Loaded after Smart Bash's defaults, so anything here wins.
#
# Examples:
#   alias proj='cd ~/dev/my-project'
#   export SB_BAT_THEME="gruvbox-dark"     # theme for cat/bat/man
#   export SMART_BASH_TAG="ME@MYBOX"       # name in the compact banner
EOF
        if [[ -n "$BACKUP" ]]; then
            echo "#" >> "$HOME/.bashrc.local"
            echo "# Your previous ~/.bashrc was saved to $BACKUP —" >> "$HOME/.bashrc.local"
            echo "# copy any personal aliases/functions from it into this file." >> "$HOME/.bashrc.local"
        fi
        success "Created ~/.bashrc.local for your personal aliases"
    else
        success "~/.bashrc.local already exists — kept as is"
    fi
}

# ── Files: secrets, layout, menu config ───────────────────────────────────────
install_files() {
    step "3/4" "Setting up files"

    if [[ ! -f "$HOME/.secrets" ]]; then
        touch "$HOME/.secrets"
        chmod 600 "$HOME/.secrets"
        info "Created ~/.secrets — add your API keys here (never in ~/.bashrc)"
    else
        success "~/.secrets already exists"
    fi

    chmod +x "$SMART_BASH_DIR"/*.sh 2>/dev/null || true
    success "Scripts marked as executable"

    mkdir -p "$HOME/.config/zellij/layouts"
    cp "$SMART_BASH_DIR/zellij/layouts/hacker.kdl" "$HOME/.config/zellij/layouts/hacker.kdl"
    success "Zellij hacker layout installed (launch with: hack)"

    if [[ -f "$HOME/.smart_menu.conf" ]]; then
        success "~/.smart_menu.conf already exists — kept as is"
    elif [[ -t 0 ]]; then
        setup_smart_menu_conf
    else
        info "Non-interactive install — Smart Menu will use ~/dev (edit ~/.smart_menu.conf)"
    fi
}

setup_smart_menu_conf() {
    local conf="$HOME/.smart_menu.conf"

    echo ""
    echo -e "  ${SB_BOLD_MAGENTA}[Smart Menu Setup]${SB_RESET}  Where do you keep your projects?"
    echo -e "  ${SB_BOLD_CYAN}→${SB_RESET}  Press Enter after each path. Type ${BOLD}done${SB_RESET} when finished."
    echo -e "  ${SB_BOLD_CYAN}→${SB_RESET}  Example: ${BOLD}~/projects${SB_RESET}  or  ${BOLD}/home/user/work${SB_RESET}"
    echo ""

    local dev_dirs=() s
    local suggestions=("$HOME/dev" "$HOME/projects" "$HOME/code" "$HOME/work" "$HOME/repos")
    local found_suggestions=()
    for s in "${suggestions[@]}"; do
        [ -d "$s" ] && found_suggestions+=("$s")
    done

    if [ ${#found_suggestions[@]} -gt 0 ]; then
        echo -e "  ${SB_BOLD_YELLOW}Found these on your system:${SB_RESET}"
        for s in "${found_suggestions[@]}"; do echo -e "    ${BOLD}$s${SB_RESET}"; done
        echo ""
        read -r -p "  Use these? [Y/n]: " use_found
        [[ ! "$use_found" =~ ^[Nn]$ ]] && dev_dirs=("${found_suggestions[@]}")
    fi

    echo -e "  ${SB_BOLD_CYAN}→${SB_RESET}  Add more directories (or type ${BOLD}done${SB_RESET} to skip):"
    while true; do
        read -r -p "  Path: " extra_dir
        [[ "$extra_dir" == "done" || -z "$extra_dir" ]] && break
        extra_dir="${extra_dir/#\~/$HOME}"
        if [ -d "$extra_dir" ]; then
            dev_dirs+=("$extra_dir"); success "Added: $extra_dir"
        else
            warning "Directory not found — creating it..."
            mkdir -p "$extra_dir" && dev_dirs+=("$extra_dir") && success "Created and added: $extra_dir"
        fi
    done

    if [ ${#dev_dirs[@]} -eq 0 ]; then
        warning "No directories provided — defaulting to ~/dev"
        mkdir -p "$HOME/dev"
        dev_dirs=("$HOME/dev")
    fi

    {
        echo "# Smart Menu Configuration — auto-generated by install.sh"
        echo "# Edit this file to change where Smart Menu looks for your projects."
        printf 'SMART_MENU_DEV_DIRS=('; printf '%q ' "${dev_dirs[@]}"; echo ')'
        echo 'SMART_MENU_EDITORS=("VS Code:code" "Cursor:cursor" "Neovim:nvim" "None (Just cd to dir):none")'
    } > "$conf"
    chmod 600 "$conf"
    success "~/.smart_menu.conf configured with ${#dev_dirs[@]} director$([ ${#dev_dirs[@]} -eq 1 ] && echo y || echo ies)"
}

# ── Final instructions ────────────────────────────────────────────────────────
finish() {
    step "4/4" "Installation complete!"
    echo ""
    echo -e "  ${SB_BOLD_GREEN}Everything is set up! Here's what to do next:${SB_RESET}"
    echo ""
    echo -e "  ${SB_BOLD_CYAN}1.${SB_RESET} Reload your shell:     ${BOLD}source ~/.bashrc${SB_RESET}"
    echo -e "  ${SB_BOLD_CYAN}2.${SB_RESET} Check everything:      ${BOLD}sb doctor${SB_RESET}"
    echo -e "  ${SB_BOLD_CYAN}3.${SB_RESET} See all commands:      ${BOLD}sb help${SB_RESET}"
    echo -e "  ${SB_BOLD_CYAN}4.${SB_RESET} Your aliases go in:    ${BOLD}~/.bashrc.local${SB_RESET}   (API keys: ${BOLD}~/.secrets${SB_RESET})"
    echo -e "  ${SB_BOLD_CYAN}5.${SB_RESET} Get new versions with: ${BOLD}sb update${SB_RESET}"
    echo ""
    if [[ -n "$BACKUP" ]]; then
        echo -e "  ${SB_BOLD_MAGENTA}Your old ~/.bashrc is backed up at:${SB_RESET} ${BOLD}$BACKUP${SB_RESET}"
        echo -e "  ${SB_BOLD_YELLOW}Undo everything with:${SB_RESET} ${BOLD}sb uninstall${SB_RESET}"
        echo ""
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
banner
if [[ "${1:-}" == "--no-deps" ]]; then
    step "1/4" "Skipping dependencies (--no-deps)"
else
    check_dependencies
fi
install_bashrc
install_files
finish
