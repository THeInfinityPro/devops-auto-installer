#!/bin/bash

# ==========================================
# DevOps Auto Installer - Health Check
# ==========================================

set -u

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Default Configuration
# ==========================================

JENKINS_PORT="${JENKINS_PORT:-8080}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
KUBERNETES_API_PORT="${KUBERNETES_API_PORT:-6443}"

# ==========================================
# Health Counters
# ==========================================

PASS_COUNT=0
WARN_COUNT=0

health_success() {

    success "$1"
    ((PASS_COUNT+=1))

    log "[SUCCESS] $1"
}

health_warning() {

    warning "$1"
    ((WARN_COUNT+=1))

    log "[WARNING] $1"
}

# ==========================================
# CPU Check
# ==========================================

check_cpu() {

    info "Checking CPU..."

    local CPU_CORES

    CPU_CORES=$(nproc 2>/dev/null || echo 0)

    echo "CPU cores: $CPU_CORES"

    if [[ "$CPU_CORES" -ge 2 ]]; then

        health_success "CPU resources are sufficient."

    else

        health_warning "Only one CPU core detected. Recommended: at least 2 cores."

    fi
}

# ==========================================
# Memory Check
# ==========================================

check_memory() {

    info "Checking system memory..."

    local TOTAL_RAM
    local AVAILABLE_RAM

    TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
    AVAILABLE_RAM=$(free -m | awk '/Mem:/ {print $7}')

    echo "Total RAM     : ${TOTAL_RAM}MB"
    echo "Available RAM : ${AVAILABLE_RAM}MB"

    if [[ "$TOTAL_RAM" -ge 4096 ]]; then

        health_success "Memory is sufficient."

    else

        health_warning "Low RAM. Recommended: at least 4GB."

    fi
}

# ==========================================
# Disk Check
# ==========================================

check_disk() {

    info "Checking disk space..."

    local AVAILABLE_DISK
    local USED_PERCENT

    AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    USED_PERCENT=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

    echo "Available disk space : ${AVAILABLE_DISK}GB"
    echo "Disk usage           : ${USED_PERCENT}%"

    if [[ "$AVAILABLE_DISK" -ge 20 ]]; then

        health_success "Disk space is sufficient."

    else

        health_warning "Low disk space. Recommended: at least 20GB available."

    fi

    if [[ "$USED_PERCENT" -ge 90 ]]; then

        health_warning "Disk usage is above 90%."

    fi
}

# ==========================================
# Internet Check
# ==========================================

check_internet() {

    info "Checking Internet connectivity..."

    # DNS check
    if getent hosts github.com >/dev/null 2>&1; then

        health_success "DNS resolution is working."

    else

        health_warning "DNS resolution could not be verified."

    fi

    # HTTPS check
    if command_exists curl; then

        if curl \
            -fsS \
            --connect-timeout 5 \
            --max-time 10 \
            https://github.com \
            >/dev/null 2>&1; then

            health_success "Internet HTTPS connectivity is available."

        else

            health_warning "Internet HTTPS connectivity could not be verified."

        fi

    else

        health_warning "curl is not installed. Internet HTTPS check skipped."

    fi
}

# ==========================================
# Required Commands Check
# ==========================================

check_required_commands() {

    info "Checking required system commands..."

    local COMMANDS=(
        "bash"
        "curl"
        "wget"
        "tar"
        "ss"
        "systemctl"
        "df"
        "free"
    )

    local COMMAND

    for COMMAND in "${COMMANDS[@]}"
    do

        if command_exists "$COMMAND"; then

            health_success "$COMMAND command is available."

        else

            health_warning "$COMMAND command is not available."

        fi

    done
}

# ==========================================
# Check Single Port
# ==========================================

