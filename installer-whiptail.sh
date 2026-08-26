#!/bin/bash

# ==========================================
# DevOps Auto Installer
# Whiptail Interactive UI
# ==========================================

set -e

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==========================================
# Load Common Functions
# ==========================================

source "$SCRIPT_DIR/Scripts/common.sh"


# ==========================================
# Check Whiptail
# ==========================================

check_whiptail() {

    if ! command -v whiptail >/dev/null 2>&1; then

        echo
        echo "Whiptail is not installed."
        echo "Installing Whiptail..."

        sudo apt-get update
        sudo apt-get install -y whiptail

    fi
}


# ==========================================
# Pause
# ==========================================

pause() {

    echo
    read -rp "Press Enter to continue..."
}


# ==========================================
# Run Script
# ==========================================

run_script() {

    local TITLE="$1"
    local SCRIPT="$2"

    clear

    echo
    echo "=========================================="
    echo " $TITLE"
    echo "=========================================="
    echo

    if [[ ! -f "$SCRIPT" ]]; then

        warning "Script not found:"
        echo "$SCRIPT"

        pause
        return

    fi

    bash "$SCRIPT"

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
    # Complete
    # ------------------------------------------

    echo

    success "=========================================="
    success "COMPLETE DEVOPS INSTALLATION FINISHED"
    success "=========================================="

    echo

    log "Complete DevOps installation completed."

    pause
}


# ==========================================
# Confirm Install Everything
# ==========================================

confirm_install_everything() {

    whiptail \
        --title "Install Everything" \
        --yesno \
        "This will install:

• Docker
• Kubernetes Components
• Kubernetes Cluster
• Jenkins
• Prometheus
• Grafana

Do you want to continue?" \
        18 65

    if [[ $? -eq 0 ]]; then

        install_everything

    fi
}


# ==========================================
# Install Components Menu
# ==========================================

install_menu() {

    while true; do

        CHOICE=$(whiptail \
            --title "Install Components" \
            --backtitle "DevOps Auto Installer" \
            --menu "Select a component to install:" \
            20 70 8 \
            "1" "Install Docker" \
            "2" "Install Kubernetes Components" \
            "3" "Install Jenkins" \
            "4" "Install Prometheus" \
            "5" "Install Grafana" \
            "0" "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        EXIT_STATUS=$?

        if [[ $EXIT_STATUS -ne 0 ]]; then
            return
        fi

        case "$CHOICE" in

            1)
                run_script \
                    "INSTALLING DOCKER" \
                    "$SCRIPT_DIR/Scripts/docker.sh"
                ;;

            2)
                run_script \
                    "INSTALLING KUBERNETES" \
                    "$SCRIPT_DIR/Scripts/kubernetes.sh"
                ;;

            3)
                run_script \
                    "INSTALLING JENKINS" \
                    "$SCRIPT_DIR/Scripts/jenkins.sh"
                ;;

            4)
                run_script \
                    "INSTALLING PROMETHEUS" \
                    "$SCRIPT_DIR/Scripts/prometheus.sh"
                ;;

            5)
                run_script \
                    "INSTALLING GRAFANA" \
                    "$SCRIPT_DIR/Scripts/grafana.sh"
                ;;

            0)
                return
                ;;

        esac

    done
}


# ==========================================
# Kubernetes Management Menu
# ==========================================

kubernetes_menu() {

    while true; do

        CHOICE=$(whiptail \
            --title "Kubernetes Management" \
            --backtitle "DevOps Auto Installer" \
            --menu "Select a Kubernetes operation:" \
            20 70 8 \
            "1" "Install Kubernetes Components" \
            "2" "Setup Kubernetes Cluster" \
            "3" "Check Kubernetes Cluster Status" \
            "4" "Check Kubernetes Nodes" \
            "0" "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        EXIT_STATUS=$?

        if [[ $EXIT_STATUS -ne 0 ]]; then
            return
        fi

        case "$CHOICE" in

            1)
                run_script \
                    "INSTALLING KUBERNETES" \
                    "$SCRIPT_DIR/Scripts/kubernetes.sh"
                ;;

            2)
                run_script \
                    "SETTING UP KUBERNETES CLUSTER" \
                    "$SCRIPT_DIR/Scripts/kubernetes-cluster.sh"
                ;;

            3)

                clear

                echo
                echo "=========================================="
                echo "       KUBERNETES CLUSTER STATUS"
                echo "=========================================="
                echo

                if command -v kubectl >/dev/null 2>&1; then

                    kubectl cluster-info 2>&1 || \
                        warning "Kubernetes cluster is not available."

                else

                    warning "kubectl is not installed."

                fi

                pause
                ;;

            4)

                clear

                echo
                echo "=========================================="
                echo "         KUBERNETES NODE STATUS"
                echo "=========================================="
                echo

                if command -v kubectl >/dev/null 2>&1; then

                    kubectl get nodes -o wide 2>&1 || \
                        warning "Unable to retrieve Kubernetes nodes."

                else

                    warning "kubectl is not installed."

                fi

                pause
                ;;

            0)
                return
                ;;

        esac

    done
}


