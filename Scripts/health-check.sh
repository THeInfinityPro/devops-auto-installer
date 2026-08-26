#!/bin/bash

# ==========================================
# DevOps Auto Installer - Health Check
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Disk Check
# ==========================================

check_disk() {

    info "Checking disk space..."

    AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    USED_PERCENT=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

    echo "Available disk space: ${AVAILABLE_DISK}GB"
    echo "Disk usage: ${USED_PERCENT}%"

    if [[ "$AVAILABLE_DISK" -ge 20 ]]; then
        success "Disk space is sufficient."
    else
        warning "Low disk space. Recommended: at least 20GB available."
    fi
}

# ==========================================
# Memory Check
# ==========================================

check_memory() {

    info "Checking system memory..."

    TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
    AVAILABLE_RAM=$(free -m | awk '/Mem:/ {print $7}')

    echo "Total RAM: ${TOTAL_RAM}MB"
    echo "Available RAM: ${AVAILABLE_RAM}MB"

    if [[ "$TOTAL_RAM" -ge 4096 ]]; then
        success "Memory is sufficient."
    else
        warning "Low RAM. Recommended: at least 4GB."
    fi
}

# ==========================================
# CPU Check
# ==========================================

check_cpu() {

    info "Checking CPU..."

    CPU_CORES=$(nproc)

    echo "CPU cores: $CPU_CORES"

    if [[ "$CPU_CORES" -ge 2 ]]; then
        success "CPU resources are sufficient."
    else
        warning "Only one CPU core detected."
    fi
}

# ==========================================
# Internet Check
# ==========================================

check_internet() {

    info "Checking Internet connectivity..."

    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connection is available."
    else
        warning "Internet connection could not be verified."
    fi
}

# ==========================================
# Port Status Check
# ==========================================

check_ports() {

    info "Checking DevOps required ports..."

    declare -A PORT_NAMES=(
        [6443]="Kubernetes API"
        [8080]="Jenkins"
        [9090]="Prometheus"
        [3000]="Grafana"
    )

    echo

    for PORT in 6443 8080 9090 3000; do

        SERVICE="${PORT_NAMES[$PORT]}"

        echo "------------------------------------------"
        info "Port $PORT - $SERVICE"
        echo "------------------------------------------"

        # --------------------------------------
        # Check local listening status
        # --------------------------------------

        if ss -tuln 2>/dev/null | grep -qE "[:.]${PORT}[[:space:]]"; then

            success "Port $PORT is listening locally."

            echo
            info "Listening process:"

            ss -tulpn 2>/dev/null | grep -E "[:.]${PORT}[[:space:]]" || true

        else

            warning "Port $PORT is not listening locally."

        fi

        echo

    done
}

# ==========================================
# Local HTTP Service Check
# ==========================================

check_http_services() {

    info "Checking DevOps web services..."

    echo

    # Jenkins
    if curl -fsS --max-time 5 \
        http://127.0.0.1:8080/login \
        >/dev/null 2>&1; then

        success "Jenkins HTTP service is responding."

    else

        warning "Jenkins HTTP service is not responding."

    fi

    # Prometheus
    if curl -fsS --max-time 5 \
        http://127.0.0.1:9090/-/ready \
        >/dev/null 2>&1; then

        success "Prometheus HTTP service is responding."

    else

        warning "Prometheus HTTP service is not responding."

    fi

    # Grafana
    if curl -fsS --max-time 5 \
        http://127.0.0.1:3000/api/health \
        >/dev/null 2>&1; then

        success "Grafana HTTP service is responding."

    else

        warning "Grafana HTTP service is not responding."

    fi
}

# ==========================================
# Firewall Check
# ==========================================