check_port() {

    local PORT="$1"
    local SERVICE="$2"

    echo
    echo "------------------------------------------"
    info "Port $PORT - $SERVICE"
    echo "------------------------------------------"

    if ss -tuln 2>/dev/null |
        grep -qE "[:.]${PORT}[[:space:]]"; then

        health_success "Port $PORT is listening locally."

        echo

        info "Listening process:"

        ss -tulpn 2>/dev/null |
            grep -E "[:.]${PORT}[[:space:]]" || true

    else

        info "Port $PORT is not currently listening."

    fi
}

# ==========================================
# Port Status Check
# ==========================================

check_ports() {

    info "Checking DevOps required ports..."

    check_port \
        "$KUBERNETES_API_PORT" \
        "Kubernetes API"

    check_port \
        "$JENKINS_PORT" \
        "Jenkins"

    check_port \
        "$PROMETHEUS_PORT" \
        "Prometheus"

    check_port \
        "$GRAFANA_PORT" \
        "Grafana"
}

# ==========================================
# HTTP Services Check
# ==========================================

check_http_services() {

    info "Checking DevOps web services..."

    # Jenkins

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${JENKINS_PORT}/login" \
        >/dev/null 2>&1; then

        health_success "Jenkins HTTP service is responding."

    else

        info "Jenkins HTTP service is not responding."

    fi

    # Prometheus

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
        >/dev/null 2>&1; then

        health_success "Prometheus HTTP service is responding."

    else

        info "Prometheus HTTP service is not responding."

    fi

    # Grafana

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${GRAFANA_PORT}/api/health" \
        >/dev/null 2>&1; then

        health_success "Grafana HTTP service is responding."

    else

        info "Grafana HTTP service is not responding."

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

        local UFW_STATUS

        UFW_STATUS=$(ufw status 2>/dev/null | head -n 1)

        echo "UFW Status: $UFW_STATUS"

        if ufw status 2>/dev/null |
            grep -q "Status: active"; then

            info "UFW firewall is active."

            echo

            info "Configured UFW rules:"

            ufw status numbered || true

        else

            health_success "UFW firewall is inactive."

        fi

    else

        info "UFW is not installed."

    fi

    echo

    # ------------------------------------------
    # iptables
    # ------------------------------------------

    if command_exists iptables; then

        info "Checking iptables firewall..."

        if iptables -L -n >/dev/null 2>&1; then

            health_success "iptables rules detected."

        else

            health_warning "Unable to read iptables rules."

        fi

    else

        info "iptables command is not installed."

    fi
}

# ==========================================
# Cloud Firewall Information
# ==========================================

check_cloud_firewall_notice() {

    echo

    info "Checking external firewall limitations..."

    health_warning \
        "This script can verify local ports and local firewall rules."

    health_warning \
        "Cloud firewall rules cannot always be verified from inside the server."

    echo

    echo "If using AWS EC2, check Security Group inbound rules."

    echo
    echo "Recommended ports:"
    echo
    echo "  22   - SSH"
    echo "  ${GRAFANA_PORT} - Grafana"
    echo "  ${KUBERNETES_API_PORT} - Kubernetes API"
    echo "  ${JENKINS_PORT} - Jenkins"
    echo "  ${PROMETHEUS_PORT} - Prometheus"
}

# ==========================================
# Existing Components Check
# ==========================================

