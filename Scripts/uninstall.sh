#!/bin/bash

# ==========================================
# DevOps Auto Installer - Uninstall
# Interactive Whiptail UI
# ==========================================

set -e

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Log Configuration
# ==========================================

LOG_DIR="$PROJECT_DIR/Logs"
LOG_FILE="$LOG_DIR/installer.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"


# ==========================================
# UI Helper Functions
# ==========================================

ui_info() {

    whiptail \
        --title "DevOps Auto Installer" \
        --backtitle "DevOps Component Uninstaller" \
        --infobox "$1" \
        8 70
}


ui_success() {

    whiptail \
        --title "✓ Operation Complete" \
        --backtitle "DevOps Component Uninstaller" \
        --msgbox "$1" \
        12 75
}


ui_error() {

    whiptail \
        --title "⚠ Operation Issue" \
        --backtitle "DevOps Component Uninstaller" \
        --msgbox "$1" \
        12 75
}


confirm_action() {

    whiptail \
        --title "Confirm Removal" \
        --backtitle "DevOps Component Uninstaller" \
        --yesno "$1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This action may permanently delete
configuration and stored data.

Do you want to continue?" \
        16 75
}


run_logged() {

    "$@" >> "$LOG_FILE" 2>&1
}


# ==========================================
# Wait for Kubernetes Cleanup
# ==========================================

wait_for_kubernetes_cleanup() {

    local total_seconds=20
    local interval=5
    local elapsed=0

    while [[ "$elapsed" -lt "$total_seconds" ]]; do

        sleep "$interval"

        elapsed=$((elapsed + interval))

        echo "[$(date '+%F %T')] Kubernetes cleanup wait: ${elapsed}/${total_seconds}" >> "$LOG_FILE"

    done
}


# ==========================================
# Kubernetes Cleanup Helper
# ==========================================

