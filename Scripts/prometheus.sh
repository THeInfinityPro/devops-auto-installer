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
        22.04|24.04)
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

    curl -fL "$DOWNLOAD_URL" \
        -o prometheus.tar.gz

    tar -xzf prometheus.tar.gz

    EXTRACTED_DIR="/tmp/prometheus-${PROM_VERSION#v}.linux-${PROM_ARCH}"

    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        error "Prometheus archive extraction failed."
        exit 1
    fi

    cp "$EXTRACTED_DIR/prometheus" "$PROMETHEUS_INSTALL_DIR/"
    cp "$EXTRACTED_DIR/promtool" "$PROMETHEUS_INSTALL_DIR/"

    mkdir -p "$PROMETHEUS_DIR"
    mkdir -p "$PROMETHEUS_DATA_DIR"

    cp -r "$EXTRACTED_DIR/consoles" "$PROMETHEUS_DIR/"
    cp -r "$EXTRACTED_DIR/console_libraries" "$PROMETHEUS_DIR/"
    cp "$EXTRACTED_DIR/prometheus.yml" "$PROMETHEUS_DIR/"

    chown -R "$PROMETHEUS_USER:$PROMETHEUS_USER" \
        "$PROMETHEUS_DIR" \
        "$PROMETHEUS_DATA_DIR" \
        "$PROMETHEUS_INSTALL_DIR"

    success "Prometheus downloaded and installed."
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
  --storage.tsdb.path=$PROMETHEUS_DATA_DIR \
  --web.console.templates=$PROMETHEUS_DIR/consoles \
  --web.console.libraries=$PROMETHEUS_DIR/console_libraries

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable prometheus
    systemctl start prometheus

    success "Prometheus service created and started."
}

# ==========================================
# Verify Prometheus
# ==========================================

verify_prometheus() {

    info "Verifying Prometheus..."

    if ! systemctl is-active --quiet prometheus; then
        error "Prometheus service is not running."
        systemctl status prometheus --no-pager
        exit 1
    fi

    if curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1; then
        success "Prometheus web service is responding on port 9090."
    else
        warning "Prometheus is running but the HTTP endpoint is not ready yet."
    fi

    "$PROMETHEUS_INSTALL_DIR/prometheus" \
        --version 2>/dev/null || true

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

main