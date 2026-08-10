#!/bin/bash

# ==========================================
# DevOps Auto Installer - Common Functions
# ==========================================

# Stop script when a command fails
set -e

# Project directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/installer.log"

# Create log directory
mkdir -p "$LOG_DIR"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
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
# Root / Privilege Check
# ==========================================

check_root() {

    if [[ "$EUID" -ne 0 ]]; then
        error "This installer must be run with root privileges."
        error "Please run it using sudo."
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

    OS_NAME="$ID"
    OS_VERSION="$VERSION_ID"
    OS_PRETTY_NAME="$PRETTY_NAME"

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

    if ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connection is available."
    else
        error "Internet connection is not available."
        exit 1
    fi
}


# ==========================================
# Command Existence Check
# ==========================================

command_exists() {

    command -v "$1" >/dev/null 2>&1
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
    echo "OS           : $OS_PRETTY_NAME"
    echo "Architecture : $ARCHITECTURE"
    echo "Hostname     : $(hostname)"
    echo "Kernel       : $(uname -r)"
    echo "=========================================="
    echo
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

    log "Installer initialization completed."
}