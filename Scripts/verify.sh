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
# Prometheus Paths
# ==========================================

PROMETHEUS_BINARY="/opt/prometheus/prometheus"
PROMTOOL_BINARY="/opt/prometheus/promtool"
PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"

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

    success "$1"
    log "[PASS] $1"

    ((PASS_COUNT+=1))
}

check_fail() {

    error "$1"
    log "[FAIL] $1"

    ((FAIL_COUNT+=1))
}

check_warning() {

    warning "$1"
    log "[WARNING] $1"

    ((WARN_COUNT+=1))
}

# ==========================================
# Section Header
# ==========================================

section() {

    echo
    echo "=========================================="
    echo " $1"
    echo "=========================================="
    echo
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

    if systemctl is-active --quiet "$SERVICE"; then

        check_pass "$DISPLAY_NAME service is running."

        return 0

    else

        check_fail "$DISPLAY_NAME service is not running."

        return 1

    fi
}

# ==========================================
# Check HTTP Endpoint
# ==========================================

check_http() {

    local URL="$1"
    local NAME="$2"

    if curl -fsS \
        --max-time 5 \
        "$URL" \
        >/dev/null 2>&1; then

        check_pass "$NAME is responding."

        return 0

    else

        check_warning "$NAME is not responding."

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

    info "Starting complete DevOps environment verification..."
}

# ==========================================
# Docker Verification
# ==========================================

