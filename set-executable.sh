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

# Make main installer executable
if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
    chmod +x "$PROJECT_ROOT/install.sh"
    echo "[SUCCESS] install.sh"
else
    echo "[WARNING] install.sh not found."
fi

# Make all shell scripts inside Scripts executable
if [[ -d "$PROJECT_ROOT/Scripts" ]]; then

    while IFS= read -r -d '' file
    do
        chmod +x "$file"
        echo "[SUCCESS] ${file#$PROJECT_ROOT/}"
    done < <(find "$PROJECT_ROOT/Scripts" -type f -name "*.sh" -print0)

else
    echo "[WARNING] Scripts directory not found."
fi

echo
echo "=========================================="
echo "Executable permissions updated."
echo "=========================================="
echo