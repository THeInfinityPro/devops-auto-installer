#!/bin/bash

# ==========================================
# DevOps Auto Installer - Health Verification
# ==========================================

set -u

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Counters
# ==========================================

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ==========================================
# Result Functions
# ==========================================

check_pass() {

    echo -e "${GREEN}[PASS]${NC} $1"
    log "[PASS] $1"

    ((PASS_COUNT+=1))
}

check_fail() {

    echo -e "${RED}[FAIL]${NC} $1"
    log "[FAIL] $1"

    ((FAIL_COUNT+=1))
}

check_warning() {

    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "[WARNING] $1"

    ((WARN_COUNT+=1))
}

# ==========================================
# Header
# ==========================================

show_verification_header() {

    clear

    echo
    echo "=========================================="
    echo "       DEVOPS HEALTH CHECK"
    echo "=========================================="
    echo
}

# ==========================================
# Docker
# ==========================================

verify_docker() {

    echo
    info "Checking Docker..."

    # ------------------------------------------
    # Docker Binary
    # ------------------------------------------

    if command_exists docker; then

        DOCKER_VERSION="$(docker --version 2>/dev/null || true)"

        check_pass "Docker installed: $DOCKER_VERSION"

    else

        check_fail "Docker is not installed."
        return

    fi

    # ------------------------------------------
    # Docker Service
    # ------------------------------------------

    if systemctl is-active --quiet docker; then

        check_pass "Docker service is running."

    else

        check_fail "Docker service is not running."

    fi

    # ------------------------------------------
    # Docker Engine
    # ------------------------------------------

    if docker info >/dev/null 2>&1; then

        check_pass "Docker engine is responding."

    else

        check_fail "Docker engine is not responding."

    fi

    # ------------------------------------------
    # Docker Compose
    # ------------------------------------------

    if docker compose version >/dev/null 2>&1; then

        COMPOSE_VERSION="$(docker compose version 2>/dev/null)"

        check_pass "Docker Compose available: $COMPOSE_VERSION"

    else

        check_warning "Docker Compose is not available."

    fi

    # ------------------------------------------
    # Containerd
    # ------------------------------------------

    if command_exists containerd; then

        CONTAINERD_VERSION="$(containerd --version 2>/dev/null || true)"

        check_pass "Containerd installed: $CONTAINERD_VERSION"

    else

        check_warning "Containerd command not found."

    fi
}

# ==========================================
# Kubernetes Components
# ==========================================

verify_kubernetes_components() {

    echo
    info "Checking Kubernetes components..."

    # ------------------------------------------
    # kubeadm
    # ------------------------------------------

    if command_exists kubeadm; then

        KUBEADM_VERSION="$(kubeadm version -o short 2>/dev/null || true)"

        check_pass "kubeadm installed: $KUBEADM_VERSION"

    else

        check_fail "kubeadm is not installed."

    fi

    # ------------------------------------------
    # kubelet
    # ------------------------------------------

    if command_exists kubelet; then

        KUBELET_VERSION="$(kubelet --version 2>/dev/null || true)"

        check_pass "kubelet installed: $KUBELET_VERSION"

    else

        check_fail "kubelet is not installed."

    fi

    # ------------------------------------------
    # kubectl
    # ------------------------------------------

    if command_exists kubectl; then

        KUBECTL_VERSION="$(
            kubectl version \
                --client \
                --output=yaml 2>/dev/null |
                grep "gitVersion" |
                head -1 ||
                true
        )"

        if [[ -n "$KUBECTL_VERSION" ]]; then

            check_pass "kubectl installed: $KUBECTL_VERSION"

        else

            check_pass "kubectl installed."

        fi

    else

        check_fail "kubectl is not installed."

    fi

    # ------------------------------------------
    # Kubelet Service
    # ------------------------------------------

    if systemctl is-enabled --quiet kubelet 2>/dev/null; then

        if systemctl is-active --quiet kubelet; then

            check_pass "Kubelet service is running."

        else

            check_warning "Kubelet is enabled but not currently running."

        fi

    else

        check_warning "Kubelet service is not enabled."

    fi
}

# ==========================================
# Kubernetes Cluster
# ==========================================

