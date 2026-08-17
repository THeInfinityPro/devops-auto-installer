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

    rm -rf "$PROMETHEUS_TEMP_DIR"

    mkdir -p "$PROMETHEUS_TEMP_DIR"

    ARCHIVE="$PROMETHEUS_TEMP_DIR/prometheus.tar.gz"
    EXTRACT_DIR="$PROMETHEUS_TEMP_DIR/extracted"

    mkdir -p "$EXTRACT_DIR"
    mkdir -p "$PROMETHEUS_INSTALL_DIR"

    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/${PROM_VERSION}/prometheus-${PROM_VERSION#v}.linux-${PROM_ARCH}.tar.gz"

    # ==========================================
    # Download
    # ==========================================

    curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"

    success "Prometheus archive downloaded."

    # ==========================================
    # Extract
    # ==========================================

    info "Extracting Prometheus archive..."

    tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"

    # ==========================================
    # Find Extracted Directory
    # ==========================================

    EXTRACTED_DIR="$(find "$EXTRACT_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'prometheus-*' \
        | head -n 1)"

    if [[ -z "$EXTRACTED_DIR" ]]; then

        error "Unable to locate Prometheus extracted directory."

        echo
        info "Extracted files:"
        find "$EXTRACT_DIR" -maxdepth 2 -type f

        exit 1
    fi

    info "Prometheus directory found:"
    info "$EXTRACTED_DIR"

    # ==========================================
    # Validate Prometheus Binary
    # ==========================================

    if [[ ! -f "$EXTRACTED_DIR/prometheus" ]]; then

        error "Prometheus binary was not found."

        echo
        info "Available files:"
        find "$EXTRACTED_DIR" -maxdepth 2 -type f

        exit 1
    fi

    # ==========================================
    # Validate Promtool
    # ==========================================

    if [[ ! -f "$EXTRACTED_DIR/promtool" ]]; then

        error "Promtool binary was not found."

        exit 1
    fi

    success "Prometheus binaries found."

    # ==========================================
    # Install Binaries
    # ==========================================

    info "Installing Prometheus binaries..."

    install -m 0755 \
        "$EXTRACTED_DIR/prometheus" \
        "$PROMETHEUS_INSTALL_DIR/prometheus"

    install -m 0755 \
        "$EXTRACTED_DIR/promtool" \
        "$PROMETHEUS_INSTALL_DIR/promtool"

    # ==========================================
    # Create Directories
    # ==========================================

    mkdir -p "$PROMETHEUS_DIR"
    mkdir -p "$PROMETHEUS_DATA_DIR"

    # ==========================================
    # Install Configuration
    # ==========================================

    if [[ -f "$EXTRACTED_DIR/prometheus.yml" ]]; then

        cp "$EXTRACTED_DIR/prometheus.yml" \
            "$PROMETHEUS_DIR/prometheus.yml"

    else

        error "prometheus.yml was not found."

        exit 1

    fi

    # ==========================================
    # Ownership
    # ==========================================

    chown -R "$PROMETHEUS_USER:$PROMETHEUS_USER" \
        "$PROMETHEUS_DIR" \
        "$PROMETHEUS_DATA_DIR" \
        "$PROMETHEUS_INSTALL_DIR"

    # ==========================================
    # Cleanup
    # ==========================================

    rm -rf "$PROMETHEUS_TEMP_DIR"

    success "Prometheus files installed successfully."
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

ExecStart=$PROMETHEUS_INSTALL_DIR/prometheus \
    --config.file=$PROMETHEUS_DIR/prometheus.yml \
    --storage.tsdb.path=$PROMETHEUS_DATA_DIR

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable prometheus

    systemctl start prometheus

    if systemctl is-active --quiet prometheus; then

        success "Prometheus service created and started."

    else

        error "Prometheus service failed to start."

        systemctl status prometheus --no-pager

        exit 1

    fi
}

# ==========================================
# Verify Prometheus
# ==========================================

verify_prometheus() {

    info "Verifying Prometheus..."

    # ==========================================
    # Check Binary
    # ==========================================

    if [[ ! -x "$PROMETHEUS_INSTALL_DIR/prometheus" ]]; then

        error "Prometheus binary is not available."

        exit 1

    fi

    # ==========================================
    # Check Promtool
    # ==========================================

    if [[ ! -x "$PROMETHEUS_INSTALL_DIR/promtool" ]]; then

        error "Promtool binary is not available."

        exit 1

    fi

    # ==========================================
    # Display Version
    # ==========================================

    "$PROMETHEUS_INSTALL_DIR/prometheus" --version

    echo

    # ==========================================
    # Check Service
    # ==========================================

    if systemctl is-active --quiet prometheus; then

        success "Prometheus service is running."

    else

        error "Prometheus service is not running."

        systemctl status prometheus --no-pager

        exit 1

    fi

    # ==========================================
# Wait for Prometheus HTTP Endpoint
# ==========================================

info "Waiting for Prometheus HTTP endpoint..."

PROMETHEUS_READY=false

for i in {1..60}; do

    if curl -fsS \
        --max-time 2 \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
        >/dev/null 2>&1; then

        PROMETHEUS_READY=true
        break

    fi

    echo -ne "\r[INFO] Waiting for Prometheus... ${i}/60 seconds"

    sleep 1

done

echo

if [[ "$PROMETHEUS_READY" == true ]]; then

    success "Prometheus HTTP endpoint is responding."

else

    error "Prometheus HTTP endpoint did not become ready within 60 seconds."

    info "Recent Prometheus logs:"
    journalctl -u prometheus -n 20 --no-pager

    exit 1

fi

    # ==========================================
    # Check HTTP Endpoint
    # ==========================================

    info "Checking Prometheus HTTP endpoint..."

    if curl -fsS \
        http://127.0.0.1:9090/-/ready \
        >/dev/null 2>&1; then

        success "Prometheus web service is responding on port 9090."

    else

        error "Prometheus HTTP endpoint is not responding."

        exit 1

    fi

    success "Prometheus verification completed."
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

# ==========================================
# Start
# ==========================================

main