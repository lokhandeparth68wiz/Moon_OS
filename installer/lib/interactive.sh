#!/bin/bash
# MoonOS Installer - Interactive UI Library
# Terminal-based user interface for installation

# Colors
readonly UI_RED='\033[0;31m'
readonly UI_GREEN='\033[0;32m'
readonly UI_YELLOW='\033[1;33m'
readonly UI_BLUE='\033[0;34m'
readonly UI_MAGENTA='\033[0;35m'
readonly UI_CYAN='\033[0;36m'
readonly UI_WHITE='\033[1;37m'
readonly UI_NC='\033[0m'

# Display header
ui_header() {
    local title="$1"
    clear
    echo -e "${UI_CYAN}==========================================${UI_NC}"
    echo -e "${UI_CYAN}  ${UI_WHITE}${title}${UI_NC}"
    echo -e "${UI_CYAN}==========================================${UI_NC}"
    echo ""
}

# Display message
ui_message() {
    local message="$1"
    echo -e "${UI_BLUE}=>${UI_NC} $message"
}

# Display success
ui_success() {
    local message="$1"
    echo -e "${UI_GREEN}=> Success:${UI_NC} $message"
}

# Display warning
ui_warning() {
    local message="$1"
    echo -e "${UI_YELLOW}=> Warning:${UI_NC} $message"
}

# Display error
ui_error() {
    local message="$1"
    echo -e "${UI_RED}=> Error:${UI_NC} $message"
}

# Display question
ui_question() {
    local question="$1"
    echo -e "${UI_CYAN}?${UI_NC} $question"
}

# Get user input
ui_input() {
    local prompt="$1"
    local default="${2:-}"
    local value

    if [[ -n "$default" ]]; then
        echo -n "$prompt [$default]: "
    else
        echo -n "$prompt: "
    fi

    read -r value

    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Get yes/no answer
ui_yesno() {
    local question="$1"
    local default="${2:-y}"

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="(Y/n)"
    else
        prompt="(y/N)"
    fi

    while true; do
        echo -e "${UI_CYAN}?${UI_NC} $question $prompt"
        read -r answer
        answer="${answer:-$default}"

        case "${answer,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer y or n"
                ;;
        esac
    done
}

# Select from list
ui_select() {
    local title="$1"
    shift
    local options=("$@")

    echo -e "${UI_CYAN}?${UI_NC} $title"
    echo ""

    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done

    echo ""
    while true; do
        echo -n "Selection [1-${#options[@]}]: "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
            echo "${options[$((choice-1))]}"
            return 0
        fi
        echo "Invalid selection. Please try again."
    done
}

# Show progress bar
ui_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"

    if [[ "$current" -eq "$total" ]]; then
        echo ""
    fi
}

# Show spinner
ui_spinner() {
    local pid=$1
    local message="${2:-Working}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spin}; i++ )); do
            printf "\r  ${spin:$i:1} $message"
            sleep 0.1
        done
    done

    printf "\r  ✓ $message\n"
}

# Show box
ui_box() {
    local title="$1"
    local content="$2"
    local width="${3:-60}"

    local border
    border=$(printf '%*s' "$width" '' | tr ' ' '─')

    echo "┌${border}┐"
    printf "│ %-$((width-2))s │\n" "$title"
    echo "├${border}┤"

    while IFS= read -r line; do
        printf "│ %-$((width-2))s │\n" "$line"
    done <<< "$content"

    echo "└${border}┘"
}

# Show progress step
ui_step() {
    local step="$1"
    local total="$2"
    local message="$3"

    echo -e "\n${UI_MAGENTA}[$step/$total]${UI_NC} ${UI_WHITE}$message${UI_NC}"
}

# Clear line
ui_clear_line() {
    printf "\033[2K"
}

# Move cursor up
ui_cursor_up() {
    local lines="${1:-1}"
    printf "\033[%sA" "$lines"
}

# Move cursor down
ui_cursor_down() {
    local lines="${1:-1}"
    printf "\033[%sB" "$lines"
}

# Hide cursor
ui_cursor_hide() {
    printf "\033[?25l"
}

# Show cursor
ui_cursor_show() {
    printf "\033[?25h"
}

# Wait for keypress
ui_wait_key() {
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Clear screen
ui_clear() {
    clear
}
