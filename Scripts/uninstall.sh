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
# Remove Docker
# ==========================================

remove_docker() {

    if ! confirm_action "This will remove Docker from the system."; then
        return
    fi

    info "Removing Docker..."

    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true

    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        2>/dev/null || true

    apt-get autoremove -y

    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc

    success "Docker removal completed."
}

# ==========================================
# Remove Kubernetes
# ==========================================

remove_kubernetes() {

    if ! confirm_action "This will remove the Kubernetes cluster and Kubernetes configuration."; then
        return
    fi

    info "Removing Kubernetes..."

    # ------------------------------------------
    # Reset Kubernetes Cluster
    # ------------------------------------------

    if command_exists kubeadm; then

        info "Resetting Kubernetes cluster..."

        kubeadm reset -f || true

    else

        warning "kubeadm is not installed. Skipping cluster reset."

    fi

    # ------------------------------------------
    # Stop Kubernetes Services
    # ------------------------------------------

    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true

    # ------------------------------------------
    # Stop Containerd
    # ------------------------------------------

    systemctl stop containerd 2>/dev/null || true

    # ------------------------------------------
    # Remove Kubernetes Packages
    # ------------------------------------------

    info "Removing Kubernetes packages..."

    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true

    apt-get purge -y \
        kubelet \
        kubeadm \
        kubectl \
        2>/dev/null || true

    apt-get autoremove -y

    # ------------------------------------------
    # Remove Kubernetes Configuration
    # ------------------------------------------

    rm -rf /etc/kubernetes
    rm -rf /var/lib/kubelet
    rm -rf /etc/cni
    rm -rf /opt/cni

    rm -rf "$HOME/.kube"

    # ------------------------------------------
    # Remove Kubernetes Repository
    # ------------------------------------------

    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # ------------------------------------------
    # Remove Kubernetes Kernel Configuration
    # ------------------------------------------

    rm -f /etc/modules-load.d/k8s.conf
    rm -f /etc/sysctl.d/k8s.conf

    sysctl --system >/dev/null 2>&1 || true

    # ------------------------------------------
    # Restart Containerd
    # ------------------------------------------

    systemctl start containerd 2>/dev/null || true
    systemctl enable containerd 2>/dev/null || true

    apt-get update

    success "Kubernetes removal completed."
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

    rm -rf /var/lib/jenkins
    rm -rf /etc/default/jenkins

    rm -f /etc/apt/sources.list.d/jenkins.list
    rm -f /etc/apt/keyrings/jenkins-keyring.asc

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

    systemctl daemon-reload

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

    rm -rf /etc/grafana
    rm -rf /var/lib/grafana
    rm -rf /var/log/grafana

    rm -f /etc/apt/sources.list.d/grafana.list
    rm -f /etc/apt/keyrings/grafana.gpg

    success "Grafana removal completed."
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

    echo

    info "Starting complete DevOps software removal..."

    # ==========================================
    # Grafana
    # ==========================================

    info "Removing Grafana..."

    systemctl stop grafana-server 2>/dev/null || true
    systemctl disable grafana-server 2>/dev/null || true

    apt-get purge -y grafana 2>/dev/null || true

    rm -rf /etc/grafana
    rm -rf /var/lib/grafana
    rm -rf /var/log/grafana

    rm -f /etc/apt/sources.list.d/grafana.list
    rm -f /etc/apt/keyrings/grafana.gpg

    success "Grafana removed."

    # ==========================================
    # Prometheus
    # ==========================================

    info "Removing Prometheus..."

    systemctl stop prometheus 2>/dev/null || true
    systemctl disable prometheus 2>/dev/null || true

    rm -f /etc/systemd/system/prometheus.service

    systemctl daemon-reload

    userdel prometheus 2>/dev/null || true

    rm -rf /opt/prometheus
    rm -rf /etc/prometheus
    rm -rf /var/lib/prometheus
    rm -rf /opt/prometheus-installer

    success "Prometheus removed."

    # ==========================================
    # Jenkins
    # ==========================================

    info "Removing Jenkins..."

    systemctl stop jenkins 2>/dev/null || true
    systemctl disable jenkins 2>/dev/null || true

    apt-get purge -y jenkins 2>/dev/null || true

    rm -rf /var/lib/jenkins
    rm -rf /etc/default/jenkins

    rm -f /etc/apt/sources.list.d/jenkins.list
    rm -f /etc/apt/keyrings/jenkins-keyring.asc

    success "Jenkins removed."

    # ==========================================
    # Kubernetes
    # ==========================================

    info "Removing Kubernetes..."

    # ------------------------------------------
    # Reset Cluster
    # ------------------------------------------

    if command_exists kubeadm; then

        info "Resetting Kubernetes cluster..."

        kubeadm reset -f || true

    else

        info "kubeadm not found. Skipping cluster reset."

    fi

    # ------------------------------------------
    # Stop Kubelet
    # ------------------------------------------

    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true

    # ------------------------------------------
    # Remove Kubernetes Packages
    # ------------------------------------------

    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true

    apt-get purge -y \
        kubelet \
        kubeadm \
        kubectl \
        2>/dev/null || true

    # ------------------------------------------
    # Remove Kubernetes Data
    # ------------------------------------------

    rm -rf /etc/kubernetes
    rm -rf /var/lib/kubelet
    rm -rf /etc/cni
    rm -rf /opt/cni
    rm -rf /var/lib/cni

    # ------------------------------------------
    # Remove kubeconfig
    # ------------------------------------------

    rm -rf /root/.kube
    rm -rf /home/*/.kube

    # ------------------------------------------
    # Remove Kubernetes Repository
    # ------------------------------------------

    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # ------------------------------------------
    # Remove Kubernetes Kernel Configuration
    # ------------------------------------------

    rm -f /etc/modules-load.d/k8s.conf
    rm -f /etc/sysctl.d/k8s.conf

    # ------------------------------------------
    # Remove Kubernetes systemd leftovers
    # ------------------------------------------

    rm -f /etc/systemd/system/kubelet.service
    rm -rf /etc/systemd/system/kubelet.service.d

    systemctl daemon-reload

    success "Kubernetes removed."

    # ==========================================
    # Docker
    # ==========================================

    info "Removing Docker..."

    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true

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

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc

    systemctl daemon-reload

    # ==========================================
    # Final Cleanup
    # ==========================================

    info "Running final package cleanup..."

    apt-get autoremove -y
    apt-get autoclean -y
    apt-get update

    # ------------------------------------------
    # Reload system configuration
    # ------------------------------------------

    sysctl --system >/dev/null 2>&1 || true

    # ------------------------------------------
    # Final Kubernetes verification
    # ------------------------------------------

    echo
    info "Performing final Kubernetes cleanup verification..."

    K8S_REMAINING=false

    if command -v kubeadm >/dev/null 2>&1; then
        K8S_REMAINING=true
    fi

    if command -v kubelet >/dev/null 2>&1; then
        K8S_REMAINING=true
    fi

    if command -v kubectl >/dev/null 2>&1; then
        K8S_REMAINING=true
    fi

    if [[ -d "/etc/kubernetes" ]]; then
        K8S_REMAINING=true
    fi

    if [[ -d "/var/lib/kubelet" ]]; then
        K8S_REMAINING=true
    fi

    if [[ -d "/etc/cni" ]]; then
        K8S_REMAINING=true
    fi

    if [[ -d "/var/lib/cni" ]]; then
        K8S_REMAINING=true
    fi

    if [[ "$K8S_REMAINING" == true ]]; then

        warning "Kubernetes leftovers detected."

    else

        success "Kubernetes completely removed."

    fi

    echo
    success "=========================================="
    success "COMPLETE DEVOPS REMOVAL FINISHED"
    success "=========================================="
}

# ==========================================
# Verify Uninstall
# ==========================================

verify_uninstall() {

    echo

    info "Verifying software removal..."

    local failures=0

    # ==========================================
    # Verify Docker
    # ==========================================

    if command_exists docker; then

        warning "Docker is still installed."
        ((failures+=1))

    else

        success "Docker removed."

    fi

# ==========================================
# Verify Kubernetes
# ==========================================

KUBERNETES_FOUND=false

# Check binaries
if command_exists kubeadm; then
    KUBERNETES_FOUND=true
fi

if command_exists kubelet; then
    KUBERNETES_FOUND=true
fi

if command_exists kubectl; then
    KUBERNETES_FOUND=true
fi

# Check installed packages only
if dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null |
    grep -qE '^ii[[:space:]]+(kubeadm|kubelet|kubectl)(:|[[:space:]])'; then

    KUBERNETES_FOUND=true
fi

# Check important Kubernetes directories
if [[ -d "/etc/kubernetes" ]]; then
    KUBERNETES_FOUND=true
fi

if [[ -d "/var/lib/kubelet" ]]; then
    KUBERNETES_FOUND=true
fi

# Final result
if [[ "$KUBERNETES_FOUND" == true ]]; then

    warning "Kubernetes components or configuration still exist."
    ((failures+=1))

else

    success "Kubernetes completely removed."

fi

    # ==========================================
    # Verify Jenkins
    # ==========================================

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^jenkins.service"; then

        warning "Jenkins service still exists."
        ((failures+=1))

    else

        success "Jenkins removed."

    fi

    # ==========================================
    # Verify Prometheus
    # ==========================================

    if [[ -x "/opt/prometheus/prometheus" ]]; then

        warning "Prometheus is still installed."
        ((failures+=1))

    else

        success "Prometheus removed."

    fi

    # ==========================================
    # Verify Grafana
    # ==========================================

    if command_exists grafana-server; then

        warning "Grafana is still installed."
        ((failures+=1))

    else

        success "Grafana removed."

    fi

    # ==========================================
    # Summary
    # ==========================================

    echo

    if [[ "$failures" -eq 0 ]]; then

        success "Uninstall verification completed successfully."

    else

        warning "Some components were not completely removed."

    fi
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

    while true
    do

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