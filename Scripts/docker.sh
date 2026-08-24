#!/bin/bash

# ==========================================
# DevOps Auto Installer - Docker
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

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "This Docker installer currently supports Ubuntu only."
        exit 1
    fi

    case "$OS_VERSION" in
        22.04|24.04|26.04)
            success "Supported Ubuntu version detected: $OS_VERSION"
            ;;
        *)
            error "Unsupported Ubuntu version: $OS_VERSION"
            error "Supported versions: Ubuntu 22.04 , 24.04 and 26.04"
            exit 1
            ;;
    esac
}


# ==========================================
# Check Existing Docker Installation
# ==========================================

check_existing_docker() {

    if command_exists docker; then

        DOCKER_VERSION="$(docker --version)"

        warning "Docker is already installed."
        info "$DOCKER_VERSION"

        if systemctl is-active --quiet docker; then
            success "Docker service is already running."
        else
            warning "Docker is installed but the service is not running."
            info "Starting Docker service..."

            systemctl start docker

            success "Docker service started."
        fi

        return 0
    fi

    info "Docker is not currently installed."
}


# ==========================================
# Remove Conflicting Packages
# ==========================================

remove_conflicting_packages() {

    info "Checking for conflicting Docker packages..."

    CONFLICTING_PACKAGES=(
        docker.io
        docker-doc
        docker-compose
        podman-docker
        containerd
        runc
    )

    for package in "${CONFLICTING_PACKAGES[@]}"; do

        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then

            warning "Removing conflicting package: $package"

            apt-get remove -y "$package"

        fi

    done

    success "Conflicting package check completed."
}


# ==========================================
# Install Required Dependencies
# ==========================================

install_dependencies() {

    info "Installing required dependencies..."

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl

    success "Required dependencies installed."
}


# ==========================================
# Configure Docker Repository
# ==========================================

configure_docker_repository() {

    info "Configuring Docker official repository..."

    install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then

        curl -fsSL \
            https://download.docker.com/linux/ubuntu/gpg \
            -o /etc/apt/keyrings/docker.asc

        chmod a+r /etc/apt/keyrings/docker.asc

    fi

    ARCH="$(dpkg --print-architecture)"

    . /etc/os-release

    echo \
      "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update

    success "Docker official repository configured."
}


# ==========================================
# Install Docker
# ==========================================

install_docker() {

    info "Installing latest available Docker packages..."

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    success "Docker packages installed successfully."
}


# ==========================================
# Enable and Start Docker
# ==========================================

start_docker() {

    info "Enabling Docker service..."

    systemctl enable docker.service
    systemctl enable containerd.service

    info "Starting Docker service..."

    systemctl start docker

    if systemctl is-active --quiet docker; then
        success "Docker service is running."
    else
        error "Docker service failed to start."
        systemctl status docker --no-pager
        exit 1
    fi
}


# ==========================================
# Configure Docker User
# ==========================================

configure_docker_user() {

    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then

        USER_NAME="$SUDO_USER"

        info "Adding $USER_NAME to the docker group..."

        groupadd -f docker

        usermod -aG docker "$USER_NAME"

        success "$USER_NAME added to the docker group."

        warning "Log out and log back in for the docker group change to take effect."

    else

        warning "Could not determine the non-root user."
        info "You can manually add your user to the docker group later."

    fi
}


# ==========================================
# Verify Docker
# ==========================================

verify_docker() {

    echo

    info "Verifying Docker installation..."

    if ! command_exists docker; then
        error "Docker command was not found."
        exit 1
    fi

    docker --version

    if ! systemctl is-active --quiet docker; then
        error "Docker service is not running."
        exit 1
    fi

    success "Docker service verification passed."

    info "Testing Docker daemon..."

    if docker info >/dev/null 2>&1; then
        success "Docker daemon is responding."
    else
        warning "Docker daemon could not be accessed by the current user."
        info "This may be because the docker group change requires a new login session."
    fi

    info "Running Docker test container..."

    if docker run --rm hello-world >/dev/null 2>&1; then
        success "Docker test container completed successfully."
    else
        warning "Docker test container could not be executed by the current user."
        info "If you were just added to the docker group, log out and log back in, then test again."
    fi
}


# ==========================================
# Main
# ==========================================

main() {

    initialize

    info "Starting Docker installation..."

    check_supported_os

    check_existing_docker

    if command_exists docker; then
        verify_docker
        success "Docker is ready."
        return 0
    fi

    remove_conflicting_packages

    install_dependencies

    configure_docker_repository

    install_docker

    start_docker

    configure_docker_user

    verify_docker

    log "Docker installation completed successfully."

    echo
    success "=========================================="
    success "Docker installation completed."
    success "=========================================="
}

# ==========================================
# Execute
# ==========================================

main