verify_kubernetes_cluster() {

    echo
    info "Checking Kubernetes cluster..."

    # ------------------------------------------
    # Check kubeconfig
    # ------------------------------------------

    if [[ ! -f "/etc/kubernetes/admin.conf" ]]; then

        if [[ -z "${KUBECONFIG:-}" ]]; then

            check_warning \
                "Kubernetes cluster is not initialized or admin.conf is missing."

            return

        fi

    fi

    # ------------------------------------------
    # Configure temporary kubeconfig
    # ------------------------------------------

    local KUBE_CONFIG=""

    if [[ -f "/etc/kubernetes/admin.conf" ]]; then

        KUBE_CONFIG="/etc/kubernetes/admin.conf"

    elif [[ -n "${KUBECONFIG:-}" ]] &&
         [[ -f "$KUBECONFIG" ]]; then

        KUBE_CONFIG="$KUBECONFIG"

    elif [[ -f "$HOME/.kube/config" ]]; then

        KUBE_CONFIG="$HOME/.kube/config"

    else

        check_warning "No Kubernetes kubeconfig was found."
        return

    fi

    # ------------------------------------------
    # API Server
    # ------------------------------------------

    if kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        cluster-info >/dev/null 2>&1; then

        check_pass "Kubernetes API server is reachable."

    else

        check_fail "Kubernetes API server is not reachable."
        return

    fi

    # ------------------------------------------
    # Current Context
    # ------------------------------------------

    local CURRENT_CONTEXT

    CURRENT_CONTEXT="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            config current-context 2>/dev/null ||
            true
    )"

    if [[ -n "$CURRENT_CONTEXT" ]]; then

        check_pass "Kubernetes context: $CURRENT_CONTEXT"

    else

        check_warning "Kubernetes current context is not set."

    fi

    # ------------------------------------------
    # Node Status
    # ------------------------------------------

    local NODE_STATUS

    NODE_STATUS="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get nodes \
            --no-headers 2>/dev/null ||
            true
    )"

    if [[ -z "$NODE_STATUS" ]]; then

        check_fail "No Kubernetes nodes were found."
        return

    fi

    if echo "$NODE_STATUS" |
        awk '{print $2}' |
        grep -q "^Ready$"; then

        check_pass "Kubernetes node is Ready."

    else

        check_warning "Kubernetes node exists but is not Ready."

    fi

    # ------------------------------------------
    # Display Nodes
    # ------------------------------------------

    echo
    info "Kubernetes nodes:"

    kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        get nodes -o wide 2>/dev/null ||
        true

    # ------------------------------------------
    # System Pods
    # ------------------------------------------

    local POD_COUNT
    local NOT_RUNNING_PODS

    POD_COUNT="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get pods -A \
            --no-headers 2>/dev/null |
            wc -l
    )"

    if [[ "$POD_COUNT" -gt 0 ]]; then

        check_pass "Kubernetes system pods detected: $POD_COUNT"

    else

        check_warning "No Kubernetes pods were detected."

    fi

    NOT_RUNNING_PODS="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get pods -A \
            --no-headers 2>/dev/null |
            awk '$4 != "Running" && $4 != "Completed" {print}'
    )"

    if [[ -z "$NOT_RUNNING_PODS" ]]; then

        check_pass "Kubernetes system pods are healthy."

    else

        check_warning "Some Kubernetes pods are not Running or Completed."

        echo "$NOT_RUNNING_PODS"
    fi
}

# ==========================================
# Jenkins
# ==========================================

verify_jenkins() {

    echo
    info "Checking Jenkins..."

    # ------------------------------------------
    # Java
    # ------------------------------------------

    if command_exists java; then

        JAVA_VERSION="$(java -version 2>&1 | head -1)"

        check_pass "Java installed: $JAVA_VERSION"

    else

        check_fail "Java is not installed."

    fi

    # ------------------------------------------
    # Jenkins Service
    # ------------------------------------------

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^jenkins.service"; then

        if systemctl is-active --quiet jenkins; then

            check_pass "Jenkins service is running."

        else

            check_fail "Jenkins service is installed but not running."

        fi

    else

        check_fail "Jenkins service is not installed."
        return

    fi

    # ------------------------------------------
    # Jenkins HTTP
    # ------------------------------------------

    if curl -fsS \
        --max-time 5 \
        http://127.0.0.1:${JENKINS_PORT}/login \
        >/dev/null 2>&1; then

        check_pass "Jenkins HTTP endpoint is responding."

    else

        check_warning "Jenkins HTTP endpoint is not responding."

    fi
}

