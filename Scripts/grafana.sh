#!/bin/bash

# ==========================================
# DevOps Auto Installer - Grafana
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check OS
# ==========================================

check_supported_os() {

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "Grafana installer currently supports Ubuntu only."
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

    info "Installing Grafana dependencies..."

    apt-get update

    apt-get install -y \
        apt-transport-https \
        wget \
        gpg

    success "Grafana dependencies installed."
}

# ==========================================
# Configure Grafana Repository
# ==========================================

configure_grafana_repository() {

    info "Configuring Grafana official repository..."

    mkdir -p /etc/apt/keyrings

    wget -q \
        -O /etc/apt/keyrings/grafana.asc \
        https://apt.grafana.com/gpg-full.key

    chmod 644 /etc/apt/keyrings/grafana.asc

    echo \
        "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" \
        > /etc/apt/sources.list.d/grafana.list

    apt-get update

    success "Grafana repository configured."
}

# ==========================================
# Install Grafana
# ==========================================

install_grafana() {

    info "Installing latest stable Grafana OSS..."

    apt-get install -y grafana

    success "Grafana installed."
}

# ==========================================
# Start Grafana
# ==========================================

start_grafana() {

    info "Enabling Grafana service..."

    systemctl enable grafana-server

    info "Starting Grafana..."

    systemctl start grafana-server

    if systemctl is-active --quiet grafana-server; then
        success "Grafana service is running."
    else
        error "Grafana service failed to start."
        systemctl status grafana-server --no-pager
        exit 1
    fi
}

# ==========================================
# Verify Grafana
# ==========================================

verify_grafana() {

    info "Verifying Grafana..."

    if ! command_exists grafana-server; then
        error "Grafana server binary was not found."
        exit 1
    fi

    grafana-server -v

    if systemctl is-active --quiet grafana-server; then
        success "Grafana service verification passed."
    else
        error "Grafana service is not running."
        exit 1
    fi

    if curl -fsS http://127.0.0.1:${GRAFANA_PORT}/api/health >/dev/null 2>&1; then
        success "Grafana HTTP API is responding on port : "${GRAFANA_PORT}" ."
    else
        warning "Grafana is running but the HTTP endpoint is not ready yet."
    fi
}

# ==========================================
# Main
# ==========================================

main() {

    info "Starting Grafana installation..."

    initialize

    check_supported_os

    install_dependencies

    configure_grafana_repository

    install_grafana

    start_grafana

    verify_grafana

    log "Grafana installation completed."

    echo
    success "=========================================="
    success "Grafana installation completed."
    success "=========================================="
}

main