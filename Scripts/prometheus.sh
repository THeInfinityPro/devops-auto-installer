#!/bin/bash

# ==========================================
# DevOps Auto Installer - Prometheus
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Variables
# ==========================================

PROMETHEUS_USER="prometheus"
PROMETHEUS_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"
PROMETHEUS_INSTALL_DIR="/opt/prometheus"

# ==========================================
# Check OS
# ==========================================

check_supported_os() {

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "Prometheus installer currently supports Ubuntu only."
        exit 1
    fi

    case "$OS_VERSION" in
        22.04|24.04|26.04)
            success "Supported Ubuntu version: $OS_VERSION"
            ;;
        *)
            error "Unsupported Ubuntu version: $OS_VERSION"
            exit 1
            ;;
    esac
}

# ==========================================
# Install Dependencies
# ==========================================

install_dependencies() {

    info "Installing Prometheus dependencies..."

    apt-get update

    apt-get install -y \
        curl \
        wget \
        tar

    success "Prometheus dependencies installed."
}

# ==========================================
# Detect Architecture
# ==========================================

get_prometheus_architecture() {

    case "$(uname -m)" in

        x86_64)
            PROM_ARCH="amd64"
            ;;

        aarch64|arm64)
            PROM_ARCH="arm64"
            ;;

        *)
            error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;

    esac

    info "Prometheus architecture: $PROM_ARCH"
}

# ==========================================
# Get Latest Release
# ==========================================

get_latest_version() {

    info "Checking latest Prometheus release..."

    PROM_VERSION="$(curl -fsSL \
        https://api.github.com/repos/prometheus/prometheus/releases/latest |
        grep '"tag_name":' |
        head -1 |
        cut -d '"' -f 4)"

    if [[ -z "$PROM_VERSION" ]]; then
        error "Unable to determine latest Prometheus version."
        exit 1
    fi

    success "Latest Prometheus release: $PROM_VERSION"
}

# ==========================================
# Create Prometheus User
# ==========================================

create_prometheus_user() {

    if id "$PROMETHEUS_USER" >/dev/null 2>&1; then

        info "Prometheus user already exists."

    else

        info "Creating Prometheus user..."

        useradd \
            --system \
            --no-create-home \
            --shell /usr/sbin/nologin \
            "$PROMETHEUS_USER"

        success "Prometheus user created."

    fi
}

# ==========================================
# Download Prometheus
# ==========================================

download_prometheus() {

    info "Downloading Prometheus $PROM_VERSION..."

    mkdir -p "$PROMETHEUS_INSTALL_DIR"

    cd /tmp

    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/${PROM_VERSION}/prometheus-${PROM_VERSION#v}.linux-${PROM_ARCH}.tar.gz"

    ARCHIVE="/tmp/prometheus.tar.gz"

    # Remove previous archive
    rm -f "$ARCHIVE"

    # Download
    curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"

    success "Prometheus archive downloaded."

    # Extract
    info "Extracting Prometheus archive..."

    rm -rf /tmp/prometheus-extracted

    mkdir -p /tmp/prometheus-extracted

    tar -xzf "$ARCHIVE" -C /tmp/prometheus-extracted

    # Find extracted directory
    EXTRACTED_DIR="$(find /tmp/prometheus-extracted \
        -maxdepth 1 \
        -type d \
        -name 'prometheus-*' \
        | head -n 1)"

    if [[ -z "$EXTRACTED_DIR" ]]; then
        error "Unable to locate extracted Prometheus directory."
        exit 1
    fi

    info "Extracted directory: $EXTRACTED_DIR"

    # Check Prometheus binary
    if [[ ! -f "$EXTRACTED_DIR/prometheus" ]]; then
        error "Prometheus binary was not found."
        exit 1
    fi

    # Check Promtool binary
    if [[ ! -f "$EXTRACTED_DIR/promtool" ]]; then
        error "Promtool binary was not found."
        exit 1
    fi

    # Install binaries
    info "Installing Prometheus binaries..."

    install -m 0755 \
        "$EXTRACTED_DIR/prometheus" \
        "$PROMETHEUS_INSTALL_DIR/prometheus"

    install -m 0755 \
        "$EXTRACTED_DIR/promtool" \
        "$PROMETHEUS_INSTALL_DIR/promtool"

    # Create directories
    mkdir -p "$PROMETHEUS_DIR"
    mkdir -p "$PROMETHEUS_DATA_DIR"

    # Copy configuration
    if [[ -f "$EXTRACTED_DIR/prometheus.yml" ]]; then

        cp "$EXTRACTED_DIR/prometheus.yml" \
            "$PROMETHEUS_DIR/prometheus.yml"

    else

        error "prometheus.yml was not found."
        exit 1

    fi

    # Set ownership
    chown -R "$PROMETHEUS_USER:$PROMETHEUS_USER" \
        "$PROMETHEUS_DIR" \
        "$PROMETHEUS_DATA_DIR" \
        "$PROMETHEUS_INSTALL_DIR"

    success "Prometheus files installed successfully."
}

# ==========================================
# Main
# ==========================================

main() {

    info "Starting Prometheus installation..."

    initialize

    check_supported_os

    install_dependencies

    get_prometheus_architecture

    get_latest_version

    create_prometheus_user

    download_prometheus

    create_prometheus_service

    verify_prometheus

    log "Prometheus installation completed."

    echo
    success "=========================================="
    success "Prometheus installation completed."
    success "=========================================="
}

main