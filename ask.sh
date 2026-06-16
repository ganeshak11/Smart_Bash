#!/bin/bash
# Terminal AI Assistant using Gemini API

BOLD_CYAN='\033[1;36m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

if [[ -z "$GEMINI_API_KEY" ]]; then
    echo -e "${BOLD_RED}❌ GEMINI_API_KEY environment variable is not set.${RESET}"
    echo -e "Please export your Gemini API key in your .bashrc:"
    echo -e "  export GEMINI_API_KEY='your_key_here'"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${BOLD_RED}❌ jq is required but not installed. (sudo apt install jq)${RESET}"
    exit 1
fi

query="$*"
if [[ -z "$query" ]]; then
    echo -e "${BOLD_YELLOW}Usage: ask <your question>${RESET}"
    exit 1
fi

echo -e "${BOLD_CYAN}🤔 Thinking...${RESET}"

# Minimal payload for gemini-2.5-flash
payload=$(jq -n --arg q "$query" '{"contents":[{"parts":[{"text":$q}]}]}')

response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY")

error=$(echo "$response" | jq -r '.error.message // empty')
if [[ -n "$error" ]]; then
    echo -e "${BOLD_RED}❌ API Error: $error${RESET}"
    exit 1
fi

text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')
if [[ -z "$text" ]]; then
    echo -e "${BOLD_RED}❌ Failed to parse response.${RESET}"
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
