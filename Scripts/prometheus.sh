#!/bin/bash

# ==========================================
# DevOps Auto Installer - Prometheus
# ==========================================

set -e

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Variables
# ==========================================

PROMETHEUS_USER="prometheus"
PROMETHEUS_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"
PROMETHEUS_INSTALL_DIR="/opt/prometheus"
PROMETHEUS_TEMP_DIR="/opt/prometheus-installer"

PROMETHEUS_BINARY="$PROMETHEUS_INSTALL_DIR/prometheus"
PROMTOOL_BINARY="$PROMETHEUS_INSTALL_DIR/promtool"
PROMETHEUS_CONFIG="$PROMETHEUS_DIR/prometheus.yml"

# ==========================================
# Check OS
# ==========================================

check_supported_os() {

    info "Checking operating system compatibility..."

    if [[ "$OS_NAME" != "ubuntu" ]]; then

        error "Prometheus installer currently supports Ubuntu only."
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
# Check Existing Prometheus
# ==========================================

check_existing_prometheus() {

    info "Checking for existing Prometheus installation..."

    if systemctl list-unit-files 2>/dev/null | \
        grep -q "^prometheus.service"; then

        warning "Prometheus service is already installed."

        if [[ -x "$PROMETHEUS_BINARY" ]]; then

            success "Prometheus binary found: $PROMETHEUS_BINARY"

        else

            warning "Prometheus service exists but binary was not found."
        fi

        if systemctl is-active --quiet prometheus; then

            success "Prometheus service is already running."

        else

            warning "Prometheus is installed but not running."

            info "Attempting to start Prometheus..."

            systemctl daemon-reload
            systemctl enable prometheus
            systemctl start prometheus || true

        fi

        return 0

    fi

    if [[ -x "$PROMETHEUS_BINARY" ]]; then

        warning "Prometheus binary exists but systemd service was not found."

        return 1

    fi

    info "Prometheus is not currently installed."

    return 1
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
        tar \
        ca-certificates

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

    success "Prometheus architecture detected: $PROM_ARCH"
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

        success "Prometheus user already exists."

    else

        info "Creating Prometheus system user..."

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

    rm -rf "$PROMETHEUS_TEMP_DIR"

    mkdir -p "$PROMETHEUS_TEMP_DIR"

    ARCHIVE="$PROMETHEUS_TEMP_DIR/prometheus.tar.gz"
    EXTRACT_DIR="$PROMETHEUS_TEMP_DIR/extracted"

    mkdir -p "$EXTRACT_DIR"
    mkdir -p "$PROMETHEUS_INSTALL_DIR"

    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/${PROM_VERSION}/prometheus-${PROM_VERSION#v}.linux-${PROM_ARCH}.tar.gz"

    info "Download URL:"
    info "$DOWNLOAD_URL"

    curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"

    success "Prometheus archive downloaded."

    # ------------------------------------------
    # Extract
    # ------------------------------------------

    info "Extracting Prometheus archive..."

    tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"

    EXTRACTED_DIR="$(find "$EXTRACT_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'prometheus-*' \
        | head -n 1)"

    if [[ -z "$EXTRACTED_DIR" ]]; then

        error "Unable to locate extracted Prometheus directory."

        exit 1

    fi

    # ------------------------------------------
    # Validate Files
    # ------------------------------------------

    if [[ ! -f "$EXTRACTED_DIR/prometheus" ]]; then

        error "Prometheus binary was not found."

        exit 1

    fi

    if [[ ! -f "$EXTRACTED_DIR/promtool" ]]; then

        error "Promtool binary was not found."

        exit 1

    fi

    if [[ ! -f "$EXTRACTED_DIR/prometheus.yml" ]]; then

        error "Default prometheus.yml was not found."

        exit 1

    fi

    success "Prometheus installation files validated."

    # ------------------------------------------
    # Backup Existing Installation
    # ------------------------------------------

    if [[ -f "$PROMETHEUS_BINARY" ]]; then

        BACKUP_DIR="${PROMETHEUS_INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"

        warning "Existing Prometheus installation detected."

        info "Creating backup: $BACKUP_DIR"

        cp -a \
            "$PROMETHEUS_INSTALL_DIR" \
            "$BACKUP_DIR"

    fi

    # ------------------------------------------
    # Install Binaries
    # ------------------------------------------

    info "Installing Prometheus binaries..."

    install -m 0755 \
        "$EXTRACTED_DIR/prometheus" \
        "$PROMETHEUS_BINARY"

    install -m 0755 \
        "$EXTRACTED_DIR/promtool" \
        "$PROMTOOL_BINARY"

    # ------------------------------------------
    # Create Directories
    # ------------------------------------------

    mkdir -p "$PROMETHEUS_DIR"
    mkdir -p "$PROMETHEUS_DATA_DIR"

    # ------------------------------------------
    # Configuration
    # ------------------------------------------

    if [[ ! -f "$PROMETHEUS_CONFIG" ]]; then

        info "Installing default Prometheus configuration..."

        cp \
            "$EXTRACTED_DIR/prometheus.yml" \
            "$PROMETHEUS_CONFIG"

    else

        warning "Existing Prometheus configuration detected."
        info "Keeping existing configuration: $PROMETHEUS_CONFIG"

    fi

    # ------------------------------------------
    # Ownership
    # ------------------------------------------

    chown -R \
        "$PROMETHEUS_USER:$PROMETHEUS_USER" \
        "$PROMETHEUS_DIR" \
        "$PROMETHEUS_DATA_DIR" \
        "$PROMETHEUS_INSTALL_DIR"

    # ------------------------------------------
    # Cleanup
    # ------------------------------------------

    rm -rf "$PROMETHEUS_TEMP_DIR"

    success "Prometheus files installed successfully."
}

# ==========================================
# Validate Prometheus Configuration
# ==========================================

validate_prometheus_config() {

    info "Validating Prometheus configuration..."

    if [[ ! -f "$PROMETHEUS_CONFIG" ]]; then

        error "Prometheus configuration not found:"
        error "$PROMETHEUS_CONFIG"

        exit 1

    fi

    if "$PROMTOOL_BINARY" check config \
        "$PROMETHEUS_CONFIG"; then

        success "Prometheus configuration is valid."

    else

        error "Prometheus configuration validation failed."

        exit 1

    fi
}

# ==========================================
# Create Systemd Service
# ==========================================

create_prometheus_service() {

    info "Creating Prometheus systemd service..."

    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
Type=simple

ExecStart=$PROMETHEUS_BINARY \
    --config.file=$PROMETHEUS_CONFIG \
    --storage.tsdb.path=$PROMETHEUS_DATA_DIR \
    --web.listen-address=0.0.0.0:$PROMETHEUS_PORT

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable prometheus

    systemctl restart prometheus

    if systemctl is-active --quiet prometheus; then

        success "Prometheus service created and started."

    else

        error "Prometheus service failed to start."

        systemctl status prometheus --no-pager || true

        exit 1

    fi
}

# ==========================================
# Wait for Prometheus
# ==========================================

wait_for_prometheus() {

    info "Waiting for Prometheus HTTP endpoint..."

    local max_attempts=60

    for ((i=1; i<=max_attempts; i++))
    do

        if curl -fsS \
            --max-time 2 \
            "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
            >/dev/null 2>&1
        then

            success "Prometheus HTTP endpoint is responding."

            return 0

        fi

        echo -ne "\r[INFO] Waiting for Prometheus... ${i}/${max_attempts} seconds"

        sleep 1

    done

    echo

    error "Prometheus HTTP endpoint did not become ready."

    info "Recent Prometheus logs:"

    journalctl \
        -u prometheus \
        -n 30 \
        --no-pager || true

    exit 1
}

# ==========================================
# Check Prometheus Port
# ==========================================

check_prometheus_port() {

    info "Checking Prometheus port ${PROMETHEUS_PORT}..."

    if ss -tuln | grep -qE ":${PROMETHEUS_PORT}[[:space:]]"; then

        success "Port ${PROMETHEUS_PORT} is listening locally."

    else

        warning "Port ${PROMETHEUS_PORT} is not detected as listening."

    fi

    # ------------------------------------------
    # UFW Check
    # ------------------------------------------

    if command_exists ufw; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then

            info "UFW firewall is active."

            if ufw status | grep -q "${PROMETHEUS_PORT}"; then

                success "UFW rule found for port ${PROMETHEUS_PORT}."

            else

                warning "No explicit UFW rule found for port ${PROMETHEUS_PORT}."

            fi

        else

            success "UFW firewall is inactive."

        fi

    fi
}

# ==========================================
# Verify Prometheus
# ==========================================

verify_prometheus() {

    info "Verifying Prometheus installation..."

    # Binary
    if [[ -x "$PROMETHEUS_BINARY" ]]; then

        success "Prometheus binary is available."

    else

        error "Prometheus binary is not available."

        exit 1

    fi

    # Promtool
    if [[ -x "$PROMTOOL_BINARY" ]]; then

        success "Promtool is available."

    else

        error "Promtool is not available."

        exit 1

    fi

    echo

    "$PROMETHEUS_BINARY" --version | head -n 3

    echo

    # Service
    if systemctl is-active --quiet prometheus; then

        success "Prometheus service is running."

    else

        error "Prometheus service is not running."

        systemctl status prometheus --no-pager || true

        exit 1

    fi

    # HTTP API
    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/healthy" \
        >/dev/null 2>&1
    then

        success "Prometheus health endpoint is responding."

    else

        error "Prometheus health endpoint is not responding."

        exit 1

    fi

    success "Prometheus verification completed."
}

# ==========================================
# Display Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "      PROMETHEUS INSTALLATION SUMMARY"
    echo "=========================================="

    echo "Service Status : $(get_service_status prometheus)"
    echo "Port           : $PROMETHEUS_PORT"
    echo "Config File    : $PROMETHEUS_CONFIG"
    echo "Data Directory : $PROMETHEUS_DATA_DIR"
    echo "Binary         : $PROMETHEUS_BINARY"

    echo
    echo "Local URL:"
    echo "http://localhost:${PROMETHEUS_PORT}"

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
    echo "        PROMETHEUS INSTALLER"
    echo "=========================================="

    echo

    info "Starting Prometheus installation..."

    check_supported_os

    # Existing installation check
    if check_existing_prometheus; then

        info "Verifying existing Prometheus installation..."

        validate_prometheus_config
        verify_prometheus
        check_prometheus_port
        show_summary

        log "[SUCCESS] Existing Prometheus installation verified."

        return 0

    fi

    # Install dependencies
    install_dependencies

    # Architecture
    get_prometheus_architecture

    # Latest version
    get_latest_version

    # Create user
    create_prometheus_user

    # Download and install
    download_prometheus

    # Validate configuration
    validate_prometheus_config

    # Create service
    create_prometheus_service

    # Wait for service
    wait_for_prometheus

    # Verify
    verify_prometheus

    # Port check
    check_prometheus_port

    # Summary
    show_summary

    log "[SUCCESS] Prometheus installation completed successfully."

    echo

    success "=========================================="
    success "PROMETHEUS INSTALLATION COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Start
# ==========================================

main