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
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian-orange?style=flat-square)

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
1. ✅ Back up your existing `~/.bashrc`
2. ✅ Auto-install all dependencies (`lsd`, `bat`, `fzf`, `ripgrep`, `zoxide`, `zellij`, etc.)
3. ✅ Install the Smart Bash config
4. ✅ Set up your `~/.secrets` file

---

## 🛠️ Manual Install

```bash
# 1. Clone the repo
git clone https://github.com/ganeshak11/Smart_Bash.git ~/Smart_Bash

# 2. Back up your existing config
cp ~/.bashrc ~/.bashrc.backup

# 3. Install
bash ~/Smart_Bash/install.sh
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

---

## ↩️ Uninstall / Restore

Your old `~/.bashrc` is automatically backed up before installation:

```bash
# Find your backup (timestamped)
ls ~/.bashrc.backup.*

# Restore it
cp ~/.bashrc.backup.YYYYMMDD_HHMMSS ~/.bashrc
source ~/.bashrc
```

---

## 📝 License

MIT — use it, fork it, share it.
