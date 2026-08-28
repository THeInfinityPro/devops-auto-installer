#!/bin/bash

# ==========================================
# DevOps Auto Installer - Jenkins Installer
# ==========================================

set -e

# ==========================================
# Load Common Functions
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# ==========================================
# Check Supported Operating System
# ==========================================

check_supported_os() {

    info "Checking operating system compatibility..."

    if [[ "$OS_NAME" != "ubuntu" ]]; then

        error "Jenkins installer currently supports Ubuntu only."
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
# Check Existing Jenkins Installation
# ==========================================

check_existing_jenkins() {

    info "Checking for existing Jenkins installation..."

    if systemctl list-unit-files 2>/dev/null | \
        grep -q "^jenkins.service"; then

        warning "Jenkins is already installed."

        if systemctl is-active --quiet jenkins; then

            success "Jenkins service is already running."

        else

            warning "Jenkins is installed but not running."

            info "Attempting to start Jenkins..."

            systemctl enable jenkins
            systemctl start jenkins

            sleep 5

        fi

        return 0

    fi

    info "Jenkins is not currently installed."

    return 1
}

# ==========================================
# Install Java
# ==========================================

install_java() {

    info "Checking Java installation..."

    if command_exists java; then

        JAVA_VERSION="$(java -version 2>&1 | head -n 1)"

        success "Java is already installed."
        info "$JAVA_VERSION"

        return 0

    fi

    info "Installing Java 21..."

    apt-get update

    apt-get install -y \
        fontconfig \
        openjdk-21-jre

    success "Java 21 installed successfully."

    java -version
}

# ==========================================
# Configure Jenkins Repository
# ==========================================

configure_jenkins_repository() {

    info "Configuring Jenkins LTS repository..."

    apt-get update

    apt-get install -y \
        wget \
        ca-certificates

    mkdir -p -m 0755 /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/jenkins-keyring.asc ]]; then

        info "Downloading Jenkins repository key..."

        wget -q \
            -O /etc/apt/keyrings/jenkins-keyring.asc \
            https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

        chmod 644 /etc/apt/keyrings/jenkins-keyring.asc

        success "Jenkins repository key installed."

    else

        success "Jenkins repository key already exists."

    fi

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

    info "Installing Jenkins LTS..."

    apt-get install -y jenkins

    success "Jenkins installed successfully."
}

# ==========================================
# Start Jenkins
# ==========================================

start_jenkins() {

    info "Enabling Jenkins service..."

    systemctl daemon-reload
    systemctl enable jenkins

    info "Starting Jenkins service..."

    systemctl start jenkins

    local max_attempts=12

    for ((i=1; i<=max_attempts; i++))
    do

        if systemctl is-active --quiet jenkins; then

            success "Jenkins service is running."

            return 0

        fi

        info "Waiting for Jenkins service... ($i/$max_attempts)"

        sleep 5

    done

    error "Jenkins service failed to start."

    systemctl status jenkins --no-pager || true

    exit 1
}

# ==========================================
# Check Jenkins Port
# ==========================================

check_jenkins_port() {

    info "Checking Jenkins port ${JENKINS_PORT}..."

    if ss -tuln | grep -qE ":${JENKINS_PORT}[[:space:]]"; then

        success "Port ${JENKINS_PORT} is listening locally."

    else

        warning "Port ${JENKINS_PORT} is not detected as listening."

    fi

    info "Checking local firewall status..."

    if command_exists ufw; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then

            if ufw status | grep -q "${JENKINS_PORT}"; then

                success "UFW contains a rule related to port ${JENKINS_PORT}."

            else

                warning "UFW is active and no explicit rule was found for port ${JENKINS_PORT}."

            fi

        else

            success "UFW firewall is inactive."

        fi

    else

        info "UFW is not installed."

    fi
}

# ==========================================
# Display Jenkins Initial Password
# ==========================================

show_initial_password() {

    local PASSWORD_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

    echo

    if [[ -f "$PASSWORD_FILE" ]]; then

        info "Jenkins initial administrator password:"

        echo
        echo "------------------------------------------"

        cat "$PASSWORD_FILE"

        echo "------------------------------------------"
        echo

    else

        warning "Initial Jenkins password file was not found."

        info "Jenkins may still be completing its first startup."

    fi
}

# ==========================================
# Verify Jenkins
# ==========================================

verify_jenkins() {

    echo

    info "Verifying Jenkins installation..."

    # Java
    if command_exists java; then

        success "Java is available."

    else

        error "Java is not available."

        exit 1

    fi

    # Jenkins service
    if systemctl is-active --quiet jenkins; then

        success "Jenkins service is running."

    else

        error "Jenkins service is not running."

        exit 1

    fi

    # Jenkins web interface
    info "Checking Jenkins web interface..."

    local max_attempts=12

    for ((i=1; i<=max_attempts; i++))
    do

        if curl -fsS \
            --max-time 10 \
            "http://127.0.0.1:${JENKINS_PORT}/login" \
            >/dev/null 2>&1
        then

            success "Jenkins web interface is responding."

            return 0

        fi

        info "Jenkins is still starting... ($i/$max_attempts)"

        sleep 5

    done

    warning "Jenkins service is running, but the web interface did not respond in time."
}

# ==========================================
# Display Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "        JENKINS INSTALLATION SUMMARY"
    echo "=========================================="

    echo "Service Status : $(get_service_status jenkins)"
    echo "Jenkins Port   : ${JENKINS_PORT}"

    if command_exists java; then

        echo "Java Version   : $(java -version 2>&1 | head -n 1)"

    fi

    echo
    echo "Local URL:"
    echo "http://localhost:${JENKINS_PORT}"

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
    echo "           JENKINS INSTALLER"
    echo "=========================================="

    echo

    info "Starting Jenkins installation..."

    check_supported_os

    # Check existing Jenkins
    if check_existing_jenkins; then

        info "Verifying existing Jenkins installation..."

        verify_jenkins
        check_jenkins_port
        show_initial_password
        show_summary

        log "[SUCCESS] Existing Jenkins installation verified."

        success "Jenkins is ready to use."

        return 0

    fi

    # Install Java
    install_java

    # Configure Jenkins repository
    configure_jenkins_repository

    # Install Jenkins
    install_jenkins

    # Start Jenkins
    start_jenkins

    # Verify Jenkins
    verify_jenkins

    # Check port
    check_jenkins_port

    # Show password
    show_initial_password

    # Summary
    show_summary

    log "[SUCCESS] Jenkins installation completed successfully."

    echo

    success "=========================================="
    success "JENKINS INSTALLATION COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Start Installer
# ==========================================

main