cleanup_kubernetes_files() {

    # Kubernetes configuration
    rm -rf /etc/kubernetes
    rm -rf /var/lib/kubelet
    rm -rf /var/lib/etcd

    # CNI configuration
    rm -rf /etc/cni
    rm -rf /opt/cni
    rm -rf /var/lib/cni

    # Runtime files
    rm -rf /run/kubernetes
    rm -rf /run/flannel

    # Root kubeconfig
    rm -rf /root/.kube

    # Current sudo user
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then

        local user_home

        user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6 || true)"

        if [[ -n "$user_home" && -d "$user_home" ]]; then

            rm -rf "$user_home/.kube"

        fi

    fi

    # Other users
    for user_home in /home/*; do

        if [[ -d "$user_home" ]]; then

            rm -rf "$user_home/.kube"

        fi

    done

    # Systemd
    rm -f /etc/systemd/system/kubelet.service

    rm -rf /etc/systemd/system/kubelet.service.d

    # Kubernetes repository
    rm -f /etc/apt/sources.list.d/kubernetes.list

    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # System configuration
    rm -f /etc/modules-load.d/k8s.conf

    rm -f /etc/sysctl.d/k8s.conf

    systemctl daemon-reload >/dev/null 2>&1 || true

    systemctl reset-failed >/dev/null 2>&1 || true

    sysctl --system >/dev/null 2>&1 || true
}


# ==========================================
# Docker Core Removal
# ==========================================

remove_docker_core() {

    systemctl stop docker docker.socket >/dev/null 2>&1 || true

    systemctl disable docker docker.socket >/dev/null 2>&1 || true

    systemctl stop containerd >/dev/null 2>&1 || true

    systemctl disable containerd >/dev/null 2>&1 || true

    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        >/dev/null 2>&1 || true

    apt-get autoremove -y >/dev/null 2>&1 || true

    apt-get autoclean -y >/dev/null 2>&1 || true

    rm -rf /var/lib/docker

    rm -rf /var/lib/containerd

    rm -rf /etc/containerd

    rm -f /etc/apt/sources.list.d/docker.list

    rm -f /etc/apt/keyrings/docker.asc

    systemctl daemon-reload >/dev/null 2>&1 || true

    apt-get update >/dev/null 2>&1 || true
}


# ==========================================
# Kubernetes Core Removal
# ==========================================

remove_kubernetes_core() {

    systemctl stop kubelet >/dev/null 2>&1 || true

    systemctl disable kubelet >/dev/null 2>&1 || true

    pkill -f kubelet >/dev/null 2>&1 || true

    pkill -f kube-apiserver >/dev/null 2>&1 || true

    pkill -f kube-controller-manager >/dev/null 2>&1 || true

    pkill -f kube-scheduler >/dev/null 2>&1 || true

    pkill -f etcd >/dev/null 2>&1 || true

    sleep 2

    if command -v kubeadm >/dev/null 2>&1; then

        kubeadm reset -f >/dev/null 2>&1 || true

    fi

    systemctl stop containerd >/dev/null 2>&1 || true

    apt-mark unhold \
        kubelet \
        kubeadm \
        kubectl \
        >/dev/null 2>&1 || true

    apt-get purge -y \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        >/dev/null 2>&1 || true

    dpkg --purge \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        >/dev/null 2>&1 || true

    apt-get autoremove -y >/dev/null 2>&1 || true

    apt-get autoclean -y >/dev/null 2>&1 || true

    cleanup_kubernetes_files

    hash -r 2>/dev/null || true

    apt-get update >/dev/null 2>&1 || true
}


# ==========================================
# Jenkins Core Removal
# ==========================================

remove_jenkins_core() {

    systemctl stop jenkins >/dev/null 2>&1 || true

    systemctl disable jenkins >/dev/null 2>&1 || true

    apt-get purge -y jenkins >/dev/null 2>&1 || true

    apt-get autoremove -y >/dev/null 2>&1 || true

    apt-get autoclean -y >/dev/null 2>&1 || true

    rm -rf /var/lib/jenkins

    rm -f /etc/default/jenkins

    rm -f /etc/apt/sources.list.d/jenkins.list

    rm -f /etc/apt/keyrings/jenkins-keyring.asc

    systemctl daemon-reload >/dev/null 2>&1 || true

    apt-get update >/dev/null 2>&1 || true
}


# ==========================================
# Prometheus Core Removal
# ==========================================

remove_prometheus_core() {

    systemctl stop prometheus >/dev/null 2>&1 || true

    systemctl disable prometheus >/dev/null 2>&1 || true

    rm -f /etc/systemd/system/prometheus.service

    systemctl daemon-reload >/dev/null 2>&1 || true

    userdel prometheus >/dev/null 2>&1 || true

    rm -rf /opt/prometheus

    rm -rf /etc/prometheus

    rm -rf /var/lib/prometheus

    rm -rf /opt/prometheus-installer
}


# ==========================================
# Grafana Core Removal
# ==========================================

remove_grafana_core() {

    systemctl stop grafana-server >/dev/null 2>&1 || true

    systemctl disable grafana-server >/dev/null 2>&1 || true

    apt-get purge -y grafana >/dev/null 2>&1 || true

    apt-get autoremove -y >/dev/null 2>&1 || true

    apt-get autoclean -y >/dev/null 2>&1 || true

    rm -rf /etc/grafana

    rm -rf /var/lib/grafana

    rm -rf /var/log/grafana

    rm -f /etc/apt/sources.list.d/grafana.list

    rm -f /etc/apt/keyrings/grafana.asc

    rm -f /etc/apt/keyrings/grafana.gpg

    systemctl daemon-reload >/dev/null 2>&1 || true

    apt-get update >/dev/null 2>&1 || true
}


# ==========================================
# Generic Component Removal UI
# ==========================================

remove_component() {

    local name="$1"
    local message="$2"
    local core_function="$3"

    if ! confirm_action "$message"; then
        return
    fi

    (
        echo "10"
        echo "XXX"
        echo "Preparing to remove $name..."
        echo "XXX"

        sleep 1

        echo "40"
        echo "XXX"
        echo "Removing $name..."
        echo "XXX"

        run_logged "$core_function"

        echo "85"
        echo "XXX"
        echo "Finalizing cleanup..."
        echo "XXX"

        sleep 1

        echo "100"
        echo "XXX"
        echo "$name removal completed."
        echo "XXX"

    ) | whiptail \
        --title "Removing $name" \
        --backtitle "DevOps Auto Installer" \
        --gauge "Starting..." \
        10 75 0

    ui_success "$name removal process completed.

You can verify the removal from:

  Verify Removal

Detailed output is available in:

  $LOG_FILE"
}


# ==========================================
# Remove Docker
# ==========================================

remove_docker() {

    remove_component \
        "Docker" \
        "This will remove:

• Docker Engine
• Containers
• Images
• Docker data
• Container runtime" \
        remove_docker_core
}


# ==========================================
# Remove Kubernetes
# ==========================================

remove_kubernetes() {

    if ! confirm_action \
        "This will remove:

• Kubernetes Cluster
• kubeadm
• kubelet
• kubectl
• CNI configuration
• Kubernetes data"; then

        return
    fi

    (
        echo "10"
        echo "XXX"
        echo "Stopping Kubernetes services..."
        echo "XXX"

        echo "35"
        echo "XXX"
        echo "Removing Kubernetes components..."
        echo "XXX"

        run_logged remove_kubernetes_core

        echo "65"
        echo "XXX"
        echo "Waiting for cleanup..."
        echo "XXX"

        wait_for_kubernetes_cleanup

        echo "100"
        echo "XXX"
        echo "Kubernetes removal completed."
        echo "XXX"

    ) | whiptail \
        --title "Removing Kubernetes" \
        --backtitle "DevOps Auto Installer" \
        --gauge "Starting..." \
        10 75 0

    ui_success "Kubernetes removal process completed.

You can run Verify Removal to check for remaining files or packages."
}


# ==========================================
# Remove Jenkins
# ==========================================

remove_jenkins() {

    remove_component \
        "Jenkins" \
        "This will remove:

• Jenkins service
• Jenkins jobs
• Jenkins configuration
• Jenkins stored data" \
        remove_jenkins_core
}


# ==========================================
# Remove Prometheus
# ==========================================

remove_prometheus() {

    remove_component \
        "Prometheus" \
        "This will remove:

• Prometheus service
• Monitoring configuration
• Prometheus database
• Stored metrics" \
        remove_prometheus_core
}


# ==========================================
# Remove Grafana
# ==========================================

remove_grafana() {

    remove_component \
        "Grafana" \
        "This will remove:

• Grafana service
• Dashboards
• Configuration
• Grafana database" \
        remove_grafana_core
}


# ==========================================
# Verify Uninstall
# ==========================================

verify_uninstall() {

    local result_file

    result_file="$(mktemp)"

    {

        echo "DEVOPS REMOVAL VERIFICATION"
        echo "=========================================="
        echo

        local failures=0

        echo "[ Docker ]"

        if command -v docker >/dev/null 2>&1 || [[ -d "/var/lib/docker" ]]; then

            echo "[WARNING] Docker components still exist."
            failures=$((failures + 1))

        else

            echo "[SUCCESS] Docker removed."

        fi

        echo
        echo "[ Kubernetes ]"

        local kubernetes_found=false

        hash -r 2>/dev/null || true

        for cmd in kubeadm kubelet kubectl; do

            if command -v "$cmd" >/dev/null 2>&1; then

                echo "[WARNING] Kubernetes command still found: $cmd"
                kubernetes_found=true

            fi

        done

        if dpkg-query -W \
            -f='${db:Status-Abbrev} ${binary:Package}\n' \
            2>/dev/null |
            grep -qE '^ii[[:space:]]+(kubeadm|kubelet|kubectl|kubernetes-cni|cri-tools)(:|[[:space:]])'; then

            echo "[WARNING] Kubernetes packages are still installed."
            kubernetes_found=true

        fi

        for dir in \
            /etc/kubernetes \
            /var/lib/kubelet \
            /var/lib/etcd \
            /etc/cni \
            /opt/cni \
            /var/lib/cni \
            /run/kubernetes
        do

            if [[ -e "$dir" ]]; then

                echo "[WARNING] Kubernetes leftover found: $dir"
                kubernetes_found=true

            fi

        done

        if [[ "$kubernetes_found" == false ]]; then

            echo "[SUCCESS] Kubernetes completely removed."

        else

            echo "[WARNING] Kubernetes components or configuration still exist."
            failures=$((failures + 1))

        fi

        echo
        echo "[ Jenkins ]"

        if command -v jenkins >/dev/null 2>&1 || \
           systemctl list-unit-files 2>/dev/null | grep -q "^jenkins.service"; then

            echo "[WARNING] Jenkins is still installed."
            failures=$((failures + 1))

        else

            echo "[SUCCESS] Jenkins removed."

        fi

        echo
        echo "[ Prometheus ]"

        if [[ -e "/opt/prometheus/prometheus" ]] || \
           [[ -d "/etc/prometheus" ]] || \
           systemctl list-unit-files 2>/dev/null | grep -q "^prometheus.service"; then

            echo "[WARNING] Prometheus is still installed."
            failures=$((failures + 1))

        else

            echo "[SUCCESS] Prometheus removed."

        fi

        echo
        echo "[ Grafana ]"

        if command -v grafana-server >/dev/null 2>&1 || \
           [[ -d "/etc/grafana" ]]; then

            echo "[WARNING] Grafana is still installed."
            failures=$((failures + 1))

        else

            echo "[SUCCESS] Grafana removed."

        fi

        echo
        echo "=========================================="

        if [[ "$failures" -eq 0 ]]; then

            echo "[SUCCESS] ALL DEVOPS COMPONENTS REMOVED."

        else

            echo "[WARNING] SOME COMPONENTS STILL EXIST."

        fi

    } > "$result_file"

    cat "$result_file" >> "$LOG_FILE"

    whiptail \
        --title "Removal Verification" \
        --backtitle "DevOps Auto Installer" \
        --textbox "$result_file" \
        28 95

    rm -f "$result_file"
}


# ==========================================
# Remove Everything
# ==========================================

remove_everything() {

    if ! whiptail \
        --title "⚠ Remove Everything" \
        --backtitle "DevOps Auto Installer" \
        --yesno "WARNING!

This will permanently remove:

• Docker
• Kubernetes
• Jenkins
• Prometheus
• Grafana

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All related configuration and local data
may be permanently deleted.

Do you want to continue?" \
        22 75; then

        return

    fi

    (
        echo "5"
        echo "XXX"
        echo "Preparing complete removal..."
        echo "XXX"

        echo "15"
        echo "XXX"
        echo "Removing Grafana..."
        echo "XXX"

        run_logged remove_grafana_core

        echo "30"
        echo "XXX"
        echo "Removing Prometheus..."
        echo "XXX"

        run_logged remove_prometheus_core

        echo "45"
        echo "XXX"
        echo "Removing Jenkins..."
        echo "XXX"

        run_logged remove_jenkins_core

        echo "60"
        echo "XXX"
        echo "Removing Kubernetes..."
        echo "XXX"

        run_logged remove_kubernetes_core

        echo "75"
        echo "XXX"
        echo "Waiting for Kubernetes cleanup..."
        echo "XXX"

        wait_for_kubernetes_cleanup

        echo "88"
        echo "XXX"
        echo "Removing Docker..."
        echo "XXX"

        run_logged remove_docker_core

        echo "96"
        echo "XXX"
        echo "Running final cleanup..."
        echo "XXX"

        apt-get autoremove -y >> "$LOG_FILE" 2>&1 || true
        apt-get autoclean -y >> "$LOG_FILE" 2>&1 || true
        apt-get update >> "$LOG_FILE" 2>&1 || true

        echo "100"
        echo "XXX"
        echo "Complete removal finished."
        echo "XXX"

        sleep 1

    ) | whiptail \
        --title "Complete DevOps Removal" \
        --backtitle "DevOps Auto Installer" \
        --gauge "Starting complete removal..." \
        10 75 0

    verify_uninstall

    ui_success "Complete DevOps removal finished.

Please review:

• Removal Verification
• Installer Log

for final details."
}


# ==========================================
# View Installer Logs
# ==========================================

view_logs() {

    if [[ ! -s "$LOG_FILE" ]]; then

        echo "No installer log entries yet." > "$LOG_FILE"

    fi

    whiptail \
        --title "Installer Log" \
        --backtitle "DevOps Auto Installer" \
        --textbox "$LOG_FILE" \
        30 110
}


# ==========================================
# Main Whiptail Menu
# ==========================================

main() {

    initialize

    while true; do

        choice=$(whiptail \
            --title "DevOps Component Uninstaller" \
            --backtitle "DevOps Auto Installer" \
            --menu "Select a component or action:" \
            25 78 14 \
            "1" "Remove Docker & Containerd" \
            "2" "Remove Kubernetes" \
            "3" "Remove Jenkins" \
            "4" "Remove Prometheus" \
            "5" "Remove Grafana" \
            "6" "Remove Everything" \
            "7" "Verify Removal Status" \
            "8" "View Installer Log" \
            "0" "Return to Main Installer" \
            3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]]; then
            break
        fi

        case "$choice" in

            1)
                remove_docker
                ;;

            2)
                remove_kubernetes
                ;;

            3)
                remove_jenkins
                ;;

            4)
                remove_prometheus
                ;;

            5)
                remove_grafana
                ;;

            6)
                remove_everything
                ;;

            7)
                verify_uninstall
                ;;

            8)
                view_logs
                ;;

            0)
                break
                ;;

        esac

    done
}


# ==========================================
# Start
# ==========================================

main