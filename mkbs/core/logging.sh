#!/bin/bash
# MKBS Core - Logging functions
# Provides colored output and logging levels

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3
readonly LOG_FATAL=4

# Current log level
MKBS_LOG_LEVEL="${MKBS_LOG_LEVEL:-$LOG_INFO}"

# Log file
MKBS_LOG_FILE="${MKBS_LOG_FILE:-/tmp/mkbs.log}"

_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Write to log file
    echo "[${timestamp}] [${level}] ${message}" >> "$MKBS_LOG_FILE" 2>/dev/null || true

    # Print to stderr with color
    if [[ -t 2 ]]; then
        echo -e "${color}[${level}]${NC} ${message}" >&2
    else
        echo "[${level}] ${message}" >&2
    fi
}

log_debug() {
    if [[ "${MKBS_DEBUG:-0}" -eq 1 ]] || [[ "$MKBS_LOG_LEVEL" -le "$LOG_DEBUG" ]]; then
        _log "DEBUG" "$CYAN" "$1"
    fi
}

log_info() {
    if [[ "$MKBS_LOG_LEVEL" -le "$LOG_INFO" ]]; then
        _log "INFO" "$GREEN" "$1"
    fi
}

log_warn() {
    if [[ "$MKBS_LOG_LEVEL" -le "$LOG_WARN" ]]; then
        _log "WARN" "$YELLOW" "$1"
    fi
}

log_error() {
    if [[ "$MKBS_LOG_LEVEL" -le "$LOG_ERROR" ]]; then
        _log "ERROR" "$RED" "$1"
    fi
}

log_fatal() {
    _log "FATAL" "$RED" "$1"
    exit 1
}

log_step() {
    local step="$1"
    local message="$2"
    echo -e "\n${MAGENTA}==>${NC} ${BLUE}${step}${NC}: ${message}" >&2
}

log_success() {
    echo -e "${GREEN}==> Success:${NC} $1" >&2
}

# Enable/disable verbose mode
set_verbose() {
    MKBS_VERBOSE=1
}

set_debug() {
    MKBS_DEBUG=1
    MKBS_VERBOSE=1
    set -x
}
