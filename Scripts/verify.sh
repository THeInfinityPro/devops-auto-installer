#!/bin/bash

# ==========================================
# DevOps Auto Installer - Installation Verify
# ==========================================

set -u

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Default Ports
# ==========================================

JENKINS_PORT="${JENKINS_PORT:-8080}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
KUBERNETES_API_PORT="${KUBERNETES_API_PORT:-6443}"

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

    echo -e "${GREEN:-}[PASS]${NC:-} $1"
    log "[PASS] $1"

    ((PASS_COUNT+=1))
}

check_fail() {

    echo -e "${RED:-}[FAIL]${NC:-} $1"
    log "[FAIL] $1"

    ((FAIL_COUNT+=1))
}

check_warning() {

    echo -e "${YELLOW:-}[WARNING]${NC:-} $1"
    log "[WARNING] $1"

    ((WARN_COUNT+=1))
}

# ==========================================
# Check Port
# ==========================================

check_port() {

    local PORT="$1"
    local SERVICE="$2"

    if ss -ltn 2>/dev/null | grep -qE ":${PORT}[[:space:]]"; then

        check_pass "$SERVICE port $PORT is listening locally."
        return 0

    else

        check_warning "$SERVICE port $PORT is not listening locally."
        return 1

    fi
}

# ==========================================
# Check Service
# ==========================================

check_service_status() {

    local SERVICE="$1"
    local DISPLAY_NAME="$2"

    if ! systemctl list-unit-files 2>/dev/null |
        grep -q "^${SERVICE}\.service"; then

        check_warning "$DISPLAY_NAME service is not installed."
        return 1

    fi

    if systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then

        check_pass "$DISPLAY_NAME service is enabled."

    else

        check_warning "$DISPLAY_NAME service is not enabled."

    fi

    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

        check_pass "$DISPLAY_NAME service is running."
        return 0

    else

        check_fail "$DISPLAY_NAME service is not running."
        return 1

    fi
}

# ==========================================
# Header
# ==========================================

show_verification_header() {

    clear

    echo
    echo "=========================================="
    echo "       DEVOPS INSTALLATION VERIFY"
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

    check_service_status "docker" "Docker" || true

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

    # ------------------------------------------
    # Containerd Service
    # ------------------------------------------

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^containerd.service"; then

        if systemctl is-active --quiet containerd; then

            check_pass "Containerd service is running."

        else

            check_warning "Containerd service is not running."

        fi

    fi
}

# ==========================================
# Kubernetes Components
# ==========================================

verify_kubernetes_components() {

    echo
    info "Checking Kubernetes components..."

    local COMPONENTS_FOUND=0

    # ------------------------------------------
    # kubeadm
    # ------------------------------------------

    if command_exists kubeadm; then

        COMPONENTS_FOUND=1

        KUBEADM_VERSION="$(kubeadm version -o short 2>/dev/null || true)"

        check_pass "kubeadm installed: $KUBEADM_VERSION"

    else

        check_warning "kubeadm is not installed."

    fi

    # ------------------------------------------
    # kubelet
    # ------------------------------------------

    if command_exists kubelet; then

        COMPONENTS_FOUND=1

        KUBELET_VERSION="$(kubelet --version 2>/dev/null || true)"

        check_pass "kubelet installed: $KUBELET_VERSION"

    else

        check_warning "kubelet is not installed."

    fi

    # ------------------------------------------
    # kubectl
    # ------------------------------------------

    if command_exists kubectl; then

        COMPONENTS_FOUND=1

        KUBECTL_VERSION="$(
            kubectl version --client --short 2>/dev/null ||
            kubectl version --client 2>/dev/null |
            head -1 ||
            true
        )"

        check_pass "kubectl installed: $KUBECTL_VERSION"

    else

        check_warning "kubectl is not installed."

    fi

    # ------------------------------------------
    # No Kubernetes Components
    # ------------------------------------------

    if [[ "$COMPONENTS_FOUND" -eq 0 ]]; then

        check_warning "Kubernetes components are not installed."
        return

    fi

    # ------------------------------------------
    # Kubelet Service
    # ------------------------------------------

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^kubelet.service"; then

        if systemctl is-enabled --quiet kubelet 2>/dev/null; then

            check_pass "Kubelet service is enabled."

        else

            check_warning "Kubelet service is not enabled."

        fi

        if systemctl is-active --quiet kubelet 2>/dev/null; then

            check_pass "Kubelet service is running."

        else

            check_warning "Kubelet service is not running."

        fi

    else

        check_warning "Kubelet service is not installed."

    fi
}

# ==========================================
# Kubernetes Cluster
# ==========================================

