#!/bin/bash

# ==========================================
# DevOps Auto Installer - Verification
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
    echo "       DEVOPS INSTALLATION CHECK"
    echo "=========================================="
    echo
}

# ==========================================
# Docker
# ==========================================

verify_docker() {

    echo
    info "Checking Docker..."

    if command_exists docker; then

        DOCKER_VERSION="$(docker --version)"

        check_pass "Docker installed: $DOCKER_VERSION"

    else

        check_fail "Docker is not installed."

    fi
}

# ==========================================
# Docker Compose
# ==========================================

verify_docker_compose() {

    info "Checking Docker Compose..."

    if docker compose version >/dev/null 2>&1; then

        COMPOSE_VERSION="$(docker compose version)"

        check_pass "Docker Compose installed: $COMPOSE_VERSION"

    else

        check_fail "Docker Compose is not available."

    fi
}

# ==========================================
# Containerd
# ==========================================

verify_containerd() {

    info "Checking containerd..."

    if command_exists containerd; then

        CONTAINERD_VERSION="$(containerd --version)"

        check_pass "Containerd installed: $CONTAINERD_VERSION"

    else

        check_fail "Containerd is not installed."

    fi
}

# ==========================================
# Docker Service
# ==========================================

verify_docker_service() {

    info "Checking Docker service..."

    if systemctl is-active --quiet docker; then

        check_pass "Docker service is running."

    else

        check_fail "Docker service is not running."

    fi
}

# ==========================================
# Kubernetes - kubeadm
# ==========================================

verify_kubeadm() {

    info "Checking kubeadm..."

    if command_exists kubeadm; then

        KUBEADM_VERSION="$(kubeadm version -o short 2>/dev/null || true)"

        check_pass "kubeadm installed: $KUBEADM_VERSION"

    else

        check_fail "kubeadm is not installed."

    fi
}

# ==========================================
# Kubernetes - kubelet
# ==========================================

verify_kubelet() {

    info "Checking kubelet..."

    if command_exists kubelet; then

        KUBELET_VERSION="$(kubelet --version)"

        check_pass "kubelet installed: $KUBELET_VERSION"

    else

        check_fail "kubelet is not installed."

    fi
}

# ==========================================
# Kubernetes - kubectl
# ==========================================

verify_kubectl() {

    info "Checking kubectl..."

    if command_exists kubectl; then

        KUBECTL_VERSION="$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1 || true)"

        check_pass "kubectl installed: $KUBECTL_VERSION"

    else

        check_fail "kubectl is not installed."

    fi
}

# ==========================================
# Kubelet Service
# ==========================================

verify_kubelet_service() {

    info "Checking kubelet service..."

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
# Jenkins
# ==========================================

verify_jenkins() {

    info "Checking Jenkins..."

    if command_exists java; then

        check_pass "Java is installed."

    else

        check_fail "Java is not installed."

    fi

    if systemctl list-unit-files 2>/dev/null | grep -q "^jenkins.service"; then

        if systemctl is-active --quiet jenkins; then

            check_pass "Jenkins service is running."

        else

            check_fail "Jenkins service is installed but not running."

        fi

    else

        check_fail "Jenkins service is not installed."

    fi
}

# ==========================================
# Prometheus
# ==========================================

verify_prometheus() {

    info "Checking Prometheus..."

    if [[ -x "/opt/prometheus/prometheus" ]]; then

        PROM_VERSION="$(/opt/prometheus/prometheus --version 2>/dev/null | head -1)"

        check_pass "Prometheus installed: $PROM_VERSION"

    else

        check_fail "Prometheus binary is not installed."

    fi

    if systemctl is-active --quiet prometheus 2>/dev/null; then

        check_pass "Prometheus service is running."

    else

        check_fail "Prometheus service is not running."

    fi

    if curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1; then

        check_pass "Prometheus HTTP endpoint is responding."

    else

        check_warning "Prometheus service is running but HTTP readiness check failed."

    fi
}

# ==========================================
# Grafana
# ==========================================

verify_grafana() {

    info "Checking Grafana..."

    if command_exists grafana-server; then

        GRAFANA_VERSION="$(grafana-server -v 2>/dev/null)"

        check_pass "Grafana installed: $GRAFANA_VERSION"

    else

        check_fail "Grafana is not installed."

    fi

    if systemctl is-active --quiet grafana-server 2>/dev/null; then

        check_pass "Grafana service is running."

    else

        check_fail "Grafana service is not running."

    fi

info "Checking Grafana HTTP endpoint..."

GRAFANA_READY=false

for i in {1..12}; do

    if curl -fsS \
        http://127.0.0.1:3000/api/health \
        >/dev/null 2>&1; then

        GRAFANA_READY=true
        break

    fi

    sleep 5

done

if [[ "$GRAFANA_READY" == true ]]; then

    check_pass "Grafana HTTP endpoint is responding."

else

    check_warning "Grafana service is running but HTTP endpoint is not responding."

fi
}

# ==========================================
# Summary
# ==========================================

show_summary() {

    echo
    echo "=========================================="
    echo "          VERIFICATION SUMMARY"
    echo "=========================================="
    echo

    echo -e "${GREEN}PASS : $PASS_COUNT${NC}"
    echo -e "${YELLOW}WARN : $WARN_COUNT${NC}"
    echo -e "${RED}FAIL : $FAIL_COUNT${NC}"

    echo
    echo "=========================================="

    if [[ "$FAIL_COUNT" -eq 0 ]]; then

        success "Verification completed successfully."

    else

        error "Verification completed with failures."

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
    verify_docker_compose
    verify_containerd
    verify_docker_service

    verify_kubeadm
    verify_kubelet
    verify_kubectl
    verify_kubelet_service

    verify_jenkins

    verify_prometheus

    verify_grafana

    show_summary

    log "System verification completed."

}

# ==========================================
# Start
# ==========================================

main