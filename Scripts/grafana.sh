#!/bin/bash

# ==========================================
# DevOps Auto Installer - Grafana Installer
# ==========================================

set -e

# ==========================================
# Load Common Functions
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check Supported Operating System
# ==========================================

check_supported_os() {

    info "Checking operating system compatibility..."

    if [[ "$OS_NAME" != "ubuntu" ]]; then

        error "Grafana installer currently supports Ubuntu only."
        error "Detected OS: ${OS_NAME:-Unknown}"

        exit 1

    fi

    case "$OS_VERSION" in

        22.04|24.04|26.04)

            success "Supported Ubuntu version detected: $OS_VERSION"
            ;;

        *)

            error "Unsupported Ubuntu version: $OS_VERSION"
            error "Supported versions: Ubuntu 22.04, 24.04, and 26.04"

            exit 1
            ;;

    esac
}

# ==========================================
# Check Existing Grafana Installation
# ==========================================

check_existing_grafana() {

    info "Checking for existing Grafana installation..."

    if systemctl list-unit-files 2>/dev/null | \
        grep -q "^grafana-server.service"; then

        warning "Grafana is already installed."

        if command_exists grafana-server; then

            success "Grafana binary found."

            info "Version: $(grafana-server -v 2>/dev/null || echo "Unknown")"

        fi

        if systemctl is-active --quiet grafana-server; then

            success "Grafana service is already running."

        else

            warning "Grafana is installed but the service is not running."

            info "Attempting to start Grafana..."

            systemctl daemon-reload
            systemctl enable grafana-server
            systemctl start grafana-server || true

        fi

        return 0

    fi

    if command_exists grafana-server; then

        warning "Grafana binary exists but systemd service was not detected."

        return 1

    fi

    info "Grafana is not currently installed."

    return 1
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
        curl \
        gpg \
        ca-certificates

    success "Grafana dependencies installed."
}

# ==========================================
# Configure Grafana Repository
# ==========================================

configure_grafana_repository() {

    info "Configuring Grafana official repository..."

    mkdir -p -m 0755 /etc/apt/keyrings

    # ------------------------------------------
    # Download GPG Key
    # ------------------------------------------

    if [[ ! -f /etc/apt/keyrings/grafana.asc ]]; then

        info "Downloading Grafana repository key..."

        wget -q \
            -O /etc/apt/keyrings/grafana.asc \
            https://apt.grafana.com/gpg-full.key

        chmod 644 /etc/apt/keyrings/grafana.asc

        success "Grafana repository key installed."

    else

        success "Grafana repository key already exists."

    fi

    # ------------------------------------------
    # Configure Repository
    # ------------------------------------------

    echo \
        "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" \
        > /etc/apt/sources.list.d/grafana.list

    apt-get update

    success "Grafana official repository configured."
}

# ==========================================
# Install Grafana
# ==========================================

install_grafana() {

    info "Installing latest stable Grafana OSS..."

    apt-get install -y grafana

    success "Grafana installed successfully."
}

# ==========================================
# Start Grafana
# ==========================================

start_grafana() {

    info "Enabling Grafana service..."

    systemctl daemon-reload
    systemctl enable grafana-server

    info "Starting Grafana service..."

    systemctl restart grafana-server

    local max_attempts=12

    for ((i=1; i<=max_attempts; i++))
    do

        if systemctl is-active --quiet grafana-server; then

            success "Grafana service is running."

            return 0

        fi

        info "Waiting for Grafana service... ($i/$max_attempts)"

        sleep 5

    done

    error "Grafana service failed to start."

    systemctl status grafana-server --no-pager || true

    exit 1
}

# ==========================================
# Wait for Grafana HTTP API
# ==========================================

wait_for_grafana() {

    info "Waiting for Grafana HTTP API..."

    local max_attempts=60

    for ((i=1; i<=max_attempts; i++))
    do

        if curl -fsS \
            --max-time 3 \
            "http://127.0.0.1:${GRAFANA_PORT}/api/health" \
            >/dev/null 2>&1
        then

            success "Grafana HTTP API is responding."

            return 0

        fi

        echo -ne "\r[INFO] Waiting for Grafana... ${i}/${max_attempts} seconds"

        sleep 1

    done

    echo

    warning "Grafana service is running but HTTP API did not respond in time."

    info "Recent Grafana logs:"

    journalctl \
        -u grafana-server \
        -n 30 \
        --no-pager || true
}

