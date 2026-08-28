#!/bin/bash

# ==========================================
# DevOps Auto Installer - System Dashboard
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Helper Functions
# ==========================================

get_service_status() {

    local service="$1"

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "RUNNING"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^${service}.service"; then
        echo "STOPPED"
    else
        echo "NOT INSTALLED"
    fi
}


get_command_status() {

    local command="$1"

    if command -v "$command" >/dev/null 2>&1; then
        echo "INSTALLED"
    else
        echo "NOT INSTALLED"
    fi
}


get_port_status() {

    local port="$1"

    if ss -tuln 2>/dev/null | grep -qE ":${port}[[:space:]]"; then
        echo "LISTENING"
    else
        echo "CLOSED"
    fi
}


# ==========================================
# Build Dashboard
# ==========================================

build_dashboard() {

    # System Information
    HOSTNAME=$(hostname)

    CPU_CORES=$(nproc)

    TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')
    USED_RAM=$(free -h | awk '/Mem:/ {print $3}')

    DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')

    OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

    UPTIME=$(uptime -p)

    # Services
    DOCKER_STATUS=$(get_service_status docker)
    CONTAINERD_STATUS=$(get_service_status containerd)
    KUBELET_STATUS=$(get_service_status kubelet)
    JENKINS_STATUS=$(get_service_status jenkins)
    PROMETHEUS_STATUS=$(get_service_status prometheus)
    GRAFANA_STATUS=$(get_service_status grafana-server)

    # Kubernetes Commands
    KUBEADM_STATUS=$(get_command_status kubeadm)
    KUBECTL_STATUS=$(get_command_status kubectl)

    # Ports
    PORT_6443=$(get_port_status 6443)
    PORT_8080=$(get_port_status 8080)
    PORT_9090=$(get_port_status 9090)
    PORT_3000=$(get_port_status 3000)

    cat <<EOF

==================================================
                 DEVOPS DASHBOARD
==================================================

SYSTEM INFORMATION

Hostname        : $HOSTNAME
Operating System: $OS_NAME
CPU Cores       : $CPU_CORES
RAM Used        : $USED_RAM / $TOTAL_RAM
Disk Used       : $DISK_USED
Disk Available  : $DISK_AVAILABLE
System Uptime   : $UPTIME


DEVOPS SERVICES

Docker          : $DOCKER_STATUS
Containerd      : $CONTAINERD_STATUS
Kubelet         : $KUBELET_STATUS
Jenkins         : $JENKINS_STATUS
Prometheus      : $PROMETHEUS_STATUS
Grafana         : $GRAFANA_STATUS


KUBERNETES TOOLS

kubeadm         : $KUBEADM_STATUS
kubectl         : $KUBECTL_STATUS


SERVICE PORTS

6443 Kubernetes API : $PORT_6443
8080 Jenkins        : $PORT_8080
9090 Prometheus     : $PORT_9090
3000 Grafana        : $PORT_3000

==================================================

EOF
}


# ==========================================
# Display Dashboard
# ==========================================

show_dashboard() {

    DASHBOARD_OUTPUT=$(build_dashboard)

    if command -v whiptail >/dev/null 2>&1; then

        whiptail \
            --title "DevOps System Dashboard" \
            --scrolltext \
            --msgbox "$DASHBOARD_OUTPUT" \
            30 90

    else

        clear
        echo "$DASHBOARD_OUTPUT"

        echo
        read -rp "Press Enter to return..."

    fi
}


# ==========================================
# Main
# ==========================================

show_dashboard