verify_kubernetes_cluster() {

    echo
    info "Checking Kubernetes cluster..."

    # ------------------------------------------
    # kubectl Required
    # ------------------------------------------

    if ! command_exists kubectl; then

        check_warning "kubectl is not installed. Skipping cluster verification."
        return

    fi

    # ------------------------------------------
    # Locate kubeconfig
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

        check_warning "Kubernetes cluster is not initialized or kubeconfig was not found."
        return

    fi

    check_pass "Kubernetes kubeconfig found: $KUBE_CONFIG"

    # ------------------------------------------
    # Kubernetes API Port
    # ------------------------------------------

    check_port \
        "$KUBERNETES_API_PORT" \
        "Kubernetes API"

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

    local CURRENT_CONTEXT=""

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
    # Nodes
    # ------------------------------------------

    local NODE_STATUS=""

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

    local READY_NODES

    READY_NODES="$(
        echo "$NODE_STATUS" |
        awk '$2 == "Ready" {count++} END {print count+0}'
    )"

    if [[ "$READY_NODES" -gt 0 ]]; then

        check_pass "Kubernetes Ready nodes: $READY_NODES"

    else

        check_warning "No Kubernetes nodes are Ready."

    fi

    echo
    info "Kubernetes nodes:"

    kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        get nodes -o wide 2>/dev/null ||
        true

    # ------------------------------------------
    # Pods
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

        check_pass "Kubernetes pods detected: $POD_COUNT"

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

        check_pass "Kubernetes pods are healthy."

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
    # Jenkins Service
    # ------------------------------------------

    if ! systemctl list-unit-files 2>/dev/null |
        grep -q "^jenkins.service"; then

        check_warning "Jenkins is not installed."
        return

    fi

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
    # Service
    # ------------------------------------------

    check_service_status "jenkins" "Jenkins" || true

    # ------------------------------------------
    # Port
    # ------------------------------------------

    check_port \
        "$JENKINS_PORT" \
        "Jenkins"

    # ------------------------------------------
    # HTTP
    # ------------------------------------------

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${JENKINS_PORT}/login" \
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

        check_warning "Prometheus is not installed."
        return

    fi

    # ------------------------------------------
    # Service
    # ------------------------------------------

    check_service_status "prometheus" "Prometheus" || true

    # ------------------------------------------
    # Port
    # ------------------------------------------

    check_port \
        "$PROMETHEUS_PORT" \
        "Prometheus"

    # ------------------------------------------
    # Ready Endpoint
    # ------------------------------------------

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
        >/dev/null 2>&1; then

        check_pass "Prometheus readiness endpoint is responding."

    else

        check_warning "Prometheus readiness endpoint is not responding."

    fi

    # ------------------------------------------
    # API
    # ------------------------------------------

    if curl -fsS \
        --max-time 5 \
        "http://127.0.0.1:${PROMETHEUS_PORT}/api/v1/status/buildinfo" \
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
            grafana-server -v 2>/dev/null ||
            true
        )"

        check_pass "Grafana installed: $GRAFANA_VERSION"

    else

        check_warning "Grafana is not installed."
        return

    fi

    # ------------------------------------------
    # Service
    # ------------------------------------------

    check_service_status \
        "grafana-server" \
        "Grafana" || true

    # ------------------------------------------
    # Port
    # ------------------------------------------

    check_port \
        "$GRAFANA_PORT" \
        "Grafana"

    # ------------------------------------------
    # Health API
    # ------------------------------------------

    local GRAFANA_HEALTH=""

    GRAFANA_HEALTH="$(
        curl -fsS \
            --max-time 5 \
            "http://127.0.0.1:${GRAFANA_PORT}/api/health" \
            2>/dev/null ||
            true
    )"

    if [[ -z "$GRAFANA_HEALTH" ]]; then

        check_warning "Grafana HTTP endpoint is not responding."
        return

    fi

    check_pass "Grafana HTTP endpoint is responding."

    # ------------------------------------------
    # Database Health
    # ------------------------------------------

    if echo "$GRAFANA_HEALTH" |
        grep -q '"database"[[:space:]]*:[[:space:]]*"ok"'; then

        check_pass "Grafana database health is OK."

    else

        check_warning \
            "Grafana responded but database health could not be confirmed."

    fi
}

# ==========================================
# Summary
# ==========================================

show_summary() {

    echo
    echo "=========================================="
    echo "        INSTALLATION SUMMARY"
    echo "=========================================="
    echo

    echo -e "${GREEN:-}PASS    : $PASS_COUNT${NC:-}"
    echo -e "${YELLOW:-}WARNING : $WARN_COUNT${NC:-}"
    echo -e "${RED:-}FAIL    : $FAIL_COUNT${NC:-}"

    echo
    echo "=========================================="

    if [[ "$FAIL_COUNT" -eq 0 ]]; then

        success "Installation verification completed successfully."

    else

        error "Installation verification completed with failures."

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

    log "DevOps installation verification completed."
}

# ==========================================
# Start
# ==========================================

main