check_firewall() {

    info "Checking firewall status..."

    echo

    # ------------------------------------------
    # UFW
    # ------------------------------------------

    if command_exists ufw; then

        UFW_STATUS=$(ufw status 2>/dev/null | head -n 1)

        echo "UFW Status: $UFW_STATUS"

        if ufw status 2>/dev/null | grep -q "Status: active"; then

            info "UFW firewall is active."
            echo

            info "Configured UFW rules:"

            ufw status numbered

        else

            success "UFW firewall is inactive."

        fi

    else

        warning "UFW is not installed."

    fi

    echo

    # ------------------------------------------
    # iptables
    # ------------------------------------------

    if command_exists iptables; then

        info "Checking iptables firewall..."

        if iptables -L -n 2>/dev/null; then
            success "iptables rules detected."
        else
            warning "Unable to read iptables rules."
        fi

    fi
}

# ==========================================
# Cloud Firewall Information
# ==========================================

check_cloud_firewall_notice() {

    echo

    info "Checking external firewall limitations..."

    warning "This script can verify local ports and local firewall rules."

    warning "Cloud firewall rules cannot always be verified from inside the server."

    echo

    echo "If using AWS EC2, check Security Group inbound rules."

    echo "Recommended ports:"

    echo "  22   - SSH"
    echo "  3000 - Grafana"
    echo "  6443 - Kubernetes API"
    echo "  8080 - Jenkins"
    echo "  9090 - Prometheus"

    echo
}

# ==========================================
# Existing Components Check
# ==========================================

# ==========================================
# Existing Components Check
# ==========================================

check_existing_components() {

    info "Checking existing DevOps components..."

    # Docker
    if command_exists docker; then
        success "Docker is installed."
    else
        info "Docker is not installed."
    fi

    # Kubernetes kubeadm
    if command_exists kubeadm; then
        success "Kubernetes kubeadm is installed."
    else
        info "Kubernetes kubeadm is not installed."
    fi

    # Kubernetes kubectl
    if command_exists kubectl; then
        success "Kubernetes kubectl is installed."
    else
        info "Kubernetes kubectl is not installed."
    fi

    # Kubernetes kubelet
    if command_exists kubelet; then
        success "Kubernetes kubelet is installed."
    else
        info "Kubernetes kubelet is not installed."
    fi

    # Jenkins
    if command_exists jenkins || \
       systemctl list-unit-files 2>/dev/null | grep -q "^jenkins.service"; then

        success "Jenkins is installed."

    else
        info "Jenkins is not installed."
    fi

    # Prometheus
    if systemctl list-unit-files 2>/dev/null | \
        grep -q "^prometheus.service"; then

        success "Prometheus is installed."

    elif [[ -x "/opt/prometheus/prometheus" ]]; then

        success "Prometheus is installed."

    else

        info "Prometheus is not installed."

    fi

    # Grafana
    if command_exists grafana-server || \
       systemctl list-unit-files 2>/dev/null | grep -q "^grafana-server.service"; then

        success "Grafana is installed."

    else
        info "Grafana is not installed."
    fi
}


# ==========================================
# Service Status Check
# ==========================================

check_services() {

    info "Checking DevOps service status..."

    declare -A SERVICES=(
        [docker]="Docker"
        [containerd]="Containerd"
        [kubelet]="Kubelet"
        [jenkins]="Jenkins"
        [prometheus]="Prometheus"
        [grafana-server]="Grafana"
    )

    for SERVICE in \
        docker \
        containerd \
        kubelet \
        jenkins \
        prometheus \
        grafana-server
    do

        NAME="${SERVICES[$SERVICE]}"

        if systemctl list-unit-files 2>/dev/null | \
            grep -q "^${SERVICE}.service"; then

            if systemctl is-active --quiet "$SERVICE"; then

                success "$NAME service is running."

            else

                warning "$NAME service is installed but not running."

            fi

        else

            info "$NAME service is not installed."

        fi

    done
}

# ==========================================
# Main
# ==========================================

main() {

    echo
    echo "=========================================="
    echo "        SYSTEM HEALTH CHECK"
    echo "=========================================="
    echo

    initialize

    show_system_info

    check_cpu

    echo

    check_memory

    echo

    check_disk

    echo

    check_internet

    echo

    check_services

    echo

    check_ports

    check_http_services

    echo

    check_firewall

    check_cloud_firewall_notice

    check_existing_components

    echo
    success "=========================================="
    success "SYSTEM HEALTH CHECK COMPLETED"
    success "=========================================="
}

main