verify_docker() {

    section "DOCKER VERIFICATION"

    # Docker Binary

    if command_exists docker; then

        DOCKER_VERSION="$(docker --version 2>/dev/null || true)"

        check_pass "Docker installed: $DOCKER_VERSION"

    else

        check_warning "Docker is not installed."

        return

    fi

    # Docker Service

    check_service_status "docker" "Docker" || true

    # Docker Engine

    if docker info >/dev/null 2>&1; then

        check_pass "Docker engine is responding."

    else

        check_fail "Docker engine is not responding."

    fi

    # Docker Compose

    if docker compose version >/dev/null 2>&1; then

        COMPOSE_VERSION="$(docker compose version 2>/dev/null)"

        check_pass "Docker Compose available: $COMPOSE_VERSION"

    else

        check_warning "Docker Compose is not available."

    fi

    # Containerd Binary

    if command_exists containerd; then

        CONTAINERD_VERSION="$(containerd --version 2>/dev/null || true)"

        check_pass "Containerd installed: $CONTAINERD_VERSION"

    else

        check_warning "Containerd command not found."

    fi

    # Containerd Service

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
# Kubernetes Components Verification
# ==========================================

verify_kubernetes_components() {

    section "KUBERNETES COMPONENT VERIFICATION"

    local COMPONENTS_FOUND=0

    # kubeadm

    if command_exists kubeadm; then

        COMPONENTS_FOUND=1

        KUBEADM_VERSION="$(kubeadm version -o short 2>/dev/null || true)"

        check_pass "kubeadm installed: $KUBEADM_VERSION"

    else

        check_warning "kubeadm is not installed."

    fi

    # kubelet

    if command_exists kubelet; then

        COMPONENTS_FOUND=1

        KUBELET_VERSION="$(kubelet --version 2>/dev/null || true)"

        check_pass "kubelet installed: $KUBELET_VERSION"

    else

        check_warning "kubelet is not installed."

    fi

    # kubectl

    if command_exists kubectl; then

        COMPONENTS_FOUND=1

        KUBECTL_VERSION="$(kubectl version --client 2>/dev/null | head -1 || true)"

        check_pass "kubectl installed: $KUBECTL_VERSION"

    else

        check_warning "kubectl is not installed."

    fi

    if [[ "$COMPONENTS_FOUND" -eq 0 ]]; then

        check_warning "Kubernetes components are not installed."

        return

    fi

    # Kubelet Service

    check_service_status "kubelet" "Kubelet" || true
}

# ==========================================
# Kubernetes Cluster Verification
# ==========================================

verify_kubernetes_cluster() {

    section "KUBERNETES CLUSTER VERIFICATION"

    if ! command_exists kubectl; then

        check_warning "kubectl is not installed. Skipping cluster verification."

        return

    fi

    local KUBE_CONFIG=""

    # Detect kubeconfig

    if [[ -f "/etc/kubernetes/admin.conf" ]]; then

        KUBE_CONFIG="/etc/kubernetes/admin.conf"

    elif [[ -n "${KUBECONFIG:-}" ]] &&
         [[ -f "$KUBECONFIG" ]]; then

        KUBE_CONFIG="$KUBECONFIG"

    elif [[ -f "$HOME/.kube/config" ]]; then

        KUBE_CONFIG="$HOME/.kube/config"

    else

        check_warning "Kubernetes cluster is not initialized."

        return

    fi

    check_pass "Kubernetes kubeconfig found: $KUBE_CONFIG"

    # API Port

    check_port \
        "$KUBERNETES_API_PORT" \
        "Kubernetes API" || true

    # API Server

    if kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        cluster-info >/dev/null 2>&1; then

        check_pass "Kubernetes API server is reachable."

    else

        check_fail "Kubernetes API server is not reachable."

        return

    fi

    # Context

    CURRENT_CONTEXT="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            config current-context 2>/dev/null || true
    )"

    if [[ -n "$CURRENT_CONTEXT" ]]; then

        check_pass "Kubernetes context: $CURRENT_CONTEXT"

    else

        check_warning "Kubernetes context is not configured."

    fi

    # Nodes

    NODE_STATUS="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get nodes \
            --no-headers 2>/dev/null || true
    )"

    if [[ -z "$NODE_STATUS" ]]; then

        check_fail "No Kubernetes nodes were found."

        return

    fi

    READY_NODES="$(
        echo "$NODE_STATUS" |
        awk '$2 == "Ready" {count++} END {print count+0}'
    )"

    TOTAL_NODES="$(
        echo "$NODE_STATUS" | wc -l
    )"

    check_pass "Total Kubernetes nodes: $TOTAL_NODES"

    if [[ "$READY_NODES" -gt 0 ]]; then

        check_pass "Ready Kubernetes nodes: $READY_NODES"

    else

        check_warning "No Kubernetes nodes are Ready."

    fi

    echo

    info "Node status:"

    kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        get nodes -o wide 2>/dev/null || true

    # Pods

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

        check_warning "No Kubernetes pods detected."

    fi

    NOT_HEALTHY_PODS="$(
        kubectl \
            --kubeconfig="$KUBE_CONFIG" \
            get pods -A \
            --no-headers 2>/dev/null |
            awk '$4 != "Running" && $4 != "Completed" {print}'
    )"

    if [[ -z "$NOT_HEALTHY_PODS" ]]; then

        check_pass "Kubernetes pods are healthy."

    else

        check_warning "Some Kubernetes pods are not healthy."

        echo
        echo "$NOT_HEALTHY_PODS"

    fi

    # Calico

    if kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        get daemonset calico-node \
        -n kube-system \
        >/dev/null 2>&1; then

        check_pass "Calico CNI is installed."

    else

        check_warning "Calico CNI was not detected."

    fi
}

# ==========================================
# Jenkins Verification
# ==========================================

verify_jenkins() {

    section "JENKINS VERIFICATION"

    if ! systemctl list-unit-files 2>/dev/null |
        grep -q "^jenkins.service"; then

        check_warning "Jenkins is not installed."

        return

    fi

    # Java

    if command_exists java; then

        JAVA_VERSION="$(java -version 2>&1 | head -1)"

        check_pass "Java installed: $JAVA_VERSION"

    else

        check_fail "Java is not installed."

    fi

    # Jenkins Service

    check_service_status "jenkins" "Jenkins" || true

    # Port

    check_port \
        "$JENKINS_PORT" \
        "Jenkins" || true

    # HTTP

    check_http \
        "http://127.0.0.1:${JENKINS_PORT}/login" \
        "Jenkins HTTP endpoint" || true
}

# ==========================================
# Prometheus Verification
# ==========================================

