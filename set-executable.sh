#!/bin/bash

# ==========================================
# DevOps Auto Installer
# Set Executable Permissions
# ==========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "=========================================="
echo "     SET EXECUTABLE PERMISSIONS"
echo "=========================================="
echo

echo "[INFO] Project root:"
echo "$PROJECT_ROOT"
echo

# ==========================================
# Main Project Scripts
# ==========================================

echo "[INFO] Updating main project scripts..."
echo

MAIN_SCRIPTS=(
    "install.sh"
    "installer-whiptail.sh"
    "installer-backup.sh"
    "set-executable.sh"
)

for script in "${MAIN_SCRIPTS[@]}"
do

    FILE="$PROJECT_ROOT/$script"

    if [[ -f "$FILE" ]]; then

        chmod +x "$FILE"

        echo "[SUCCESS] $script"

    else

        echo "[INFO] $script not found. Skipping."

    fi

done

# ==========================================
# Scripts Directory
# ==========================================

echo
echo "[INFO] Updating Scripts directory..."
echo

if [[ -d "$PROJECT_ROOT/Scripts" ]]; then

    while IFS= read -r -d '' file
    do

        chmod +x "$file"

        echo "[SUCCESS] ${file#$PROJECT_ROOT/}"

    done < <(
        find "$PROJECT_ROOT/Scripts" \
        -type f \
        -name "*.sh" \
        -print0
    )

else

    echo "[WARNING] Scripts directory not found."

fi

# ==========================================
# Verify Permissions
# ==========================================

echo
echo "[INFO] Verifying executable permissions..."
echo

NOT_EXECUTABLE=0

while IFS= read -r -d '' file
do

    if [[ -x "$file" ]]; then

        echo "[SUCCESS] Executable: ${file#$PROJECT_ROOT/}"

    else

        echo "[WARNING] Not executable: ${file#$PROJECT_ROOT/}"

        NOT_EXECUTABLE=1

    fi

done < <(
    find "$PROJECT_ROOT" \
    -type f \
    -name "*.sh" \
    -print0
)

# ==========================================
# Complete
# ==========================================

echo

if [[ "$NOT_EXECUTABLE" -eq 0 ]]; then

    echo "=========================================="
    echo "[SUCCESS] ALL SCRIPT PERMISSIONS UPDATED"
    echo "=========================================="

else

    echo "=========================================="
    echo "[WARNING] SOME SCRIPTS ARE NOT EXECUTABLE"
    echo "=========================================="

fi

echo