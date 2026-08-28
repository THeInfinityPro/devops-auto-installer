#!/bin/bash

# ==========================================
# DevOps Auto Installer - Kubernetes
# ==========================================

set -e

# ==========================================
# Load Common Functions
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check Supported OS
# ==========================================

check_supported_os() {

    info "Checking operating system compatibility..."

    if [[ "$OS_NAME" != "ubuntu" ]]; then

        error "Kubernetes installer currently supports Ubuntu only."
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
# Check Existing Installation
# ==========================================

check_existing_kubernetes() {

    info "Checking existing Kubernetes installation..."

    local installed=0

    for component in kubeadm kubelet kubectl
    do

        if command_exists "$component"; then

            success "$component is already installed."

            installed=$((installed + 1))

        else

            info "$component is not installed."

        fi

    done

    if [[ "$installed" -eq 3 ]]; then

        success "All Kubernetes components are already installed."

        return 0

    fi

    return 1
}

# ==========================================
# Disable Swap
# ==========================================

configure_swap() {

    info "Checking swap configuration..."

    if swapon --show | grep -q .; then

        warning "Swap is enabled. Disabling swap..."

        swapoff -a

        if grep -qE '^[^#].*\sswap\s' /etc/fstab; then

            cp /etc/fstab /etc/fstab.k8s-backup

            sed -i -E \
                's/^([^#].*\sswap\s.*)$/#\1/' \
                /etc/fstab

        fi

        success "Swap disabled."

    else

        success "Swap is already disabled."

    fi
}

# ==========================================
# Configure Kernel Modules
# ==========================================

configure_kernel() {

    info "Configuring Kubernetes kernel modules..."

    cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    success "Kernel modules configured."

    info "Loaded modules:"

    lsmod | grep -E "overlay|br_netfilter" || true
}

# ==========================================
# Configure Sysctl
# ==========================================

configure_sysctl() {

    info "Configuring Kubernetes network settings..."

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

    sysctl --system >/dev/null

    success "Kernel network settings configured."

    info "Verifying required sysctl settings..."

    sysctl \
        net.bridge.bridge-nf-call-iptables \
        net.bridge.bridge-nf-call-ip6tables \
        net.ipv4.ip_forward
}

# ==========================================
# Configure Containerd
# ==========================================

configure_containerd() {

    info "Configuring containerd for Kubernetes..."

    if ! command_exists containerd; then

        error "containerd is not installed."
        error "Install Docker before installing Kubernetes."

        exit 1

    fi

    info "Containerd version: $(containerd --version)"

    systemctl stop containerd 2>/dev/null || true

    mkdir -p /etc/containerd

    # Backup existing configuration
    if [[ -f /etc/containerd/config.toml ]]; then

        BACKUP_FILE="/etc/containerd/config.toml.backup.$(date +%Y%m%d-%H%M%S)"

        cp \
            /etc/containerd/config.toml \
            "$BACKUP_FILE"

        info "Existing containerd configuration backed up."

    fi

    # Generate clean configuration
    info "Generating containerd configuration..."

    containerd config default > /etc/containerd/config.toml

    # Enable systemd cgroups
    sed -i \
        's/SystemdCgroup = false/SystemdCgroup = true/' \
        /etc/containerd/config.toml

    # Ensure CRI plugin is enabled
    sed -i \
        '/disabled_plugins.*cri/d' \
        /etc/containerd/config.toml

    systemctl daemon-reload

    systemctl enable containerd

    systemctl restart containerd

    info "Waiting for containerd service..."

    local started=false

    for i in {1..12}
    do

        if systemctl is-active --quiet containerd; then

            started=true
            break

        fi

        sleep 5

    done

    if [[ "$started" == "true" ]]; then

        success "Containerd service is running."

    else

        error "Containerd failed to start."

        systemctl status containerd --no-pager || true

        exit 1

    fi
}

# ==========================================
# Verify Containerd CRI Support
# ==========================================

verify_containerd_cri() {

    info "Verifying containerd CRI support..."

    if ctr plugins ls 2>/dev/null | \
        awk '$1 ~ /cri/ && $NF == "ok" { found=1 } END { exit !found }'
    then

        success "Containerd CRI plugin is available."

    else

        error "Containerd CRI plugin is not available."

        info "CRI plugin status:"

        ctr plugins ls 2>/dev/null | grep -i cri || true

        exit 1

    fi
}

# ==========================================
# Configure Kubernetes Repository
# ==========================================

configure_kubernetes_repository() {

    info "Configuring Kubernetes v${KUBERNETES_MINOR_VERSION} repository..."

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl \
        gpg

    mkdir -p -m 755 /etc/apt/keyrings

    # Download repository key
    curl -fsSL \
        "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR_VERSION}/deb/Release.key" |
        gpg --dearmor \
        --yes \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Configure repository
    echo \
        "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR_VERSION}/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list

    apt-get update

    success "Kubernetes repository configured."
}

# ==========================================
# Install Kubernetes Components
# ==========================================

install_kubernetes() {

    info "Installing Kubernetes components..."

    apt-get install -y \
        kubelet \
        kubeadm \
        kubectl

    apt-mark hold \
        kubelet \
        kubeadm \
        kubectl

    success "Kubernetes components installed."

    success "kubeadm, kubelet and kubectl are held from automatic upgrades."
}

# ==========================================
# Enable Kubelet
# ==========================================

enable_kubelet() {

    info "Enabling kubelet service..."

    systemctl enable kubelet

    success "Kubelet service enabled."

    info "Note: kubelet may restart or remain inactive until kubeadm init is completed."
}

# ==========================================
# Verify Kubernetes
# ==========================================

verify_kubernetes() {

    echo

    info "Verifying Kubernetes installation..."

    local failed=0

    for component in kubeadm kubelet kubectl
    do

        if command_exists "$component"; then

            success "$component command found."

        else

            error "$component command was not found."

            failed=1

        fi

    done

    if [[ "$failed" -ne 0 ]]; then

        exit 1

    fi

    echo

    echo "Kubernetes Versions:"

    echo

    kubeadm version

    kubectl version --client

    kubelet --version

    echo

    success "Kubernetes components verified."
}

# ==========================================
# Display Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "       KUBERNETES INSTALLATION SUMMARY"
    echo "=========================================="

    echo "Kubelet Service : $(get_service_status kubelet)"

    echo

    if command_exists kubeadm; then

        echo "kubeadm Version  : $(kubeadm version -o short 2>/dev/null || echo "Unknown")"

    fi

    if command_exists kubectl; then

        echo "kubectl Version  : $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1 | awk '{print $2}' || echo "Installed")"

    fi

    echo "Containerd       : $(get_service_status containerd)"

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
    echo "       KUBERNETES COMPONENT INSTALLER"
    echo "=========================================="

    echo

    info "Starting Kubernetes installation..."

    check_supported_os

    # Configure system requirements
    configure_swap

    configure_kernel

    configure_sysctl

    # Configure container runtime
    configure_containerd

    verify_containerd_cri

    # Check existing installation
    if check_existing_kubernetes; then

        info "Kubernetes components are already installed."

        verify_kubernetes

        show_summary

        log "[SUCCESS] Existing Kubernetes installation verified."

        return 0

    fi

    # Configure repository
    configure_kubernetes_repository

    # Install components
    install_kubernetes

    # Enable kubelet
    enable_kubelet

    # Verify
    verify_kubernetes

    # Summary
    show_summary

    log "[SUCCESS] Kubernetes installation completed successfully."

    echo

    success "=========================================="
    success "KUBERNETES INSTALLATION COMPLETED"
    success "=========================================="

    echo

    info "Next step:"
    info "Run Kubernetes Cluster Setup from the main menu."
}

main