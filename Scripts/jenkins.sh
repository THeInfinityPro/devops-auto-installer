#!/bin/bash

# ==========================================
# DevOps Auto Installer - Jenkins
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check OS
# ==========================================

check_supported_os() {

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "Jenkins installer currently supports Ubuntu only."
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
# Install Java
# ==========================================

install_java() {

    info "Installing Java 21..."

    apt-get update

    apt-get install -y \
        fontconfig \
        openjdk-21-jre

    success "Java 21 installed."

    java -version
}

# ==========================================
# Configure Jenkins Repository
# ==========================================

configure_jenkins_repository() {

    info "Configuring Jenkins LTS repository..."

    mkdir -p /etc/apt/keyrings

    wget -O /etc/apt/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

    chmod 644 /etc/apt/keyrings/jenkins-keyring.asc

    echo \
        "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
        > /etc/apt/sources.list.d/jenkins.list

    apt-get update

    success "Jenkins LTS repository configured."
}

# ==========================================
# Install Jenkins
# ==========================================

install_jenkins() {

    info "Installing latest Jenkins LTS..."

    apt-get install -y jenkins

    success "Jenkins installed."
}

# ==========================================
# Start Jenkins
# ==========================================

start_jenkins() {

    info "Enabling Jenkins service..."

    systemctl enable jenkins

    info "Starting Jenkins service..."

    systemctl start jenkins

    if systemctl is-active --quiet jenkins; then
        success "Jenkins service is running."
    else
        error "Jenkins service failed to start."
        systemctl status jenkins --no-pager
        exit 1
    fi
}

# ==========================================
# Display Jenkins Password
# ==========================================

show_initial_password() {

    PASSWORD_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

    echo

    if [[ -f "$PASSWORD_FILE" ]]; then

        info "Jenkins initial administrator password:"

        echo
        cat "$PASSWORD_FILE"
        echo

    else

        warning "Initial Jenkins password file was not found yet."

    fi
}

# ==========================================
# Verify Jenkins
# ==========================================

verify_jenkins() {

    info "Verifying Jenkins installation..."

    if ! command_exists java; then
        error "Java is not available."
        exit 1
    fi

    if ! systemctl is-active --quiet jenkins; then
        error "Jenkins service is not running."
        exit 1
    fi

    success "Jenkins service verification passed."

    info "Checking Jenkins web interface..."

    for i in {1..6}; do

        if curl -fsS --max-time 10 \
            "http://127.0.0.1:${JENKINS_PORT}/login" \
            >/dev/null 2>&1; then

            success "Jenkins web interface is responding on port: ${JENKINS_PORT}."
            return 0
        fi

        info "Jenkins is not ready yet. Waiting 10 seconds..."
        sleep 10

    done

    warning "Jenkins service is running but the web interface did not respond within 60 seconds."
}

# ==========================================
# Main
# ==========================================

main() {

    initialize

    info "Starting Jenkins installation..."

    check_supported_os

    install_java

    configure_jenkins_repository

    install_jenkins

    start_jenkins

    verify_jenkins

    show_initial_password

    log "Jenkins installation completed."

    echo
    success "=========================================="
    success "Jenkins installation completed."
    success "=========================================="
}

main