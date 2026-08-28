#!/bin/bash

# ==========================================
# DevOps Auto Installer
# Main Control Panel
# ==========================================

set -u

# ==========================================
# Script Directory
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/Scripts"

# ==========================================
# Load Common Functions
# ==========================================

source "$SCRIPTS_DIR/common.sh"

# ==========================================
# Check Whiptail
# ==========================================

check_whiptail() {

    if ! command -v whiptail >/dev/null 2>&1; then

        echo "Whiptail is required but not installed."
        echo

        read -rp "Install Whiptail now? (Y/n): " choice

        choice="${choice:-Y}"

        if [[ "$choice" =~ ^[Yy]$ ]]; then

            sudo apt-get update
            sudo apt-get install -y whiptail

        else

            echo "Whiptail is required to run this installer."
            exit 1

        fi

    fi
}

# ==========================================
# Run Script
# ==========================================

run_script() {

    local SCRIPT_NAME="$1"
    local SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT_NAME"

    if [[ ! -f "$SCRIPT_PATH" ]]; then

        whiptail \
            --title "File Not Found" \
            --msgbox \
            "The following script was not found:

$SCRIPT_PATH" \
            10 70

        return 1

    fi

    clear

    echo
    echo "=========================================="
    echo "      DEVOPS AUTO INSTALLER"
    echo "=========================================="
    echo

    info "Running: $SCRIPT_NAME"

    echo

    bash "$SCRIPT_PATH"

    local EXIT_CODE=$?

    echo

    if [[ "$EXIT_CODE" -eq 0 ]]; then

        success "$SCRIPT_NAME completed successfully."

    else

        error "$SCRIPT_NAME finished with errors."
        log "[ERROR] $SCRIPT_NAME exited with code $EXIT_CODE"

    fi

    echo
    read -rp "Press Enter to return to the main menu..."
}

# ==========================================
# Confirm Script
# ==========================================

confirm_and_run() {

    local TITLE="$1"
    local MESSAGE="$2"
    local SCRIPT_NAME="$3"

    if whiptail \
        --title "$TITLE" \
        --yesno \
        "$MESSAGE

Do you want to continue?" \
        15 70; then

        run_script "$SCRIPT_NAME"

    fi
}

# ==========================================
# Install Everything
# ==========================================

install_everything() {

    if ! whiptail \
        --title "Install Everything" \
        --yesno \
        "This will install and configure:

• Docker
• Kubernetes Components
• Kubernetes Cluster
• Jenkins
• Prometheus
• Grafana

The process may take several minutes.

Do you want to continue?" \
        20 70; then

        return

    fi

    clear

    echo
    echo "=========================================="
    echo "       COMPLETE DEVOPS INSTALLATION"
    echo "=========================================="
    echo

    log "[INFO] Starting complete DevOps installation."

    local INSTALL_SCRIPTS=(
        "docker.sh"
        "kubernetes.sh"
        "kubernetes-cluster.sh"
        "jenkins.sh"
        "prometheus.sh"
        "grafana.sh"
    )

    local TOTAL="${#INSTALL_SCRIPTS[@]}"
    local CURRENT=0

    for SCRIPT in "${INSTALL_SCRIPTS[@]}"
    do

        ((CURRENT+=1))

        clear

        echo
        echo "=========================================="
        echo " COMPLETE DEVOPS INSTALLATION"
        echo "=========================================="
        echo

        info "Step $CURRENT/$TOTAL"
        info "Running: $SCRIPT"

        echo

        log "[INFO] Step $CURRENT/$TOTAL: Starting $SCRIPT"

        if [[ ! -f "$SCRIPTS_DIR/$SCRIPT" ]]; then

            error "Required script not found: $SCRIPT"

            log "[ERROR] Required script missing: $SCRIPT"

            read -rp "Press Enter to return to the main menu..."

            return 1

        fi

        if bash "$SCRIPTS_DIR/$SCRIPT"; then

            echo

            success "Step $CURRENT/$TOTAL completed: $SCRIPT"

            log "[SUCCESS] Step $CURRENT/$TOTAL completed: $SCRIPT"

        else

            echo

            error "Installation failed at: $SCRIPT"

            log "[ERROR] Installation failed at: $SCRIPT"

            if whiptail \
                --title "Installation Failed" \
                --yesno \
                "Installation failed while running:

$SCRIPT

Do you want to continue with the remaining components?" \
                12 70; then

                continue

            else

                read -rp "Press Enter to return to the main menu..."

                return 1

            fi

        fi

        echo

        if [[ "$CURRENT" -lt "$TOTAL" ]]; then

            info "Moving to the next component..."

            sleep 2

        fi

    done

    # ==========================================
    # Final Verification
    # ==========================================

    clear

    echo
    echo "=========================================="
    echo "       FINAL INSTALLATION VERIFICATION"
    echo "=========================================="
    echo

    info "Running complete verification..."

    if [[ -f "$SCRIPTS_DIR/verify.sh" ]]; then

        bash "$SCRIPTS_DIR/verify.sh" || true

    else

        warning "verify.sh was not found."

    fi

    log "[SUCCESS] Complete DevOps installation finished."

    echo
    success "=========================================="
    success "COMPLETE INSTALLATION FINISHED"
    success "=========================================="
    echo

    read -rp "Press Enter to return to the main menu..."
}