# ==========================================
# Run Uninstaller
# ==========================================

run_uninstaller() {

    whiptail \
        --title "WARNING - DevOps Uninstaller" \
        --yesno \
        "You are about to open the DevOps Uninstaller.

This may remove:

• Docker
• Kubernetes
• Jenkins
• Prometheus
• Grafana

Continue?" \
        18 65

    if [[ $? -eq 0 ]]; then

        clear

        bash "$SCRIPT_DIR/Scripts/uninstall.sh"

        echo
        pause

    fi
}


# ==========================================
# View Installer Logs
# ==========================================

view_logs() {

    local LOG_FILE=""

    # Check possible log locations

    if [[ -f "$SCRIPT_DIR/installer.log" ]]; then

        LOG_FILE="$SCRIPT_DIR/installer.log"

    elif [[ -f "$SCRIPT_DIR/installer.logs" ]]; then

        LOG_FILE="$SCRIPT_DIR/installer.logs"

    elif [[ -f "$SCRIPT_DIR/logs/installer.log" ]]; then

        LOG_FILE="$SCRIPT_DIR/logs/installer.log"

    fi


    # No log file found

    if [[ -z "$LOG_FILE" ]]; then

        whiptail \
            --title "Installer Logs" \
            --msgbox \
            "Installer log file was not found.

Checked:

$SCRIPT_DIR/installer.log

$SCRIPT_DIR/installer.logs

$SCRIPT_DIR/logs/installer.log" \
            15 75

        return

    fi


    # Show log file

    whiptail \
        --title "Installer Logs" \
        --backtitle "DevOps Auto Installer" \
        --textbox "$LOG_FILE" \
        25 100
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
            24 75 12 \
            "1" "System Health Check" \
            "2" "Install Components" \
            "3" "Kubernetes Management" \
            "4" "Install Everything" \
            "5" "Verify Installation" \
            "6" "Uninstall Components" \
            "7" "View Installer Logs" \
            "0" "Exit" \
            3>&1 1>&2 2>&3)

        EXIT_STATUS=$?

        # ESC or Cancel

        if [[ $EXIT_STATUS -ne 0 ]]; then

            clear

            echo
            success "Exiting DevOps Auto Installer."
            echo

            exit 0

        fi


        case "$CHOICE" in

            # ----------------------------------
            # System Health Check
            # ----------------------------------

            1)

                run_script \
                    "SYSTEM HEALTH CHECK" \
                    "$SCRIPT_DIR/Scripts/health-check.sh"

                ;;


            # ----------------------------------
            # Install Components
            # ----------------------------------

            2)

                install_menu

                ;;


            # ----------------------------------
            # Kubernetes Management
            # ----------------------------------

            3)

                kubernetes_menu

                ;;


            # ----------------------------------
            # Install Everything
            # ----------------------------------

            4)

                confirm_install_everything

                ;;


            # ----------------------------------
            # Verify Installation
            # ----------------------------------

            5)

                run_script \
                    "VERIFYING DEVOPS INSTALLATION" \
                    "$SCRIPT_DIR/Scripts/verify.sh"

                ;;


            # ----------------------------------
            # Uninstall
            # ----------------------------------

            6)

                run_uninstaller

                ;;


            # ----------------------------------
            # View Logs
            # ----------------------------------

            7)

                view_logs

                ;;


            # ----------------------------------
            # Exit
            # ----------------------------------

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
# Initialize
# ==========================================

check_whiptail

initialize

log "DevOps Auto Installer Whiptail UI started."


# ==========================================
# Start Application
# ==========================================

main_menu