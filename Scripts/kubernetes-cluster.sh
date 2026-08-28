#!/bin/bash

# ==========================================
# DevOps Auto Installer - Kubernetes Cluster
# ==========================================

set -e

# ==========================================
# Load Common Functions
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Variables
# ==========================================

KUBECONFIG_FILE="/etc/kubernetes/admin.conf"

# ==========================================
# Check Kubernetes Components
# ==========================================

check_kubernetes_components() {

    info "Checking Kubernetes components..."

    local missing=0

    for component in kubeadm kubelet kubectl
    do

        if command_exists "$component"; then

            success "$component is available."

        else

            error "$component is not installed."

            missing=1

        fi

    done

    if [[ "$missing" -ne 0 ]]; then

        error "Kubernetes components are missing."
        error "Run Kubernetes installation first."

        exit 1

    fi

    success "All Kubernetes components are available."
}

# ==========================================
# Detect Private IP
# ==========================================

detect_private_ip() {

    info "Detecting server private IP..."

    PRIVATE_IP="$(hostname -I | awk '{print $1}')"

    if [[ -z "$PRIVATE_IP" ]]; then

        error "Unable to determine server private IP."

        exit 1

    fi

    success "Server private IP detected: $PRIVATE_IP"

    log "[INFO] Kubernetes API advertise address: $PRIVATE_IP"
}

# ==========================================
# Check Existing Cluster
# ==========================================

check_existing_cluster() {

    info "Checking for existing Kubernetes cluster..."

    if [[ -f "$KUBECONFIG_FILE" ]]; then

        warning "Kubernetes control plane is already initialized."

        EXISTING_CLUSTER=true

        return 0

    fi

    EXISTING_CLUSTER=false

    info "No existing Kubernetes control plane detected."
}

# ==========================================
# Initialize Kubernetes Cluster
# ==========================================

initialize_cluster() {

    if [[ "$EXISTING_CLUSTER" == "true" ]]; then

        warning "Skipping kubeadm init because the cluster already exists."

        return 0

    fi

    info "Initializing Kubernetes control plane..."

    info "Pod Network CIDR: $POD_CIDR"

    kubeadm init \
        --apiserver-advertise-address="$PRIVATE_IP" \
        --pod-network-cidr="$POD_CIDR"

    success "Kubernetes control plane initialized."
}

# ==========================================
# Configure kubectl
# ==========================================

configure_kubectl() {

    info "Configuring kubectl access..."

    if [[ ! -f "$KUBECONFIG_FILE" ]]; then

        error "Kubernetes admin configuration not found:"
        error "$KUBECONFIG_FILE"

        exit 1

    fi

    # ------------------------------------------
    # Configure Root User
    # ------------------------------------------

    mkdir -p /root/.kube

    cp "$KUBECONFIG_FILE" /root/.kube/config

    chown root:root /root/.kube/config

    success "kubectl configured for root."

    # ------------------------------------------
    # Configure Original Sudo User
    # ------------------------------------------

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then

        USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

        if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then

            mkdir -p "$USER_HOME/.kube"

            cp "$KUBECONFIG_FILE" \
                "$USER_HOME/.kube/config"

            chown -R \
                "$SUDO_USER:$SUDO_USER" \
                "$USER_HOME/.kube"

            success "kubectl configured for user: $SUDO_USER"

        else

            warning "Unable to determine home directory for $SUDO_USER"

        fi

    else

        info "No non-root sudo user detected."

    fi

    export KUBECONFIG="$KUBECONFIG_FILE"

    success "kubectl configuration completed."
}

# ==========================================
# Verify Kubernetes API
# ==========================================

verify_api_server() {

    info "Checking Kubernetes API server..."

    local max_attempts=30

    for ((i=1; i<=max_attempts; i++))
    do

        if kubectl cluster-info >/dev/null 2>&1; then

            success "Kubernetes API server is responding."

            break

        fi

        info "Waiting for API server... Attempt $i/$max_attempts"

        sleep 5

    done

    if ! kubectl cluster-info >/dev/null 2>&1; then

        error "Kubernetes API server is not responding."

        kubectl cluster-info || true

        exit 1

    fi

    # Local port check
    if get_port_status "${KUBERNETES_API_PORT:-6443}" | grep -q "LISTENING"; then

        success "Kubernetes API port ${KUBERNETES_API_PORT:-6443} is listening locally."

    else

        warning "Kubernetes API port ${KUBERNETES_API_PORT:-6443} is not detected as listening."

    fi
}

