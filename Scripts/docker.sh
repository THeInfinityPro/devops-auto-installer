#!/bin/bash

# ==========================================
# DevOps Auto Installer - Docker Installer
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

        error "This Docker installer currently supports Ubuntu only."
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
# Check Existing Docker Installation
# ==========================================

check_existing_docker() {

    info "Checking for existing Docker installation..."

    if command_exists docker; then

        DOCKER_VERSION="$(docker --version 2>/dev/null || echo "Unknown")"

        warning "Docker is already installed."
        info "$DOCKER_VERSION"

        if systemctl is-active --quiet docker; then

            success "Docker service is already running."

        else

            warning "Docker is installed but the service is not running."

            info "Starting Docker service..."

            systemctl enable docker.service
            systemctl start docker.service

            if systemctl is-active --quiet docker; then

                success "Docker service started successfully."

            else

                error "Docker service failed to start."

                systemctl status docker --no-pager || true

                exit 1

            fi

        fi

        return 0

    fi

    info "Docker is not currently installed."

    return 1
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
        docker-compose-v2
        podman-docker
        containerd
        runc
    )

    local removed=0

    for package in "${CONFLICTING_PACKAGES[@]}"
    do

        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then

            warning "Removing conflicting package: $package"

            apt-get remove -y "$package"

            removed=1

        fi

    done

    if [[ "$removed" -eq 1 ]]; then

        success "Conflicting Docker packages removed."

    else

        success "No conflicting Docker packages found."

    fi
}

# ==========================================
# Install Required Dependencies
# ==========================================

install_dependencies() {

    info "Updating package information..."

    apt-get update

    info "Installing required dependencies..."

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

        info "Downloading Docker GPG key..."

        curl -fsSL \
            https://download.docker.com/linux/ubuntu/gpg \
            -o /etc/apt/keyrings/docker.asc

        chmod a+r /etc/apt/keyrings/docker.asc

        success "Docker GPG key installed."

    else

        success "Docker GPG key already exists."

    fi

    ARCH="$(dpkg --print-architecture)"

    source /etc/os-release

    info "Configuring Docker APT repository..."

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

    info "Installing Docker Engine and required components..."

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    success "Docker packages installed successfully."
}

# ==========================================
# Enable and Start Docker Services
# ==========================================

start_docker() {

    info "Enabling Docker services..."

    systemctl enable docker.service
    systemctl enable containerd.service

    info "Starting Containerd..."

    systemctl start containerd.service

    info "Starting Docker..."

    systemctl start docker.service

    echo

    if systemctl is-active --quiet containerd; then

        success "Containerd service is running."

    else

        warning "Containerd service is not running."

    fi

    if systemctl is-active --quiet docker; then

        success "Docker service is running."

    else

        error "Docker service failed to start."

        systemctl status docker --no-pager || true

        exit 1

    fi
}

# ==========================================
# Configure Docker User
# ==========================================

configure_docker_user() {

    local USER_NAME=""

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then

        USER_NAME="$SUDO_USER"

    elif [[ -n "${USER:-}" && "$USER" != "root" ]]; then

        USER_NAME="$USER"

    fi

    if [[ -n "$USER_NAME" ]]; then

        info "Configuring Docker access for user: $USER_NAME"

        groupadd -f docker

        if id -nG "$USER_NAME" | grep -qw docker; then

            success "$USER_NAME is already a member of the docker group."

        else

            usermod -aG docker "$USER_NAME"

            success "$USER_NAME added to the docker group."

            warning "Log out and log back in for Docker group changes to take effect."

        fi

    else

        warning "Could not determine the non-root user."

        info "You can manually run:"
        info "sudo usermod -aG docker <username>"

    fi
}

# ==========================================
# Verify Docker Installation
# ==========================================

verify_docker() {

    echo

    info "Verifying Docker installation..."

    # Docker command
    if command_exists docker; then

        success "Docker command found."

        echo "Docker Version:"
        docker --version

    else

        error "Docker command was not found."

        exit 1

    fi

    echo

    # Docker service
    if systemctl is-active --quiet docker; then

        success "Docker service is running."

    else

        error "Docker service is not running."

        exit 1

    fi

    # Containerd service
    if systemctl is-active --quiet containerd; then

        success "Containerd service is running."

    else

        warning "Containerd service is not running."

    fi

    echo

    # Docker Compose
    if docker compose version >/dev/null 2>&1; then

        success "Docker Compose plugin is available."

        docker compose version

    else

        warning "Docker Compose plugin could not be verified."

    fi

    echo

    # Docker daemon
    info "Testing Docker daemon..."

    if docker info >/dev/null 2>&1; then

        success "Docker daemon is responding."

    else

        warning "Docker daemon cannot be accessed by the current user."

        info "This may happen if the Docker group change requires a new login session."

    fi

    echo

    # Test container
    info "Testing Docker with hello-world container..."

    if docker run --rm hello-world >/dev/null 2>&1; then

        success "Docker test container completed successfully."

    else

        warning "Docker test container could not be executed by the current user."

        info "If you were just added to the Docker group, log out and log back in."

    fi
}

# ==========================================
# Display Docker Summary
# ==========================================

show_summary() {

    echo

    echo "=========================================="
    echo "           DOCKER INSTALLATION"
    echo "=========================================="

    echo "Docker Service    : $(get_service_status docker)"
    echo "Containerd Service: $(get_service_status containerd)"

    if command_exists docker; then

        echo "Docker Version    : $(docker --version)"

    fi

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
    echo "         DOCKER INSTALLER"
    echo "=========================================="

    echo

    info "Starting Docker installation..."

    check_supported_os

    # Check existing installation
    if check_existing_docker; then

        info "Docker is already installed."

        verify_docker

        show_summary

        success "Docker is ready to use."

        log "[SUCCESS] Docker already installed and verified."

        return 0

    fi

    # Installation process
    remove_conflicting_packages

    install_dependencies

    configure_docker_repository

    install_docker

    start_docker

    configure_docker_user

    verify_docker

    show_summary

    log "[SUCCESS] Docker installation completed successfully."

    echo

    success "=========================================="
    success "DOCKER INSTALLATION COMPLETED"
    success "=========================================="

    echo
}

# ==========================================
# Execute
# ==========================================

main