#!/bin/bash
# Zellij Layout Generator

LAYOUT_DIR="$HOME/.config/zellij/layouts"
mkdir -p "$LAYOUT_DIR"

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

read -r -p $'\e[1;36m❯ Enter a name for this layout: \e[0m' layout_name
[[ -z "$layout_name" ]] && exit 1
layout_name="${layout_name// /_}"

layout_file="$LAYOUT_DIR/${layout_name}.kdl"

# Basic layout generation wizard
echo "layout {" > "$layout_file"
echo "    default_tab_template {" >> "$layout_file"
echo "        pane size=1 borderless=true {" >> "$layout_file"
echo "            plugin location=\"zellij:tab-bar\"" >> "$layout_file"
echo "        }" >> "$layout_file"
echo "        children" >> "$layout_file"
echo "        pane size=2 borderless=true {" >> "$layout_file"
echo "            plugin location=\"zellij:status-bar\"" >> "$layout_file"
echo "        }" >> "$layout_file"
echo "    }" >> "$layout_file"

echo -e "\n${BOLD_CYAN}Configure Panes:${RESET}"

num_panes=$(printf "1\n2\n3\n4" | fzf --prompt="How many panes? > " --height=20% --border=rounded)
[[ -z "$num_panes" ]] && exit 1

echo "    tab name=\"$layout_name\" {" >> "$layout_file"

if [[ "$num_panes" == "1" ]]; then
    echo "        pane" >> "$layout_file"
elif [[ "$num_panes" == "2" ]]; then
    split=$(printf "horizontal\nvertical" | fzf --prompt="Split direction? > " --height=20% --border=rounded)
    echo "        pane split_direction=\"$split\" {" >> "$layout_file"
    echo "            pane" >> "$layout_file"
    echo "            pane" >> "$layout_file"
    echo "        }" >> "$layout_file"
elif [[ "$num_panes" == "3" ]]; then
    echo "        pane split_direction=\"vertical\" {" >> "$layout_file"
    echo "            pane" >> "$layout_file"
    echo "            pane split_direction=\"horizontal\" {" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "            }" >> "$layout_file"
    echo "        }" >> "$layout_file"
elif [[ "$num_panes" == "4" ]]; then
    echo "        pane split_direction=\"vertical\" {" >> "$layout_file"
    echo "            pane split_direction=\"horizontal\" {" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "            }" >> "$layout_file"
    echo "            pane split_direction=\"horizontal\" {" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "                pane" >> "$layout_file"
    echo "            }" >> "$layout_file"
    echo "        }" >> "$layout_file"
fi

echo "    }" >> "$layout_file"
echo "}" >> "$layout_file"

echo -e "${BOLD_GREEN}✅ Layout saved to $layout_file${RESET}"
read -r -p $'\e[1;33m❯ Launch it now? [y/N]: \e[0m' launch
if [[ "$launch" =~ ^[Yy]$ ]]; then
    zellij --layout "$layout_file"
fi