# ==========================================
# Check Grafana Port
# ==========================================

check_grafana_port() {

    info "Checking Grafana port ${GRAFANA_PORT}..."

    if ss -tuln | grep -qE ":${GRAFANA_PORT}[[:space:]]"; then

        success "Port ${GRAFANA_PORT} is listening locally."

    else

        warning "Port ${GRAFANA_PORT} is not detected as listening."

    fi

    # ------------------------------------------
    # UFW Firewall Check
    # ------------------------------------------

    if command_exists ufw; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then

            info "UFW firewall is active."

            if ufw status | grep -q "${GRAFANA_PORT}"; then

                success "UFW rule found for port ${GRAFANA_PORT}."

            else

                warning "No explicit UFW rule found for port ${GRAFANA_PORT}."

            fi

        else

            success "UFW firewall is inactive."

        fi

    else

        info "UFW firewall is not installed."

    fi
}

# ==========================================
# Verify Grafana
# ==========================================

verify_grafana() {

    echo

    info "Verifying Grafana installation..."

    # ------------------------------------------
    # Binary Check
    # ------------------------------------------

    if command_exists grafana-server; then

        success "Grafana server binary found."

        echo

        grafana-server -v

    else

        error "Grafana server binary was not found."

        exit 1

    fi

    echo

    # ------------------------------------------
    # Service Check
    # ------------------------------------------

    if systemctl is-active --quiet grafana-server; then

        success "Grafana service is running."

    else

        error "Grafana service is not running."

        systemctl status grafana-server --no-pager || true

        exit 1

    fi

    # ------------------------------------------
    # HTTP Health Check
    # ------------------------------------------

    info "Checking Grafana health endpoint..."

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${GRAFANA_PORT}/api/health" \
        >/dev/null 2>&1
    then

        success "Grafana health endpoint is responding."

    else

        warning "Grafana health endpoint did not respond."

    fi
}

# ==========================================
# Display Grafana Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "        GRAFANA INSTALLATION SUMMARY"
    echo "=========================================="

    echo "Service Status : $(get_service_status grafana-server)"
    echo "Grafana Port   : ${GRAFANA_PORT}"

    if command_exists grafana-server; then

        echo "Version        : $(grafana-server -v 2>/dev/null || echo "Unknown")"

    fi

    echo

    echo "Local URL:"
    echo "http://localhost:${GRAFANA_PORT}"

    echo

    echo "Default Login:"
    echo "Username : admin"
    echo "Password : admin"

    echo "=========================================="

    echo
}

# ==========================================
# Main
# ==========================================

main() {

    initialize

    echo

    echo "=========================================="
    echo "           GRAFANA INSTALLER"
    echo "=========================================="

    echo

    info "Starting Grafana installation..."

    check_supported_os

    # ------------------------------------------
    # Existing Installation
    # ------------------------------------------

    if check_existing_grafana; then

        info "Verifying existing Grafana installation..."

        wait_for_grafana
        verify_grafana
        check_grafana_port
        show_summary

        log "[SUCCESS] Existing Grafana installation verified."

        success "Grafana is ready to use."

        return 0

    fi

    # ------------------------------------------
    # Install Dependencies
    # ------------------------------------------

    install_dependencies

    # ------------------------------------------
    # Configure Repository
    # ------------------------------------------

    configure_grafana_repository

    # ------------------------------------------
    # Install Grafana
    # ------------------------------------------

    install_grafana

    # ------------------------------------------
    # Start Service
    # ------------------------------------------

    start_grafana

    # ------------------------------------------
    # Wait for HTTP API
    # ------------------------------------------

    wait_for_grafana

    # ------------------------------------------
    # Verify Installation
    # ------------------------------------------

    verify_grafana

    # ------------------------------------------
    # Check Port
    # ------------------------------------------

    check_grafana_port

    # ------------------------------------------
    # Display Summary
    # ------------------------------------------

    show_summary

    log "[SUCCESS] Grafana installation completed successfully."

    echo

    success "=========================================="
    success "GRAFANA INSTALLATION COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Start Installer
# ==========================================

main