# ==========================================
# Prometheus
# ==========================================

verify_prometheus() {

    echo
    info "Checking Prometheus..."

    # ------------------------------------------
    # Binary
    # ------------------------------------------

    if [[ -x "/opt/prometheus/prometheus" ]]; then

        PROM_VERSION="$(
            /opt/prometheus/prometheus \
                --version 2>/dev/null |
                head -1
        )"

        check_pass "Prometheus installed: $PROM_VERSION"

    else

        check_fail "Prometheus binary is not installed."
        return

    fi

    # ------------------------------------------
    # Service
    # ------------------------------------------

    if systemctl is-active --quiet prometheus 2>/dev/null; then

        check_pass "Prometheus service is running."

    else

        check_fail "Prometheus service is not running."
        return

    fi

    # ------------------------------------------
    # HTTP Endpoint
    # ------------------------------------------

    info "Checking Prometheus HTTP endpoint..."

    if curl -fsS \
        --max-time 5 \
        http://127.0.0.1:${PROMETHEUS_PORT}/-/ready \
        >/dev/null 2>&1; then

        check_pass "Prometheus HTTP endpoint is responding."

    else

        check_warning "Prometheus HTTP endpoint is not responding."

    fi

    # ------------------------------------------
    # API Health
    # ------------------------------------------

    if curl -fsS \
        --max-time 5 \
        http://127.0.0.1:${PROMETHEUS_PORT}/api/v1/status/buildinfo \
        >/dev/null 2>&1; then

        check_pass "Prometheus API is healthy."

    else

        check_warning "Prometheus API health check failed."

    fi
}

# ==========================================
# Grafana
# ==========================================

verify_grafana() {

    echo
    info "Checking Grafana..."

    # ------------------------------------------
    # Binary
    # ------------------------------------------

    if command_exists grafana-server; then

        GRAFANA_VERSION="$(
            grafana-server -v 2>/dev/null
        )"

        check_pass "Grafana installed: $GRAFANA_VERSION"

    else

        check_fail "Grafana is not installed."
        return

    fi

    # ------------------------------------------
    # Service
    # ------------------------------------------

    if systemctl is-active --quiet grafana-server 2>/dev/null; then

        check_pass "Grafana service is running."

    else

        check_fail "Grafana service is not running."
        return

    fi

    # ------------------------------------------
    # HTTP Endpoint
    # ------------------------------------------

    info "Checking Grafana HTTP endpoint..."

    if curl -fsS \
        --max-time 5 \
        http://127.0.0.1:${GRAFANA_PORT}/api/health \
        >/dev/null 2>&1; then

        check_pass "Grafana HTTP endpoint is responding."

    else

        check_warning "Grafana HTTP endpoint is not responding."

    fi

    # ------------------------------------------
    # Grafana API Health
    # ------------------------------------------

    local GRAFANA_HEALTH

    GRAFANA_HEALTH="$(
        curl -fsS \
            --max-time 5 \
            http://127.0.0.1:${GRAFANA_PORT}/api/health \
            2>/dev/null ||
            true
    )"

    if echo "$GRAFANA_HEALTH" |
        grep -q '"database": "ok"'; then

        check_pass "Grafana database health is OK."

    elif [[ -n "$GRAFANA_HEALTH" ]]; then

        check_warning "Grafana responded but database health could not be confirmed."

    fi
}

# ==========================================
# Summary
# ==========================================

show_summary() {

    echo
    echo "=========================================="
    echo "          HEALTH CHECK SUMMARY"
    echo "=========================================="
    echo

    echo -e "${GREEN}PASS : $PASS_COUNT${NC}"
    echo -e "${YELLOW}WARN : $WARN_COUNT${NC}"
    echo -e "${RED}FAIL : $FAIL_COUNT${NC}"

    echo
    echo "=========================================="

    if [[ "$FAIL_COUNT" -eq 0 ]]; then

        success "Health verification completed successfully."

    else

        error "Health verification completed with failures."

    fi

    echo "=========================================="
    echo
}

# ==========================================
# Main
# ==========================================

main() {

    initialize

    show_verification_header

    verify_docker

    verify_kubernetes_components

    verify_kubernetes_cluster

    verify_jenkins

    verify_prometheus

    verify_grafana

    show_summary

    log "DevOps health verification completed."
}

# ==========================================
# Start
# ==========================================

main