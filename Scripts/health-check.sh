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

    echo "Available disk space: ${AVAILABLE_DISK}GB"

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

    echo "Total RAM: ${TOTAL_RAM}MB"

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
# Port Check
# ==========================================

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

    for PORT in "${!PORT_NAMES[@]}"; do

        SERVICE="${PORT_NAMES[$PORT]}"

        echo

        info "Checking port $PORT ($SERVICE)..."

        # Check local listening status
        if ss -tuln | grep -qE ":${PORT}[[:space:]]"; then
            success "Port $PORT is OPEN and listening locally."
        else
            warning "Port $PORT is NOT listening locally."
        fi

    done
}

# ==========================================
# Firewall Check
# ==========================================

check_firewall() {

    info "Checking firewall status..."

    echo

    # UFW
    if command_exists ufw; then

        UFW_STATUS=$(ufw status 2>/dev/null | head -n 1)

        echo "UFW Status: $UFW_STATUS"

        if ufw status | grep -q "Status: active"; then

            info "Checking UFW rules..."

            ufw status numbered

        else

            success "UFW firewall is inactive."

        fi

    else

        warning "UFW is not installed."

    fi

    echo

    # iptables
    if command_exists iptables; then

        info "Checking iptables firewall rules..."

        iptables -L -n --line-numbers

    fi
}


# ==========================================
# Existing Components Check
# ==========================================

check_existing_components() {

    info "Checking existing DevOps components..."

    COMPONENTS=(
        docker
        kubeadm
        kubectl
        kubelet
        jenkins
        prometheus
        grafana-server
    )

    for COMPONENT in "${COMPONENTS[@]}"; do

        if command_exists "$COMPONENT"; then
            warning "$COMPONENT is already installed."
        else
            success "$COMPONENT is not installed."
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
    check_memory
    check_disk
    check_ports
    check_firewall
    check_existing_components

    echo
    success "=========================================="
    success "SYSTEM HEALTH CHECK COMPLETED"
    success "=========================================="
}

main