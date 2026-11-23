#!/bin/bash
# Terminal AI Assistant using Gemini API

# shellcheck disable=SC1091
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [[ -z "$GEMINI_API_KEY" ]]; then
    echo -e "${SB_BOLD_RED}❌ GEMINI_API_KEY environment variable is not set.${SB_RESET}"
    echo -e "Please export your Gemini API key in your .bashrc:"
    echo -e "  export GEMINI_API_KEY='your_key_here'"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${SB_BOLD_RED}❌ jq is required but not installed. Install it with your package manager, e.g. sudo apt install jq${SB_RESET}"
    exit 1
fi

query="$*"
if [[ -z "$query" ]]; then
    echo -e "${SB_BOLD_YELLOW}Usage: ask <your question>${SB_RESET}"
    exit 1
fi

echo -e "${SB_BOLD_CYAN}🤔 Thinking...${SB_RESET}"

# Minimal payload for gemini-2.5-flash
payload=$(jq -n --arg q "$query" '{"contents":[{"parts":[{"text":$q}]}]}')

# Key goes in a header so it doesn't show up in `ps` output or proxy logs
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -d "$payload" \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")

error=$(echo "$response" | jq -r '.error.message // empty')
if [[ -n "$error" ]]; then
    echo -e "${SB_BOLD_RED}❌ API Error: $error${SB_RESET}"
    exit 1
fi

text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')
if [[ -z "$text" ]]; then
    echo -e "${SB_BOLD_RED}❌ Failed to parse response.${SB_RESET}"
    echo "$response"
    exit 1
fi

echo ""
if command -v mdcat &>/dev/null; then
    echo -e "$text" | mdcat
elif command -v bat &>/dev/null; then
    echo -e "$text" | bat --language=markdown --style=plain
else
    echo -e "$text"
fi
echo ""