check_existing_components() {

    info "Checking existing DevOps components..."

    echo

    # Docker

    if command_exists docker; then

        health_success \
            "Docker is installed: $(docker --version 2>/dev/null || true)"

    else

        info "Docker is not installed."

    fi

    # Kubernetes kubeadm

    if command_exists kubeadm; then

        health_success \
            "Kubernetes kubeadm is installed."

    else

        info "Kubernetes kubeadm is not installed."

    fi

    # Kubernetes kubectl

    if command_exists kubectl; then

        health_success \
            "Kubernetes kubectl is installed."

    else

        info "Kubernetes kubectl is not installed."

    fi

    # Kubernetes kubelet

    if command_exists kubelet; then

        health_success \
            "Kubernetes kubelet is installed."

    else

        info "Kubernetes kubelet is not installed."

    fi

    # Jenkins

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^jenkins.service"; then

        health_success "Jenkins is installed."

    elif command_exists jenkins; then

        health_success "Jenkins is installed."

    else

        info "Jenkins is not installed."

    fi

    # Prometheus

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^prometheus.service"; then

        health_success "Prometheus is installed."

    elif [[ -x "/opt/prometheus/prometheus" ]]; then

        health_success "Prometheus is installed."

    else

        info "Prometheus is not installed."

    fi

    # Grafana

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^grafana-server.service"; then

        health_success "Grafana is installed."

    elif command_exists grafana-server; then

        health_success "Grafana is installed."

    else

        info "Grafana is not installed."

    fi
}

# ==========================================
# Check Single Service
# ==========================================

check_service() {

    local SERVICE="$1"
    local DISPLAY_NAME="$2"

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^${SERVICE}.service"; then

        if systemctl is-active --quiet "$SERVICE"; then

            health_success "$DISPLAY_NAME service is running."

        else

            health_warning \
                "$DISPLAY_NAME service is installed but not running."

        fi

    else

        info "$DISPLAY_NAME service is not installed."

    fi
}

# ==========================================
# Service Status Check
# ==========================================

check_services() {

    info "Checking DevOps service status..."

    check_service "docker" "Docker"
    check_service "containerd" "Containerd"
    check_service "kubelet" "Kubelet"
    check_service "jenkins" "Jenkins"
    check_service "prometheus" "Prometheus"
    check_service "grafana-server" "Grafana"
}

# ==========================================
# Kubernetes Cluster Readiness
# ==========================================

check_kubernetes_cluster() {

    info "Checking Kubernetes cluster status..."

    if ! command_exists kubectl; then

        info "kubectl is not installed. Skipping cluster check."

        return

    fi

    local KUBE_CONFIG=""

    if [[ -f "/etc/kubernetes/admin.conf" ]]; then

        KUBE_CONFIG="/etc/kubernetes/admin.conf"

    elif [[ -f "$HOME/.kube/config" ]]; then

        KUBE_CONFIG="$HOME/.kube/config"

    else

        info "Kubernetes cluster is not initialized."

        return

    fi

    if kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        get nodes \
        >/dev/null 2>&1; then

        health_success "Kubernetes cluster is reachable."

        echo

        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get nodes -o wide || true

    else

        health_warning "Kubernetes cluster is not reachable."

    fi
}

# ==========================================
# Overall Summary
# ==========================================

show_summary() {

    echo
    echo "=========================================="
    echo "         SYSTEM HEALTH SUMMARY"
    echo "=========================================="
    echo

    echo "Successful checks : $PASS_COUNT"
    echo "Warnings          : $WARN_COUNT"

    echo

    if [[ "$WARN_COUNT" -eq 0 ]]; then

        success "System health status: EXCELLENT"

    elif [[ "$WARN_COUNT" -le 5 ]]; then

        success "System health status: READY"

    else

        warning "System health status: REVIEW WARNINGS"

    fi

    echo
    echo "=========================================="
}

# ==========================================
# Main
# ==========================================

main() {

    clear

    echo
    echo "=========================================="
    echo "        SYSTEM HEALTH CHECK"
    echo "=========================================="
    echo

    initialize

    log "[INFO] System health check started."

    show_system_info

    echo

    check_required_commands

    echo

    check_cpu

    echo

    check_memory

    echo

    check_disk

    echo

    check_internet

    echo

    check_existing_components

    echo

    check_services

    echo

    check_kubernetes_cluster

    echo

    check_ports

    echo

    check_http_services

    echo

    check_firewall

    check_cloud_firewall_notice

    show_summary

    log "[INFO] System health check completed."

    echo

    success "=========================================="
    success "SYSTEM HEALTH CHECK COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Start
# ==========================================

main