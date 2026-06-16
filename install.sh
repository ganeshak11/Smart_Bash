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

    # Install zellij hacker layout
    if command -v zellij &>/dev/null; then
        mkdir -p "$HOME/.config/zellij/layouts"
        cp "$SMART_BASH_DIR/zellij/layouts/hacker.kdl" "$HOME/.config/zellij/layouts/hacker.kdl"
        success "Zellij hacker layout installed (~/.config/zellij/layouts/hacker.kdl)"
        info "Launch it with: hack"
    else
        warning "zellij not found — skipping layout install. Install zellij first, then re-run this script."
    fi

    # Set up Smart Menu config — ask user where their projects live
    setup_smart_menu_conf
}

# ── Smart Menu project directory setup ───────────────────────────────────────
setup_smart_menu_conf() {
    local conf="$HOME/.smart_menu.conf"

    echo ""
    echo -e "  ${MAGENTA}${BOLD}[Smart Menu Setup]${RESET}  Where do you keep your projects?"
    echo -e "  ${CYAN}→${RESET}  Press Enter after each path. Type ${BOLD}done${RESET} when finished."
    echo -e "  ${CYAN}→${RESET}  Example: ${BOLD}~/projects${RESET}  or  ${BOLD}/home/user/work${RESET}"
    echo ""

    local dev_dirs=()

    # Suggest common directories that actually exist
    local suggestions=("$HOME/dev" "$HOME/projects" "$HOME/code" "$HOME/work" "$HOME/repos")
    local found_suggestions=()
    for s in "${suggestions[@]}"; do
        [ -d "$s" ] && found_suggestions+=("$s")
    done

    if [ ${#found_suggestions[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}Found these on your system:${RESET}"
        for s in "${found_suggestions[@]}"; do
            echo -e "    ${BOLD}$s${RESET}"
        done
        echo ""
        read -r -p "  Use these? [Y/n]: " use_found
        if [[ ! "$use_found" =~ ^[Nn]$ ]]; then
            dev_dirs=("${found_suggestions[@]}")
        fi
    fi

    # Let the user add more or override
    echo -e "  ${CYAN}→${RESET}  Add more directories (or type ${BOLD}done${RESET} to skip):"
    while true; do
        read -r -p "  Path: " extra_dir
        [[ "$extra_dir" == "done" || -z "$extra_dir" ]] && break
        # Expand ~ manually
        extra_dir="${extra_dir/#\~/$HOME}"
        if [ -d "$extra_dir" ]; then
            dev_dirs+=("$extra_dir")
            success "Added: $extra_dir"
        else
            echo -e "  ${YELLOW}⚠${RESET}  Directory not found — creating it..."
            mkdir -p "$extra_dir" && dev_dirs+=("$extra_dir") && success "Created and added: $extra_dir"
        fi
    done

    # Fall back to ~/dev if user gave nothing
    if [ ${#dev_dirs[@]} -eq 0 ]; then
        warning "No directories provided — defaulting to ~/dev"
        mkdir -p "$HOME/dev"
        dev_dirs=("$HOME/dev")
    fi

    # Build the array string for the conf file
    local dirs_str="("
    for d in "${dev_dirs[@]}"; do
        dirs_str+="\"$d\" "
    done
    dirs_str="${dirs_str% })"

    cat > "$conf" <<EOF
# Smart Menu Configuration — auto-generated by install.sh
# Edit this file to change where Smart Menu looks for your projects.
SMART_MENU_DEV_DIRS=$dirs_str
SMART_MENU_EDITORS=("VS Code:code" "Cursor:cursor" "Neovim:nvim" "None (Just cd to dir):none")
EOF
    chmod 600 "$conf"
    success "~/.smart_menu.conf configured with ${#dev_dirs[@]} director$([ ${#dev_dirs[@]} -eq 1 ] && echo y || echo ies)"
    info "Edit ~/.smart_menu.conf anytime to add more project folders"
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
