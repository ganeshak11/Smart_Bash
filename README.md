<div align="center">

```
███████╗███╗   ███╗ █████╗ ██████╗ ████████╗    ██████╗  █████╗ ███████╗██╗  ██╗
██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██╔════╝██║  ██║
███████╗██╔████╔██║███████║██████╔╝   ██║       ██████╔╝███████║███████╗███████║
╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║       ██╔══██╗██╔══██║╚════██║██╔══██║
███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║       ██████╔╝██║  ██║███████║██║  ██║
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

**A powerful, aesthetic, and fully organized Bash configuration for Linux power users.**

![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Shell](https://img.shields.io/badge/shell-bash-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Fedora%20%7C%20Arch%20%7C%20openSUSE-orange?style=flat-square)
![shellcheck](https://github.com/ganeshak11/Smart_Bash/actions/workflows/shellcheck.yml/badge.svg)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🗂️ **Numbered Directory Navigation** | `ld` lists directories with numbers. `cd 2` jumps to #2 instantly. |
| 🎨 **lsd Icons & Colors** | Every listing has beautiful icons and syntax-colored output. |
| 🔍 **Smart `cd`** | Auto-creates missing directories, shows contents after every jump. |
| 🧠 **Context-Aware Prompt** | Prompt changes color for SSH, Docker, root, and VM environments. |
| ⚡ **Fuzzy Everything** | `fzf` for history (Ctrl+R), files (Ctrl+T), and directories (Alt+C). |
| 🧭 **Zoxide Smart Jumps** | `z projectname` teleports to your most-visited directories. |
| 📦 **Auto-Installer** | Type a missing command → asked to install it on the spot. |
| 🔄 **`sb update`** | Your `~/.bashrc` just *sources* the repo — one `git pull` and you are on the latest version. |
| 🩺 **`sb doctor`** | Checks dependencies, install state, startup time and stray ssh-agents. |
| 🚀 **Fast startup** | IP, weather, Docker and update info are cached and refreshed in the background — no network waits. |
| 🛡️ **Secrets Protection** | API keys live in `~/.secrets`, never in `~/.bashrc`. |
| 🌟 **Dracula Theme** | `bat`, `fzf`, and `man` pages all styled with the Dracula theme. |
| ⏱️ **Countdown Timer** | `countdown 30` — visual progress bar with color shifts. |
| 🔌 **Port Manager** | `killport 3000`, `pid 8080`, `ports` — network ops at a glance. |
| 📡 **Network Scanner** | `scan` — auto-detects and scans your active subnet with nmap. |
| ⚙️ **Lazy NVM Loading** | NVM loads on first use — zero startup delay. |

---

## 🚀 One-Line Install

```bash
git clone https://github.com/ganeshak11/Smart_Bash.git ~/Smart_Bash && bash ~/Smart_Bash/install.sh
```

The installer will:
1. ✅ Install dependencies with **apt, dnf, pacman, zypper or brew** (`lsd`, `bat`, `fzf`, `ripgrep`, `zoxide`, `jq`, `zellij`, …)
2. ✅ Back up your existing `~/.bashrc`
3. ✅ Replace it with a tiny stub that **sources** `~/Smart_Bash/bashrc.sh` — nothing is copied
4. ✅ Create `~/.bashrc.local` for your own aliases, and `~/.secrets` for API keys

Already have the dependencies? `bash install.sh --no-deps`

### How the config is laid out

| File | What it is | Who edits it |
|---|---|---|
| `~/.bashrc` | 5-line stub that sources Smart Bash | nobody |
| `~/Smart_Bash/bashrc.sh` | the Smart Bash config | updated by `sb update` |
| `~/.bashrc.local` | your aliases, paths, extra tools — loaded last, so it wins | **you** |
| `~/.secrets` | API keys (`chmod 600`) | **you** |
| `~/.smart_menu.conf` | where your projects live, which editors to offer | **you** |

---

## 🧰 The `sb` command

```bash
sb help            # every command and alias
sb update          # git pull + reload
sb doctor          # dependencies, install state, startup time, ssh-agents
sb off menu        # stop the startup menu   (sb on menu to bring it back)
sb off banner      # stop the startup banner
sb cache clear     # refetch IP / weather / updates / docker stats
sb uninstall       # restore your old ~/.bashrc
```

---

## 📖 Key Commands

### 🗂️ Navigation
```bash
ld            # Numbered list — dirs with icons + files below
ld -a         # Include hidden files/folders
ld -l         # Detailed view (like ls -l but with numbers)
ld -la        # Detailed + hidden

cd 3          # Jump to folder #3 from the last ld output
cd newdir     # Works as normal, creates dir if it doesn't exist

z projectname # Zoxide smart jump (learns your habits)
```

### 🔧 Utilities
```bash
extract file.tar.gz   # Universal archive extractor (.zip, .rar, .7z, .tar.gz...)
weather               # Current weather at your location
weather London        # Weather for a specific city
countdown 30          # Visual 30-second timer

mkcd my-project       # Create a directory and immediately enter it
```

### 🌐 Network & System
```bash
myip              # Your public IP address
ports             # All listening ports
pid 3000          # Get PID on a specific port
killport 3000     # Interactively kill process on a port
scan              # Scan your active LAN subnet
```

### ⚡ Git Shortcuts
```bash
gs    # git status
ga    # git add .
gc "message"  # git commit -m
gp    # git push
gpl   # git pull
gd    # git diff
gl    # git log (visual tree)
gco   # git checkout
gb    # git branch -a
gst   # git stash
gstp  # git stash pop
```

---

## 🔑 API Keys & Secrets

**Never put API keys directly in `~/.bashrc`.** Add them to `~/.secrets`:

```bash
# ~/.secrets — this file is NOT committed to git
export MY_API_KEY="your-key-here"
export ANOTHER_SECRET="another-value"
```

---

## 📦 Dependencies

The installer handles all of these automatically. For reference:

| Tool | Purpose | Install |
|---|---|---|
| `lsd` | Beautiful `ls` replacement | `apt install lsd` |
| `bat` | Syntax-highlighted `cat` | `apt install bat` |
| `fzf` | Fuzzy finder | `apt install fzf` |
| `ripgrep` | Fast grep | `apt install ripgrep` |
| `zoxide` | Smart cd | `apt install zoxide` |
| `zellij` | Terminal multiplexer | Auto-downloaded from GitHub |
| `nmap` | Network scanner | `apt install nmap` |
| `jq` | JSON for `ask` | `apt install jq` |

Package names are the same on `dnf`, `pacman`, `zypper` and `brew`.
Runtime is Linux-focused: the installer works with Homebrew, but parts of the
banner and `scan` use Linux-only tools (`/proc`, `ip`).

---

## 🪟 Zellij Layout — Hacker Mode

Included in the repo and auto-installed to `~/.config/zellij/layouts/hacker.kdl`.

Launch it any time with:
```bash
hack
```

The layout gives you:
- **Left (60%)** — Main terminal on top, `htop` on the bottom
- **Right (40%)** — `cmatrix` rain on top, live system status (uptime, memory, disk, network) cycling every 5 seconds on the bottom

---

## ↩️ Uninstall / Restore

```bash
sb uninstall
```

It restores your newest pre-Smart-Bash backup (`~/.bashrc.backup.*`), and asks
before removing the zellij layout, menu config and cache. Your `~/.bashrc.local`,
`~/.secrets` and the repo itself are never deleted.

---

## 📝 License

MIT — use it, fork it, share it.
