#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                      Smart Bash — Installer v1.0                             ║
# ║          https://github.com/ganeshak11/Smart_Bash                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   git clone https://github.com/ganeshak11/Smart_Bash.git ~/Smart_Bash
#   cd ~/Smart_Bash && bash install.sh

set -e

SMART_BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\e[1;31m'; GREEN='\e[1;32m'; CYAN='\e[1;36m'
YELLOW='\e[1;33m'; MAGENTA='\e[1;35m'; RESET='\e[0m'
BOLD='\e[1m'

banner() {
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "  ███████╗███╗   ███╗ █████╗ ██████╗ ████████╗    ██████╗  █████╗ ███████╗██╗  ██╗"
    echo "  ██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██╔════╝██║  ██║"
    echo "  ███████╗██╔████╔██║███████║██████╔╝   ██║       ██████╔╝███████║███████╗███████║"
    echo "  ╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║       ██╔══██╗██╔══██║╚════██║██╔══██║"
    echo "  ███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║       ██████╔╝██║  ██║███████║██║  ██║"
    echo "  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
    echo -e "${RESET}"
    echo -e "  ${CYAN}A powerful, aesthetic, and organized Bash configuration${RESET}"
    echo -e "  ${YELLOW}──────────────────────────────────────────────────────${RESET}"
    echo ""
}

info()    { echo -e "  ${CYAN}→${RESET}  $1"; }
success() { echo -e "  ${GREEN}✔${RESET}  $1"; }
warning() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
error()   { echo -e "  ${RED}✘${RESET}  $1"; exit 1; }
step()    { echo -e "\n  ${MAGENTA}${BOLD}[$1]${RESET}  $2"; }

# ── Dependency Checker & Installer ────────────────────────────────────────────
install_if_missing() {
    local cmd="$1"
    local pkg="${2:-$1}"
    local install_cmd="${3:-sudo apt-get install -y $pkg}"

    if command -v "$cmd" &>/dev/null; then
        success "$cmd is already installed"
    else
        warning "$cmd not found — installing..."
        eval "$install_cmd" &>/dev/null && success "$cmd installed" || warning "Could not auto-install $cmd. Please install it manually: $pkg"
    fi
}

check_dependencies() {
    step "1/4" "Checking & installing dependencies"

    # Update apt index once
    info "Updating package index..."
    sudo apt-get update -qq

    install_if_missing "lsd"       "lsd"       "sudo apt-get install -y lsd"
    install_if_missing "batcat"    "bat"       "sudo apt-get install -y bat"
    install_if_missing "fzf"       "fzf"       "sudo apt-get install -y fzf"
    install_if_missing "rg"        "ripgrep"   "sudo apt-get install -y ripgrep"
    install_if_missing "zoxide"    "zoxide"    "sudo apt-get install -y zoxide"
    install_if_missing "git"       "git"       "sudo apt-get install -y git"
    install_if_missing "curl"      "curl"      "sudo apt-get install -y curl"
    install_if_missing "nmap"      "nmap"      "sudo apt-get install -y nmap"

    # zellij — not on apt, install via cargo or binary release
    if ! command -v zellij &>/dev/null; then
        warning "zellij not found — downloading latest release..."
        local arch; arch=$(uname -m)
        local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-unknown-linux-musl.tar.gz"
        curl -sL "$url" | tar xz -C /tmp && sudo mv /tmp/zellij /usr/local/bin/ && success "zellij installed" || warning "Could not install zellij automatically. See: https://zellij.dev/documentation/installation"
    else
        success "zellij is already installed"
    fi
}

# ── Backup existing .bashrc ───────────────────────────────────────────────────
backup_bashrc() {
    step "2/4" "Backing up existing ~/.bashrc"
    if [ -f "$BASHRC" ]; then
        cp "$BASHRC" "$BACKUP"
        success "Backup saved to: $BACKUP"
    else
        info "No existing ~/.bashrc found — skipping backup"
    fi
}

# ── Install the config ────────────────────────────────────────────────────────
install_config() {
    step "3/4" "Installing Smart Bash config"

    # Copy Smart_Bash scripts
    info "Copying Smart_Bash scripts..."
    mkdir -p "$HOME/Smart_Bash"
    rsync -a --exclude='.git' --exclude='install.sh' "$SMART_BASH_DIR/" "$HOME/Smart_Bash/" 2>/dev/null || \
        cp -r "$SMART_BASH_DIR"/. "$HOME/Smart_Bash/"
    success "Scripts copied to ~/Smart_Bash"

    # Install .bashrc template
    info "Installing ~/.bashrc..."
    cp "$SMART_BASH_DIR/bashrc_template" "$BASHRC"
    success "~/.bashrc installed"

    # Set up .secrets file if it doesn't exist
    if [ ! -f "$HOME/.secrets" ]; then
        touch "$HOME/.secrets"
        chmod 600 "$HOME/.secrets"
        info "Created ~/.secrets — add your API keys here (never in ~/.bashrc)"
    else
        success "~/.secrets already exists"
    fi

    # Make all scripts executable
    chmod +x "$HOME/Smart_Bash"/*.sh 2>/dev/null || true
    success "Scripts marked as executable"
}

# ── Final instructions ────────────────────────────────────────────────────────
finish() {
    step "4/4" "Installation complete!"
    echo ""
    echo -e "  ${GREEN}${BOLD}Everything is set up! Here's what to do next:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Reload your shell:    ${BOLD}source ~/.bashrc${RESET}"
    echo -e "  ${CYAN}2.${RESET} Add your API keys to: ${BOLD}~/.secrets${RESET}"
    echo -e "  ${CYAN}3.${RESET} Try these commands:"
    echo -e "     ${YELLOW}ld${RESET}         → Numbered directory listing with icons"
    echo -e "     ${YELLOW}cd 2${RESET}       → Jump to directory #2 from last ld"
    echo -e "     ${YELLOW}ld -a${RESET}      → Include hidden files"
    echo -e "     ${YELLOW}ld -l${RESET}      → Detailed listing"
    echo -e "     ${YELLOW}killport 3000${RESET} → Kill whatever is on port 3000"
    echo -e "     ${YELLOW}extract file.zip${RESET} → Universal archive extractor"
    echo -e "     ${YELLOW}countdown 30${RESET} → 30-second visual timer"
    echo ""
    echo -e "  ${MAGENTA}Your old ~/.bashrc is backed up at:${RESET}"
    echo -e "  ${BOLD}$BACKUP${RESET}"
    echo ""
    echo -e "  ${YELLOW}If anything looks off, restore with:${RESET}"
    echo -e "  ${BOLD}cp $BACKUP ~/.bashrc && source ~/.bashrc${RESET}"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
banner
check_dependencies
backup_bashrc
install_config
finish
