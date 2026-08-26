#!/bin/bash

# ==========================================
# DevOps Auto Installer - Whiptail UI
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/Scripts/common.sh"

# ==========================================
# Pause
# ==========================================

pause() {
    read -rp "Press Enter to continue..."
}

# ==========================================
# Run Script
# ==========================================

run_script() {

    local title="$1"
    local script="$2"

    clear

    echo
    echo "=========================================="
    echo " $title"
    echo "=========================================="
    echo

    bash "$script"

    echo
    pause
}

# ==========================================
# Install Everything
# ==========================================

install_everything() {

    clear

    echo
    echo "=========================================="
    echo " COMPLETE DEVOPS INSTALLATION"
    echo "=========================================="
    echo

    info "Step 1/7: Installing Docker..."
    bash "$SCRIPT_DIR/Scripts/docker.sh"

    info "Step 2/7: Installing Kubernetes..."
    bash "$SCRIPT_DIR/Scripts/kubernetes.sh"

    info "Step 3/7: Setting up Kubernetes Cluster..."
    bash "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"

    info "Step 4/7: Installing Jenkins..."
    bash "$SCRIPT_DIR/Scripts/jenkins.sh"

    info "Step 5/7: Installing Prometheus..."
    bash "$SCRIPT_DIR/Scripts/prometheus.sh"

    info "Step 6/7: Installing Grafana..."
    bash "$SCRIPT_DIR/Scripts/grafana.sh"

    info "Step 7/7: Verifying installation..."
    bash "$SCRIPT_DIR/Scripts/verify.sh"

    success "Complete DevOps installation finished."

    pause
}

# ==========================================
# Main Menu
# ==========================================

main_menu() {

    while true; do

        CHOICE=$(whiptail \
            --title "DevOps Auto Installer" \
            --backtitle "Docker | Kubernetes | Jenkins | Prometheus | Grafana" \
            --menu "Select an option:" \
            28 85 15 \
            "1"  "System Health Check" \
            "2"  "Install Docker" \
            "3"  "Install Kubernetes" \
            "4"  "Setup Kubernetes Cluster" \
            "5"  "Install Jenkins" \
            "6"  "Install Prometheus" \
            "7"  "Install Grafana" \
            "8"  "Install Everything" \
            "9"  "Verify Installation" \
            "10" "Uninstall Components" \
            "11" "View Installer Logs" \
            "0"  "Exit" \
            3>&1 1>&2 2>&3)

        EXIT_STATUS=$?

        if [[ $EXIT_STATUS -ne 0 ]]; then
            clear
            echo
            success "Exiting DevOps Auto Installer."
            echo
            exit 0
        fi

        case "$CHOICE" in

            1)
                run_script \
                    "SYSTEM HEALTH CHECK" \
                    "$SCRIPT_DIR/Scripts/health-check.sh"
                ;;

            2)
                run_script \
                    "INSTALLING DOCKER" \
                    "$SCRIPT_DIR/Scripts/docker.sh"
                ;;

            3)
                run_script \
                    "INSTALLING KUBERNETES" \
                    "$SCRIPT_DIR/Scripts/kubernetes.sh"
                ;;

            4)
                run_script \
                    "SETTING UP KUBERNETES CLUSTER" \
                    "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"
                ;;

            5)
                run_script \
                    "INSTALLING JENKINS" \
                    "$SCRIPT_DIR/Scripts/jenkins.sh"
                ;;

            6)
                run_script \
                    "INSTALLING PROMETHEUS" \
                    "$SCRIPT_DIR/Scripts/prometheus.sh"
                ;;

            7)
                run_script \
                    "INSTALLING GRAFANA" \
                    "$SCRIPT_DIR/Scripts/grafana.sh"
                ;;

            8)
                install_everything
                ;;

            9)
                run_script \
                    "VERIFYING INSTALLATION" \
                    "$SCRIPT_DIR/Scripts/verify.sh"
                ;;

            10)
                clear

                echo
                echo "=========================================="
                echo "          DEVOPS UNINSTALLER"
                echo "=========================================="
                echo

                bash "$SCRIPT_DIR/Scripts/uninstall.sh"

                echo
                read -rp "Press Enter to return to the main menu..."
                ;;

            11)
                clear

                echo
                echo "=========================================="
                echo "           INSTALLER LOG VIEWER"
                echo "=========================================="
                echo

                # Check possible log locations
                if [[ -f "$SCRIPT_DIR/installer.log" ]]; then

                    less "$SCRIPT_DIR/installer.log"

                elif [[ -f "$SCRIPT_DIR/installer.logs" ]]; then

                    less "$SCRIPT_DIR/installer.logs"

                elif [[ -f "$SCRIPT_DIR/logs/installer.log" ]]; then

                    less "$SCRIPT_DIR/logs/installer.log"

                else

                    warning "Installer log file not found."

                    echo
                    echo "Checked locations:"
                    echo "  $SCRIPT_DIR/installer.log"
                    echo "  $SCRIPT_DIR/installer.logs"
                    echo "  $SCRIPT_DIR/logs/installer.log"

                    echo
                    read -rp "Press Enter to return to the main menu..."

                fi
                ;;

            0)
                clear
                echo
                success "Exiting DevOps Auto Installer."
                echo
                exit 0
                ;;

        esac

    done
}

# ==========================================
# Start
# ==========================================

initialize

main_menu