# ==========================================
# Install Calico CNI
# ==========================================

install_cni() {

    info "Checking Kubernetes network plugin..."

    if kubectl get daemonset calico-node \
        -n kube-system >/dev/null 2>&1
    then

        success "Calico is already installed."

        return 0

    fi

    info "Installing Calico version $CALICO_VERSION..."

    kubectl apply -f \
        "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml"

    success "Calico network plugin installed."
}

# ==========================================
# Wait for Calico
# ==========================================

wait_for_calico() {

    info "Waiting for Calico components..."

    local max_attempts=30

    for ((i=1; i<=max_attempts; i++))
    do

        if kubectl get daemonset calico-node \
            -n kube-system \
            --no-headers 2>/dev/null |
            awk '{if ($2 == $3 && $2 > 0) exit 0; else exit 1}'
        then

            success "Calico DaemonSet is ready."

            return 0

        fi

        info "Calico is not ready yet. Waiting 10 seconds... ($i/$max_attempts)"

        sleep 10

    done

    warning "Calico did not become ready within the expected time."

    kubectl get pods -n kube-system | grep -i calico || true
}

# ==========================================
# Wait for Node
# ==========================================

wait_for_node() {

    info "Waiting for Kubernetes node to become Ready..."

    local max_attempts=30

    for ((i=1; i<=max_attempts; i++))
    do

        if kubectl get nodes --no-headers 2>/dev/null | \
            awk '$2 == "Ready" { found=1 } END { exit !found }'
        then

            success "Kubernetes node is Ready."

            return 0

        fi

        info "Node is not Ready yet. Waiting 10 seconds... ($i/$max_attempts)"

        sleep 10

    done

    warning "Node did not become Ready within 300 seconds."

    kubectl get nodes -o wide || true

    kubectl get pods -A || true
}

# ==========================================
# Verify Control Plane Components
# ==========================================

verify_control_plane() {

    info "Checking Kubernetes control plane components..."

    local components=(
        kube-apiserver
        kube-controller-manager
        kube-scheduler
    )

    for component in "${components[@]}"
    do

        if kubectl get pods \
            -n kube-system \
            --no-headers 2>/dev/null |
            grep -q "$component"
        then

            success "$component detected."

        else

            warning "$component not detected."

        fi

    done
}

# ==========================================
# Verify Cluster
# ==========================================

verify_cluster() {

    echo

    echo "=========================================="
    echo "       KUBERNETES CLUSTER STATUS"
    echo "=========================================="

    echo

    info "Kubernetes Nodes:"

    kubectl get nodes -o wide || true

    echo

    info "Kubernetes System Pods:"

    kubectl get pods -A || true

    echo

    if kubectl get nodes --no-headers 2>/dev/null | \
        awk '$2 == "Ready" { found=1 } END { exit !found }'
    then

        success "Kubernetes cluster is operational."

    else

        warning "Kubernetes cluster is initialized but the node is not Ready."

    fi
}

# ==========================================
# Display Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "     KUBERNETES CLUSTER INSTALLATION"
    echo "=========================================="

    echo "API Address : $PRIVATE_IP"
    echo "API Port    : ${KUBERNETES_API_PORT:-6443}"
    echo "Pod CIDR    : $POD_CIDR"
    echo "CNI         : Calico v$CALICO_VERSION"

    echo

    echo "Node Status:"

    kubectl get nodes --no-headers 2>/dev/null || true

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
    echo "      KUBERNETES CLUSTER SETUP"
    echo "=========================================="

    echo

    info "Starting Kubernetes cluster setup..."

    check_kubernetes_components

    detect_private_ip

    check_existing_cluster

    initialize_cluster

    configure_kubectl

    verify_api_server

    install_cni

    wait_for_calico

    wait_for_node

    verify_control_plane

    verify_cluster

    show_summary

    log "[SUCCESS] Kubernetes cluster setup completed successfully."

    echo

    success "=========================================="
    success "KUBERNETES CLUSTER SETUP COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Start
# ==========================================

main