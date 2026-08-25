#!/bin/bash

# ==========================================
# DevOps Auto Installer
# Main Installer
# ==========================================

set -e

# ==========================================
# Load Common Functions
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/Scripts/common.sh"


# ==========================================
# Installer Header
# ==========================================

show_header() {

    clear

    echo
    echo "=========================================="
    echo "        DEVOPS AUTO INSTALLER"
    echo "=========================================="
    echo
}


# ==========================================
# Pause
# ==========================================

pause() {

    echo
    read -rp "Press Enter to continue..."
}


# ==========================================
# Menu
# ==========================================

show_menu() {

    echo "1. Health Check / Port Check"
    echo "2. Install Docker"
    echo "3. Install Kubernetes"
    echo "4. Setup Kubernetes Cluster"
    echo "5. Install Jenkins"
    echo "6. Install Prometheus"
    echo "7. Install Grafana"
    echo
    echo "8. Install Everything"
    echo "9. Verify Installation"
    echo "10. Uninstall"
    echo
    echo "0. Exit"
    echo
}


# ==========================================
# Install Everything
# ==========================================

install_everything() {

    echo
    echo "=========================================="
    echo "       COMPLETE DEVOPS INSTALLATION"
    echo "=========================================="
    echo

    info "Starting complete DevOps installation..."


    # ------------------------------------------
    # Docker
    # ------------------------------------------

    info "Step 1/7: Installing Docker..."

    bash "$SCRIPT_DIR/Scripts/docker.sh"

    success "Docker installation completed."


    # ------------------------------------------
    # Kubernetes Components
    # ------------------------------------------

    info "Step 2/7: Installing Kubernetes components..."

    bash "$SCRIPT_DIR/Scripts/kubernetes.sh"

    success "Kubernetes component installation completed."


    # ------------------------------------------
    # Kubernetes Cluster
    # ------------------------------------------

    info "Step 3/7: Setting up Kubernetes cluster..."

    bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"

    success "Kubernetes cluster setup completed."


    # ------------------------------------------
    # Jenkins
    # ------------------------------------------

    info "Step 4/7: Installing Jenkins..."

    bash "$SCRIPT_DIR/Scripts/jenkins.sh"

    success "Jenkins installation completed."


    # ------------------------------------------
    # Prometheus
    # ------------------------------------------

    info "Step 5/7: Installing Prometheus..."

    bash "$SCRIPT_DIR/Scripts/prometheus.sh"

    success "Prometheus installation completed."


    # ------------------------------------------
    # Grafana
    # ------------------------------------------

    info "Step 6/7: Installing Grafana..."

    bash "$SCRIPT_DIR/Scripts/grafana.sh"

    success "Grafana installation completed."


    # ------------------------------------------
    # Verification
    # ------------------------------------------

    info "Step 7/7: Verifying complete installation..."

    bash "$SCRIPT_DIR/Scripts/verify.sh"


    # ------------------------------------------
    # Complete
    # ------------------------------------------

    echo

    success "=========================================="
    success "COMPLETE DEVOPS INSTALLATION FINISHED"
    success "=========================================="

    echo

    log "Complete DevOps installation completed."
}


# ==========================================
# Handle User Selection
# ==========================================

handle_choice() {

    local choice="$1"

    case "$choice" in

        1)

            info "Starting Health Check..."

            bash "$SCRIPT_DIR/Scripts/health-check.sh"

            ;;


        2)

            info "Starting Docker installation..."

            bash "$SCRIPT_DIR/Scripts/docker.sh"

            ;;


        3)

            info "Starting Kubernetes installation..."

            bash "$SCRIPT_DIR/Scripts/kubernetes.sh"

            ;;


        4)

            info "Starting Kubernetes cluster setup..."

            bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"

            ;;


        5)

            info "Starting Jenkins installation..."

            bash "$SCRIPT_DIR/Scripts/jenkins.sh"

            ;;


        6)

            info "Starting Prometheus installation..."

            bash "$SCRIPT_DIR/Scripts/prometheus.sh"

            ;;


        7)

            info "Starting Grafana installation..."

            bash "$SCRIPT_DIR/Scripts/grafana.sh"

            ;;


        8)

            install_everything

            ;;


        9)

            info "Starting installation verification..."

            bash "$SCRIPT_DIR/Scripts/verify.sh"

            ;;


        10)

            info "Starting DevOps uninstaller..."

            bash "$SCRIPT_DIR/Scripts/uninstall.sh"

            ;;


        0)

            echo

            success "Exiting DevOps Auto Installer."

            log "DevOps Auto Installer exited."

            exit 0

            ;;


        *)

            warning "Invalid option. Please choose a valid option."

            ;;

    esac
}


# ==========================================
# Main
# ==========================================

main() {

    # ------------------------------------------
    # Initialize Environment
    # ------------------------------------------

    initialize


    # ------------------------------------------
    # Log Start
    # ------------------------------------------

    log "=========================================="
    log "DevOps Auto Installer started."
    log "=========================================="


    # ------------------------------------------
    # Main Menu Loop
    # ------------------------------------------

    while true
    do

        show_header

        show_menu

        read -rp "Choose an option: " choice

        echo

        handle_choice "$choice"

        pause

    done
}


# ==========================================
# Start Installer
# ==========================================

main