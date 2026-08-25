#!/bin/bash

# ==========================================
# DevOps Auto Installer - Uninstall
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Confirmation
# ==========================================

confirm_action() {

    local message="$1"

    echo
    warning "$message"

    read -rp "Continue? [y/N]: " confirmation

    case "$confirmation" in
        y|Y)
            return 0
            ;;
        *)
            warning "Operation cancelled."
            return 1
            ;;
    esac
}

# ==========================================
# Wait for Kubernetes Cleanup
# ==========================================

wait_for_kubernetes_cleanup() {

    local total_seconds=60
    local interval=10
    local elapsed=0

    info "Waiting for Kubernetes cleanup to settle..."

    while [[ "$elapsed" -lt "$total_seconds" ]]; do

        sleep "$interval"

        elapsed=$((elapsed + interval))

        info "Verification wait: ${elapsed}/${total_seconds} seconds"

    done
}

# ==========================================
# Kubernetes Cleanup Helper
# ==========================================

cleanup_kubernetes_files() {

    info "Removing Kubernetes files and configuration..."

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

    # Sudo user kubeconfig
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then

        local user_home

        user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

        if [[ -n "$user_home" && -d "$user_home" ]]; then

            info "Removing kubectl configuration for user: $SUDO_USER"

            rm -rf "$user_home/.kube"

        fi

    fi

    # Other users
    for user_home in /home/*; do

        if [[ -d "$user_home" ]]; then
            rm -rf "$user_home/.kube"
        fi

    done

    # Systemd configuration
    rm -f /etc/systemd/system/kubelet.service
    rm -rf /etc/systemd/system/kubelet.service.d

    # Kubernetes repository
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Kubernetes system configuration
    rm -f /etc/modules-load.d/k8s.conf
    rm -f /etc/sysctl.d/k8s.conf

    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true

    sysctl --system >/dev/null 2>&1 || true
}

# ==========================================
# Remove Docker
# ==========================================

remove_docker() {

    if ! confirm_action "This will remove Docker from the system."; then
        return
    fi

    info "Removing Docker..."

    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true

    systemctl stop containerd 2>/dev/null || true
    systemctl disable containerd 2>/dev/null || true

    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        2>/dev/null || true

    apt-get autoremove -y
    apt-get autoclean -y

    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/containerd

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc

    systemctl daemon-reload 2>/dev/null || true

    apt-get update

    success "Docker removal completed."
}

# ==========================================
# Remove Kubernetes
# ==========================================

remove_kubernetes() {

    if ! confirm_action "This will remove the Kubernetes cluster and all Kubernetes configuration."; then
        return
    fi

    info "Removing Kubernetes..."

    # ------------------------------------------
    # Stop Kubernetes Services
    # ------------------------------------------

    info "Stopping Kubernetes services..."

    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true

    # Kill remaining Kubernetes processes
    pkill -f kubelet 2>/dev/null || true
    pkill -f kube-apiserver 2>/dev/null || true
    pkill -f kube-controller-manager 2>/dev/null || true
    pkill -f kube-scheduler 2>/dev/null || true
    pkill -f etcd 2>/dev/null || true

    sleep 5

    # ------------------------------------------
    # Reset Kubernetes Cluster
    # ------------------------------------------

    if command_exists kubeadm; then

        info "Resetting Kubernetes cluster..."

        kubeadm reset -f || true

    else

        info "kubeadm not found. Skipping cluster reset."

    fi

    # ------------------------------------------
    # Stop Container Runtime
    # ------------------------------------------

    systemctl stop containerd 2>/dev/null || true

    # ------------------------------------------
    # Remove Kubernetes Packages
    # ------------------------------------------

    info "Removing Kubernetes packages..."

    apt-mark unhold \
        kubelet \
        kubeadm \
        kubectl \
        2>/dev/null || true

    apt-get purge -y \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        2>/dev/null || true

    # Force purge if package database still contains entries
    dpkg --purge \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        2>/dev/null || true

    apt-get autoremove -y
    apt-get autoclean -y

    # ------------------------------------------
    # Remove Files
    # ------------------------------------------

    cleanup_kubernetes_files

    # ------------------------------------------
    # Final Cleanup
    # ------------------------------------------

    sleep 5

    cleanup_kubernetes_files

    apt-get update

    success "Kubernetes removal completed."

    wait_for_kubernetes_cleanup
}

# ==========================================
# Remove Jenkins
# ==========================================

remove_jenkins() {

    if ! confirm_action "This will remove Jenkins and its configuration."; then
        return
    fi

    info "Removing Jenkins..."

    systemctl stop jenkins 2>/dev/null || true
    systemctl disable jenkins 2>/dev/null || true

    apt-get purge -y jenkins 2>/dev/null || true

    apt-get autoremove -y
    apt-get autoclean -y

    rm -rf /var/lib/jenkins
    rm -f /etc/default/jenkins

    rm -f /etc/apt/sources.list.d/jenkins.list
    rm -f /etc/apt/keyrings/jenkins-keyring.asc

    systemctl daemon-reload 2>/dev/null || true

    apt-get update

    success "Jenkins removal completed."
}

# ==========================================
# Remove Prometheus
# ==========================================

remove_prometheus() {

    if ! confirm_action "This will remove Prometheus and its stored monitoring data."; then
        return
    fi

    info "Removing Prometheus..."

    systemctl stop prometheus 2>/dev/null || true
    systemctl disable prometheus 2>/dev/null || true

    rm -f /etc/systemd/system/prometheus.service

    systemctl daemon-reload 2>/dev/null || true

    userdel prometheus 2>/dev/null || true

    rm -rf /opt/prometheus
    rm -rf /etc/prometheus
    rm -rf /var/lib/prometheus
    rm -rf /opt/prometheus-installer

    success "Prometheus removal completed."
}

# ==========================================
# Remove Grafana
# ==========================================

remove_grafana() {

    if ! confirm_action "This will remove Grafana and its configuration."; then
        return
    fi

    info "Removing Grafana..."

    systemctl stop grafana-server 2>/dev/null || true
    systemctl disable grafana-server 2>/dev/null || true

    apt-get purge -y grafana 2>/dev/null || true

    apt-get autoremove -y
    apt-get autoclean -y

    rm -rf /etc/grafana
    rm -rf /var/lib/grafana
    rm -rf /var/log/grafana

    rm -f /etc/apt/sources.list.d/grafana.list
    rm -f /etc/apt/keyrings/grafana.asc
    rm -f /etc/apt/keyrings/grafana.gpg

    systemctl daemon-reload 2>/dev/null || true

    apt-get update

    success "Grafana removal completed."
}

# ==========================================
# Verify Kubernetes Removal
# ==========================================

verify_kubernetes_removal() {

    local kubernetes_found=false

    # ------------------------------------------
    # Check Commands
    # ------------------------------------------

    for cmd in kubeadm kubelet kubectl; do

        if command_exists "$cmd"; then

            warning "Kubernetes command still found: $cmd"

            kubernetes_found=true

        fi

    done

    # ------------------------------------------
    # Check Installed Packages
    # ------------------------------------------

    if dpkg-query -W \
        -f='${db:Status-Abbrev} ${binary:Package}\n' \
        2>/dev/null | \
        grep -qE '^ii[[:space:]]+(kubeadm|kubelet|kubectl|kubernetes-cni|cri-tools)(:|[[:space:]])'; then

        warning "Kubernetes packages are still installed."

        kubernetes_found=true

    fi

    # ------------------------------------------
    # Check Directories
    # ------------------------------------------

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

            warning "Kubernetes leftover found: $dir"

            kubernetes_found=true

        fi

    done

    # ------------------------------------------
    # Result
    # ------------------------------------------

    if [[ "$kubernetes_found" == false ]]; then

        success "Kubernetes completely removed."

        return 0

    else

        warning "Kubernetes components or configuration still exist."

        return 1

    fi
}

# ==========================================
# Verify Uninstall
# ==========================================

verify_uninstall() {

    echo

    info "Verifying software removal..."

    local failures=0

    # ------------------------------------------
    # Docker
    # ------------------------------------------

    if command_exists docker; then

        warning "Docker is still installed."

        failures=$((failures + 1))

    else

        success "Docker removed."

    fi

    # ------------------------------------------
    # Kubernetes
    # ------------------------------------------

    if ! verify_kubernetes_removal; then

        failures=$((failures + 1))

    fi

    # ------------------------------------------
    # Jenkins
    # ------------------------------------------

    if command_exists jenkins; then

        warning "Jenkins is still installed."

        failures=$((failures + 1))

    elif systemctl list-unit-files 2>/dev/null | grep -q "^jenkins.service"; then

        warning "Jenkins service still exists."

        failures=$((failures + 1))

    else

        success "Jenkins removed."

    fi

    # ------------------------------------------
    # Prometheus
    # ------------------------------------------

    if [[ -e "/opt/prometheus/prometheus" ]] || \
       [[ -d "/etc/prometheus" ]] || \
       systemctl list-unit-files 2>/dev/null | grep -q "^prometheus.service"; then

        warning "Prometheus is still installed."

        failures=$((failures + 1))

    else

        success "Prometheus removed."

    fi

    # ------------------------------------------
    # Grafana
    # ------------------------------------------

    if command_exists grafana-server; then

        warning "Grafana is still installed."

        failures=$((failures + 1))

    else

        success "Grafana removed."

    fi

    # ------------------------------------------
    # Final Result
    # ------------------------------------------

    echo

    if [[ "$failures" -eq 0 ]]; then

        success "=========================================="
        success "All DevOps components have been removed."
        success "=========================================="

    else

        warning "Some components were not completely removed."

    fi
}

# ==========================================
# Remove Everything
# ==========================================

remove_everything() {

    echo
    echo "=========================================="
    echo "       REMOVE EVERYTHING"
    echo "=========================================="
    echo

    warning "This will remove:"
    echo "  - Docker"
    echo "  - Kubernetes"
    echo "  - Jenkins"
    echo "  - Prometheus"
    echo "  - Grafana"
    echo

    read -rp "Are you sure you want to continue? [y/N]: " confirmation

    case "$confirmation" in

        y|Y)
            ;;
        *)
            warning "Complete removal cancelled."
            return
            ;;

    esac

    info "Starting complete DevOps software removal..."

    # ------------------------------------------
    # Grafana
    # ------------------------------------------

    systemctl stop grafana-server 2>/dev/null || true
    systemctl disable grafana-server 2>/dev/null || true

    apt-get purge -y grafana 2>/dev/null || true

    rm -rf /etc/grafana
    rm -rf /var/lib/grafana
    rm -rf /var/log/grafana

    rm -f /etc/apt/sources.list.d/grafana.list
    rm -f /etc/apt/keyrings/grafana.asc
    rm -f /etc/apt/keyrings/grafana.gpg

    success "Grafana removed."

    # ------------------------------------------
    # Prometheus
    # ------------------------------------------

    systemctl stop prometheus 2>/dev/null || true
    systemctl disable prometheus 2>/dev/null || true

    rm -f /etc/systemd/system/prometheus.service

    userdel prometheus 2>/dev/null || true

    rm -rf /opt/prometheus
    rm -rf /etc/prometheus
    rm -rf /var/lib/prometheus
    rm -rf /opt/prometheus-installer

    success "Prometheus removed."

    # ------------------------------------------
    # Jenkins
    # ------------------------------------------

    systemctl stop jenkins 2>/dev/null || true
    systemctl disable jenkins 2>/dev/null || true

    apt-get purge -y jenkins 2>/dev/null || true

    rm -rf /var/lib/jenkins
    rm -f /etc/default/jenkins

    rm -f /etc/apt/sources.list.d/jenkins.list
    rm -f /etc/apt/keyrings/jenkins-keyring.asc

    success "Jenkins removed."

    # ------------------------------------------
    # Kubernetes
    # ------------------------------------------

    info "Removing Kubernetes..."

    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true

    pkill -f kubelet 2>/dev/null || true
    pkill -f kube-apiserver 2>/dev/null || true
    pkill -f kube-controller-manager 2>/dev/null || true
    pkill -f kube-scheduler 2>/dev/null || true
    pkill -f etcd 2>/dev/null || true

    sleep 5

    if command_exists kubeadm; then

        info "Resetting Kubernetes cluster..."

        kubeadm reset -f || true

    fi

    systemctl stop containerd 2>/dev/null || true

    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true

    apt-get purge -y \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        2>/dev/null || true

    dpkg --purge \
        kubeadm \
        kubelet \
        kubectl \
        kubernetes-cni \
        cri-tools \
        2>/dev/null || true

    cleanup_kubernetes_files

    success "Kubernetes removed."

    # ------------------------------------------
    # Docker
    # ------------------------------------------

    info "Removing Docker..."

    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true

    systemctl stop containerd 2>/dev/null || true
    systemctl disable containerd 2>/dev/null || true

    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        2>/dev/null || true

    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/containerd

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc

    # ------------------------------------------
    # Final Package Cleanup
    # ------------------------------------------

    info "Running final package cleanup..."

    apt-get autoremove -y
    apt-get autoclean -y

    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true

    apt-get update

    # ------------------------------------------
    # Wait for Kubernetes Cleanup
    # ------------------------------------------

    wait_for_kubernetes_cleanup

    # ------------------------------------------
    # Final Verification
    # ------------------------------------------

    echo

    verify_uninstall

    echo

    success "=========================================="
    success "COMPLETE DEVOPS REMOVAL FINISHED"
    success "=========================================="
}

# ==========================================
# Uninstall Menu
# ==========================================

show_uninstall_menu() {

    clear

    echo
    echo "=========================================="
    echo "       DEVOPS UNINSTALLER"
    echo "=========================================="
    echo

    echo "1. Remove Docker"
    echo "2. Remove Kubernetes"
    echo "3. Remove Jenkins"
    echo "4. Remove Prometheus"
    echo "5. Remove Grafana"
    echo "6. Remove Everything"
    echo "7. Verify Removal"
    echo "0. Back"

    echo
}

# ==========================================
# Handle Choice
# ==========================================

handle_choice() {

    local choice="$1"

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

        0)
            return 1
            ;;

        *)
            warning "Invalid option."
            ;;

    esac

    return 0
}

# ==========================================
# Main
# ==========================================

main() {

    initialize

    while true; do

        show_uninstall_menu

        read -rp "Choose an option: " choice

        echo

        if ! handle_choice "$choice"; then
            break
        fi

        echo

        read -rp "Press Enter to continue..."

    done
}

# ==========================================
# Start
# ==========================================

main