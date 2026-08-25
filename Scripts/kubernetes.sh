#!/bin/bash

# ==========================================
# DevOps Auto Installer - Kubernetes
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check Supported OS
# ==========================================

check_supported_os() {

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "Kubernetes installer currently supports Ubuntu only."
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
# Disable Swap
# ==========================================

configure_swap() {

    info "Checking swap configuration..."

    if swapon --show | grep -q .; then

        warning "Swap is enabled."

        swapoff -a

        if grep -qE '^[^#].*\sswap\s' /etc/fstab; then
            sed -i -E 's/^([^#].*\sswap\s.*)$/#\1/' /etc/fstab
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
}

# ==========================================
# Configure Containerd
# ==========================================

configure_containerd() {

    info "Configuring containerd for Kubernetes..."

    if ! command_exists containerd; then
        error "containerd is not installed."
        error "Install Docker/containerd before installing Kubernetes."
        exit 1
    fi

    info "Containerd version: $(containerd --version)"

    systemctl stop containerd 2>/dev/null || true

    mkdir -p /etc/containerd

    # Backup existing configuration
    if [[ -f /etc/containerd/config.toml ]]; then
        cp \
            /etc/containerd/config.toml \
            /etc/containerd/config.toml.backup
    fi

    # Generate clean containerd configuration
    containerd config default > /etc/containerd/config.toml

    # Enable systemd cgroups for Kubernetes
    sed -i \
        's/SystemdCgroup = false/SystemdCgroup = true/' \
        /etc/containerd/config.toml

    # Ensure CRI plugin is not disabled
    sed -i \
        '/disabled_plugins.*cri/d' \
        /etc/containerd/config.toml

    systemctl daemon-reload
    systemctl restart containerd
    systemctl enable containerd

    # Wait for containerd
    info "Waiting for containerd to start..."

    for i in {1..6}; do

        if systemctl is-active --quiet containerd; then
            success "Containerd service is running."
            break
        fi

        sleep 5
    done

    if ! systemctl is-active --quiet containerd; then
        error "Containerd failed to start."
        systemctl status containerd --no-pager
        exit 1
    fi

  # ==========================================
# Verify Containerd CRI Support
# ==========================================

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
# Install Kubernetes Repository
# ==========================================

configure_kubernetes_repository() {

    info "Configuring Kubernetes v${KUBERNETES_MINOR_VERSION} repository..."

    apt-get update

    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg

    mkdir -p -m 755 /etc/apt/keyrings

    curl -fsSL \
        "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR_VERSION}/deb/Release.key" |
        gpg --dearmor \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

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

    apt-get install -y kubelet kubeadm kubectl

    apt-mark hold kubelet kubeadm kubectl

    success "kubelet, kubeadm and kubectl installed."
}

# ==========================================
# Enable Kubelet
# ==========================================

enable_kubelet() {

    info "Enabling kubelet..."

    systemctl enable kubelet

    success "Kubelet service enabled."

    info "Note: kubelet may not remain active until the Kubernetes cluster is initialized."
}



# ==========================================
# Verify Kubernetes
# ==========================================

verify_kubernetes() {

    echo

    info "Verifying Kubernetes installation..."

    if ! command_exists kubeadm; then
        error "kubeadm was not found."
        exit 1
    fi

    if ! command_exists kubelet; then
        error "kubelet was not found."
        exit 1
    fi

    if ! command_exists kubectl; then
        error "kubectl was not found."
        exit 1
    fi

    echo
    kubeadm version
    kubectl version --client
    kubelet --version

    echo

    success "Kubernetes components verified."

    info "Kubernetes cluster has NOT been initialized."
    info "Run the cluster initialization phase separately."
}



# ==========================================
# Main
# ==========================================

main() {

    initialize

    info "Starting Kubernetes installation..."

    check_supported_os

    configure_swap

    configure_kernel

    configure_sysctl

    configure_containerd

    configure_kubernetes_repository

    install_kubernetes

    enable_kubelet

    verify_kubernetes

    log "Kubernetes installation completed."

    echo
    success "=========================================="
    success "Kubernetes installation completed."
    success "=========================================="
}

main