# ==========================================
# View Installer Log
# ==========================================

view_installer_log() {

    if [[ -f "$LOG_FILE" ]]; then

        if [[ -s "$LOG_FILE" ]]; then

            whiptail \
                --title "Installer Log" \
                --textbox "$LOG_FILE" \
                25 100

        else

            whiptail \
                --title "Installer Log" \
                --msgbox "The installer log exists but no activity has been recorded yet." \
                10 70

        fi

    else

        whiptail \
            --title "Installer Log" \
            --msgbox "No installer log file was found yet." \
            10 70

    fi
}
# ==========================================
# Confirm Exit
# ==========================================

confirm_exit() {

    if whiptail \
        --title "Exit Installer" \
        --yesno \
        "Are you sure you want to exit the DevOps Auto Installer?" \
        10 60; then

        clear

        echo
        success "Thank you for using DevOps Auto Installer."
        echo

        log "[INFO] DevOps Auto Installer exited."

        exit 0

    fi
}

# ==========================================
# Main Menu
# ==========================================

show_main_menu() {

    while true
    do

        CHOICE=$(whiptail \
            --title "DevOps Auto Installer" \
            --menu \
            "Choose an option:" \
            25 75 15 \
            "1" "System Health Check" \
            "2" "Install Docker" \
            "3" "Install Kubernetes Components" \
            "4" "Setup Kubernetes Cluster" \
            "5" "Install Jenkins" \
            "6" "Install Prometheus" \
            "7" "Install Grafana" \
            "8" "Install Everything" \
            "9" "Verify Installation" \
            "10" "Uninstall Components" \
            "11" "View Installer Log" \
            "12" "Exit" \
            3>&1 1>&2 2>&3)

        EXIT_STATUS=$?

        # User pressed Cancel or ESC
        if [[ "$EXIT_STATUS" -ne 0 ]]; then

            confirm_exit

            continue

        fi

        case "$CHOICE" in

            1)
                run_script "health-check.sh"
                ;;

            2)
                confirm_and_run \
                    "Install Docker" \
                    "Docker Engine and Docker Compose will be installed." \
                    "docker.sh"
                ;;

            3)
                confirm_and_run \
                    "Install Kubernetes" \
                    "kubeadm, kubelet and kubectl will be installed." \
                    "kubernetes.sh"
                ;;

            4)
                confirm_and_run \
                    "Setup Kubernetes Cluster" \
                    "This will initialize and configure the Kubernetes cluster.

Make sure the required system resources are available." \
                    "kubernetes-cluster.sh"
                ;;

            5)
                confirm_and_run \
                    "Install Jenkins" \
                    "Java and Jenkins LTS will be installed.

Jenkins will be available on port 8080." \
                    "jenkins.sh"
                ;;

            6)
                confirm_and_run \
                    "Install Prometheus" \
                    "Prometheus monitoring server will be installed.

Prometheus will be available on port 9090." \
                    "prometheus.sh"
                ;;

            7)
                confirm_and_run \
                    "Install Grafana" \
                    "Grafana monitoring dashboard will be installed.

Grafana will be available on port 3000." \
                    "grafana.sh"
                ;;

            8)
                install_everything
                ;;

            9)
                run_script "verify.sh"
                ;;

            10)
                confirm_and_run \
                    "Uninstall Components" \
                    "WARNING!

This option may remove installed DevOps components and services.

Review the uninstall options carefully." \
                    "uninstall.sh"
                ;;

            11)
                view_installer_log
                ;;

            12)
                confirm_exit
                ;;

        esac

    done
}

# ==========================================
# Main
# ==========================================

main() {

    check_whiptail

    initialize

    log "[INFO] DevOps Auto Installer started."

    show_main_menu
}

# ==========================================
# Start Installer
# ==========================================

main