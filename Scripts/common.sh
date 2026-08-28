#!/bin/bash

# ==========================================
# DevOps Auto Installer - Common Functions
# ==========================================

# ==========================================
# Project Directories
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_DIR="$PROJECT_ROOT/config"
CONFIG_FILE="$CONFIG_DIR/installer.conf"

LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/installer.log"

# ==========================================
# Load Configuration
# ==========================================

if [[ ! -f "$CONFIG_FILE" ]]; then

    echo "[ERROR] Configuration file not found:"
    echo "$CONFIG_FILE"

    exit 1

fi

# Load installer configuration
source "$CONFIG_FILE"

# ==========================================
# Create Required Directories
# ==========================================

mkdir -p "$LOG_DIR"

touch "$LOG_FILE"

# ==========================================
# Colors
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==========================================
# Logging
# ==========================================

log() {

    local MESSAGE="$1"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" >> "$LOG_FILE"

}

# ==========================================
# Reset Installer Log
# ==========================================

reset_log() {

    if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then

        ARCHIVE_LOG="$LOG_DIR/installer-$(date '+%Y%m%d-%H%M%S').log"

        mv "$LOG_FILE" "$ARCHIVE_LOG"

    fi

    touch "$LOG_FILE"

    log "[INFO] New installer log started."

}

# ==========================================
# Message Functions
# ==========================================

info() {

    echo -e "${CYAN}[INFO]${NC} $1"

    log "[INFO] $1"

}

success() {

    echo -e "${GREEN}[SUCCESS]${NC} $1"

    log "[SUCCESS] $1"

}

warning() {

    echo -e "${YELLOW}[WARNING]${NC} $1"

    log "[WARNING] $1"

}

error() {

    echo -e "${RED}[ERROR]${NC} $1"

    log "[ERROR] $1"

}

# ==========================================
# Command Existence Check
# ==========================================

command_exists() {

    command -v "$1" >/dev/null 2>&1

}

# ==========================================
# Root / Privilege Check
# ==========================================

check_root() {

    if [[ "$EUID" -ne 0 ]]; then

        error "This installer must be run with root privileges."
        error "Please run the installer using sudo."

        exit 1

    fi

    success "Root privileges confirmed."

}

# ==========================================
# Operating System Detection
# ==========================================

detect_os() {

    if [[ ! -f /etc/os-release ]]; then

        error "Unable to detect operating system."

        exit 1

    fi

    source /etc/os-release

    OS_NAME="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_PRETTY_NAME="${PRETTY_NAME:-Unknown Linux}"

    info "Operating System: $OS_PRETTY_NAME"

}

# ==========================================
# Architecture Detection
# ==========================================

detect_architecture() {

    ARCHITECTURE="$(uname -m)"

    info "System Architecture: $ARCHITECTURE"

}

# ==========================================
# Internet Connectivity Check
# ==========================================

check_internet() {

    info "Checking Internet connectivity..."

    if command_exists curl; then

        if curl -fsS \
            --connect-timeout 5 \
            --max-time 10 \
            https://github.com >/dev/null 2>&1; then

            success "Internet connection is available."

        else

            warning "Internet connectivity check failed."

        fi

    else

        warning "curl is not installed. Skipping Internet connectivity check."

    fi

}

# ==========================================
# Create Required Directories
# ==========================================

create_directories() {

    mkdir -p "$LOG_DIR"

    touch "$LOG_FILE"

    success "Required directories verified."

}

# ==========================================
# System Information
# ==========================================

show_system_info() {

    echo

    echo "=========================================="
    echo "         SYSTEM INFORMATION"
    echo "=========================================="

    echo "OS           : ${OS_PRETTY_NAME:-Unknown}"
    echo "Architecture : ${ARCHITECTURE:-Unknown}"
    echo "Hostname     : $(hostname)"
    echo "Kernel       : $(uname -r)"

    echo "=========================================="

    echo

}

# ==========================================
# Check Service Status
# ==========================================

get_service_status() {

    local SERVICE="$1"

    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

        echo "RUNNING"

    elif systemctl list-unit-files 2>/dev/null | \
        grep -q "^${SERVICE}.service"; then

        echo "STOPPED"

    else

        echo "NOT INSTALLED"

    fi

}

# ==========================================
# Check Port Status
# ==========================================

get_port_status() {

    local PORT="$1"

    if command_exists ss; then

        if ss -tuln 2>/dev/null | \
            grep -qE ":${PORT}[[:space:]]"; then

            echo "LISTENING"

        else

            echo "NOT LISTENING"

        fi

    else

        echo "UNKNOWN"

    fi

}

# ==========================================
# Check Firewall
# ==========================================

check_firewall_status() {

    if command_exists ufw; then

        if ufw status 2>/dev/null | \
            grep -q "Status: active"; then

            echo "ACTIVE"

        else

            echo "INACTIVE"

        fi

    else

        echo "NOT INSTALLED"

    fi

}

# ==========================================
# Common Initialization
# ==========================================

initialize() {

    create_directories

    check_root

    detect_os

    detect_architecture

    check_internet

    log "[INFO] Installer initialization completed."

}

# ==========================================
# Standalone Test
# ==========================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    echo

    echo "=========================================="
    echo "     DEVOPS COMMON FUNCTIONS TEST"
    echo "=========================================="

    echo

    initialize

    show_system_info

fi