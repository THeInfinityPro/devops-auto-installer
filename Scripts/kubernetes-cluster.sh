    #!/bin/bash

    # ==========================================
    # DevOps Auto Installer - Kubernetes Cluster
    # ==========================================

    set -e

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

        for command in kubeadm kubelet kubectl; do

            if ! command -v "$command" >/dev/null 2>&1; then
                error "$command is not installed."
                error "Run Kubernetes installation first."
                exit 1
            fi

        done

        success "Kubernetes components are available."
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

        success "Server private IP: $PRIVATE_IP"
    }

    # ==========================================
    # Check Existing Cluster
    # ==========================================

    check_existing_cluster() {

        if [[ -f "$KUBECONFIG_FILE" ]]; then

            warning "Kubernetes control plane is already initialized."

            return 0

        fi

        info "No existing Kubernetes control plane detected."
    }

    # ==========================================
    # Initialize Kubernetes
    # ==========================================

    initialize_cluster() {

        if [[ -f "$KUBECONFIG_FILE" ]]; then

            warning "Skipping kubeadm init because the cluster already exists."

            return 0

        fi

        info "Initializing Kubernetes control plane..."

        kubeadm init \
            --apiserver-advertise-address="$PRIVATE_IP" \
            --pod-network-cidr="$POD_CIDR"

        success "Kubernetes control plane initialized."
    }

    # ==========================================
    # Configure kubectl
    # ==========================================

    configure_kubectl() {

    info "Configuring kubectl..."

    if [[ ! -f "$KUBECONFIG_FILE" ]]; then
        error "Kubernetes admin configuration not found: $KUBECONFIG_FILE"
        exit 1
    fi

    # Configure root
    mkdir -p /root/.kube
    cp "$KUBECONFIG_FILE" /root/.kube/config
    chown root:root /root/.kube/config

    # Configure the original sudo user
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then

        USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

        mkdir -p "$USER_HOME/.kube"

        cp "$KUBECONFIG_FILE" "$USER_HOME/.kube/config"

        chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.kube"

        success "kubectl configured for user: $SUDO_USER"

    fi

    success "kubectl configuration completed."
}

    # ==========================================
    # Install Calico CNI
    # ==========================================

    install_cni() {

        info "Installing Kubernetes network plugin..."

        if kubectl get daemonset calico-node \
            -n kube-system >/dev/null 2>&1; then

            warning "Calico appears to be already installed."

            return 0

        fi

        kubectl apply -f \
            https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml

        success "Calico network plugin installed."
    }

    # ==========================================
    # Wait for Node
    # ==========================================

    wait_for_node() {

    info "Waiting for Kubernetes node to become Ready..."

    for i in {1..30}; do

        if kubectl get nodes --no-headers 2>/dev/null | \
            grep -qE '[[:space:]]Ready[[:space:]]'; then

            success "Kubernetes node is Ready."
            return 0

        fi

        info "Node is not ready yet. Waiting 10 seconds..."
        sleep 10

    done

    warning "Node did not become Ready within 300 seconds."

    kubectl get nodes -o wide || true
}

    # ==========================================
    # Verify Cluster
    # ==========================================

    verify_cluster() {

        echo

        info "Kubernetes nodes:"

        kubectl get nodes -o wide

        echo

        info "Kubernetes system pods:"

        kubectl get pods -A

        echo

        if kubectl get nodes 2>/dev/null | grep -q " Ready "; then

            success "Kubernetes cluster is operational."

        else

            warning "Kubernetes cluster is initialized but the node is not Ready."

        fi
    }

    # ==========================================
    # Main
    # ==========================================

    main() {

        initialize

        info "Starting Kubernetes cluster setup..."

        check_kubernetes_components

        detect_private_ip

        check_existing_cluster

        initialize_cluster

        configure_kubectl

        install_cni

        wait_for_node

        verify_cluster

        log "Kubernetes cluster setup completed."

        echo
        success "=========================================="
        success "Kubernetes cluster setup completed."
        success "=========================================="
    }

    # ==========================================
    # Start
    # ==========================================

    main