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

    echo "  INSTALLATION"
    echo "------------------------------------------"
    echo "1. Install Docker"
    echo "2. Install Kubernetes"
    echo "3. Setup Kubernetes Cluster"
    echo "4. Install Jenkins"
    echo "5. Install Prometheus"
    echo "6. Install Grafana"
    echo

    echo "  MANAGEMENT"
    echo "------------------------------------------"
    echo "7. Install Everything"
    echo "8. Verify Installation"
    echo "9. Health Check"
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
    # Step 1 - Docker
    # ------------------------------------------

    info "Step 1/7: Installing Docker..."

    bash "$SCRIPT_DIR/Scripts/docker.sh"

    success "Docker installation completed."


    # ------------------------------------------
    # Step 2 - Kubernetes Components
    # ------------------------------------------

    info "Step 2/7: Installing Kubernetes components..."

    bash "$SCRIPT_DIR/Scripts/kubernetes.sh"

    success "Kubernetes component installation completed."


    # ------------------------------------------
    # Step 3 - Kubernetes Cluster
    # ------------------------------------------

    info "Step 3/7: Setting up Kubernetes cluster..."

    bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"

    success "Kubernetes cluster setup completed."


    # ------------------------------------------
    # Step 4 - Jenkins
    # ------------------------------------------

    info "Step 4/7: Installing Jenkins..."

    bash "$SCRIPT_DIR/Scripts/jenkins.sh"

    success "Jenkins installation completed."


    # ------------------------------------------
    # Step 5 - Prometheus
    # ------------------------------------------

    info "Step 5/7: Installing Prometheus..."

    bash "$SCRIPT_DIR/Scripts/prometheus.sh"

    success "Prometheus installation completed."


    # ------------------------------------------
    # Step 6 - Grafana
    # ------------------------------------------

    info "Step 6/7: Installing Grafana..."

    bash "$SCRIPT_DIR/Scripts/grafana.sh"

    success "Grafana installation completed."


    # ------------------------------------------
    # Step 7 - Verification
    # ------------------------------------------

    info "Step 7/7: Verifying complete installation..."

    bash "$SCRIPT_DIR/Scripts/verify.sh"


    # ------------------------------------------
    # Installation Complete
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

        # --------------------------------------
        # Install Docker
        # --------------------------------------

        1)
            bash "$SCRIPT_DIR/Scripts/docker.sh"
            ;;


        # --------------------------------------
        # Install Kubernetes
        # --------------------------------------

        2)
            bash "$SCRIPT_DIR/Scripts/kubernetes.sh"
            ;;


        # --------------------------------------
        # Setup Kubernetes Cluster
        # --------------------------------------

        3)
            bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"
            ;;


        # --------------------------------------
        # Install Jenkins
        # --------------------------------------

        4)
            bash "$SCRIPT_DIR/Scripts/jenkins.sh"
            ;;


        # --------------------------------------
        # Install Prometheus
        # --------------------------------------

        5)
            bash "$SCRIPT_DIR/Scripts/prometheus.sh"
            ;;


        # --------------------------------------
        # Install Grafana
        # --------------------------------------

        6)
            bash "$SCRIPT_DIR/Scripts/grafana.sh"
            ;;


        # --------------------------------------
        # Install Everything
        # --------------------------------------

        7)
            install_everything
            ;;


        # --------------------------------------
        # Verify Installation
        # --------------------------------------

        8)
            bash "$SCRIPT_DIR/Scripts/verify.sh"
            ;;


        # --------------------------------------
        # Health Check
        # --------------------------------------

        9)
            bash "$SCRIPT_DIR/Scripts/health-check.sh"
            ;;


        # --------------------------------------
        # Uninstall
        # --------------------------------------

        10)
            bash "$SCRIPT_DIR/Scripts/uninstall.sh"
            ;;


        # --------------------------------------
        # Exit
        # --------------------------------------

        0)
            echo
            success "Exiting DevOps Auto Installer."
            exit 0
            ;;


        # --------------------------------------
        # Invalid Option
        # --------------------------------------

        *)
            warning "Invalid option. Please choose a valid option."
            ;;

    esac
}


# ==========================================
# Main Function
# ==========================================

main() {

    reset_log

    initialize

    log "DevOps Auto Installer started."

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