verify_prometheus() {

    section "PROMETHEUS VERIFICATION"

    # Prometheus Binary

    if [[ -x "$PROMETHEUS_BINARY" ]]; then

        PROM_VERSION="$(
            "$PROMETHEUS_BINARY" \
                --version 2>/dev/null |
                head -1
        )"

        check_pass "Prometheus installed: $PROM_VERSION"

    else

        check_warning "Prometheus binary not found: $PROMETHEUS_BINARY"

        return

    fi

    # Promtool

    if [[ -x "$PROMTOOL_BINARY" ]]; then

        check_pass "Promtool is installed."

    else

        check_warning "Promtool is not installed."

    fi

    # Configuration

    if [[ -f "$PROMETHEUS_CONFIG" ]]; then

        check_pass "Prometheus configuration found."

        if [[ -x "$PROMTOOL_BINARY" ]]; then

            if "$PROMTOOL_BINARY" check config \
                "$PROMETHEUS_CONFIG" \
                >/dev/null 2>&1; then

                check_pass "Prometheus configuration is valid."

            else

                check_fail "Prometheus configuration validation failed."

            fi

        fi

    else

        check_fail "Prometheus configuration not found."

    fi

    # Service

    check_service_status \
        "prometheus" \
        "Prometheus" || true

    # Port

    check_port \
        "$PROMETHEUS_PORT" \
        "Prometheus" || true

    # Ready Endpoint

    check_http \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
        "Prometheus readiness endpoint" || true

    # Health Endpoint

    check_http \
        "http://127.0.0.1:${PROMETHEUS_PORT}/-/healthy" \
        "Prometheus health endpoint" || true

    # API

    check_http \
        "http://127.0.0.1:${PROMETHEUS_PORT}/api/v1/status/buildinfo" \
        "Prometheus API" || true
}

# ==========================================
# Grafana Verification
# ==========================================

verify_grafana() {

    section "GRAFANA VERIFICATION"

    # Grafana Binary

    if command_exists grafana-server; then

        GRAFANA_VERSION="$(
            grafana-server -v 2>/dev/null || true
        )"

        check_pass "Grafana installed: $GRAFANA_VERSION"

    else

        check_warning "Grafana is not installed."

        return

    fi

    # Service

    check_service_status \
        "grafana-server" \
        "Grafana" || true

    # Port

    check_port \
        "$GRAFANA_PORT" \
        "Grafana" || true

    # Health API

    GRAFANA_HEALTH="$(
        curl -fsS \
            --max-time 5 \
            "http://127.0.0.1:${GRAFANA_PORT}/api/health" \
            2>/dev/null || true
    )"

    if [[ -z "$GRAFANA_HEALTH" ]]; then

        check_warning "Grafana HTTP endpoint is not responding."

        return

    fi

    check_pass "Grafana HTTP endpoint is responding."

    # Database Health

    if echo "$GRAFANA_HEALTH" |
        grep -q '"database"[[:space:]]*:[[:space:]]*"ok"'; then

        check_pass "Grafana database health is OK."

    else

        check_warning \
            "Grafana responded but database health could not be confirmed."

    fi
}

# ==========================================
# Overall Health Result
# ==========================================

show_overall_result() {

    echo

    if [[ "$FAIL_COUNT" -eq 0 ]]; then

        success "Overall verification status: HEALTHY"

    elif [[ "$FAIL_COUNT" -le 2 ]]; then

        warning "Overall verification status: PARTIALLY HEALTHY"

    else

        error "Overall verification status: ISSUES DETECTED"

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

    echo "PASS    : $PASS_COUNT"
    echo "WARNING : $WARN_COUNT"
    echo "FAIL    : $FAIL_COUNT"

    show_overall_result

    echo
    echo "=========================================="

    if [[ "$FAIL_COUNT" -eq 0 ]]; then

        success "Installation verification completed successfully."

    else

        warning "Installation verification completed with some issues."

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

    log "[INFO] DevOps installation verification completed."

    # Do not fail the entire UI just because
    # one optional component has an issue.

    return 0
}

# ==========================================
# Start
# ==========================================

main