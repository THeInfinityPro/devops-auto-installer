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
    echo "3. Install Jenkins"
    echo "4. Install Prometheus"
    echo "5. Install Grafana"
    echo
    echo "6. Install Everything"
    echo "7. Verify Installation"
    echo "8. Uninstall"
    echo
    echo "0. Exit"
    echo
}


# ==========================================
# Handle User Selection
# ==========================================

handle_choice() {

    local choice="$1"

    case "$choice" in

        1)
            info "Docker installer will be added in the next phase."
            ;;

        2)
            info "Kubernetes installer will be added in the next phase."
            ;;

        3)
            info "Jenkins installer will be added in the next phase."
            ;;

        4)
            info "Prometheus installer will be added in the next phase."
            ;;

        5)
            info "Grafana installer will be added in the next phase."
            ;;

        6)
            info "Complete installation will be added after all installers are created."
            ;;

        7)
            info "Verification module will be added later."
            ;;

        8)
            info "Uninstall module will be added later."
            ;;

        0)
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