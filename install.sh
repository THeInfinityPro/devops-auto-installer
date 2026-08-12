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

    echo "1. Install Docker"
    echo "2. Install Kubernetes"
    echo "3. Setup Kubernetes Cluster"
    echo "4. Install Jenkins"
    echo "5. Install Prometheus"
    echo "6. Install Grafana"
    echo
    echo "7. Install Everything"
    echo "8. Verify Installation"
    echo "9. Uninstall"
    echo
    echo "10. Exit"
    echo
}

# ==========================================
# Handle User Selection
# ==========================================

handle_choice() {

    local choice="$1"

    case "$choice" in

        1)
            bash "$SCRIPT_DIR/Scripts/docker.sh"
            ;;

        2)
            bash "$SCRIPT_DIR/Scripts/kubernetes.sh"
            ;;

        3)
            bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"
            ;;

        4)
            bash "$SCRIPT_DIR/Scripts/jenkins.sh"
            ;;

        5)
            bash "$SCRIPT_DIR/Scripts/prometheus.sh"
            ;;

        6)
            bash "$SCRIPT_DIR/Scripts/grafana.sh"
            ;;

        7)
            install_everything
            ;;

        8)
            bash "$SCRIPT_DIR/Scripts/verify.sh"
            ;;

        9)
            warning "Uninstall script has not been created yet."
            ;;

        10)
            echo
            success "Exiting DevOps Auto Installer."
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