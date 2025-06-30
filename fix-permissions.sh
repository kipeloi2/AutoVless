#!/bin/bash

# Quick Permission Fix Script
# Исправляет права доступа для Xray логов

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
LOG_DIR="/var/log/xray"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

fix_permissions() {
    print_status "Fixing file permissions..."
    
    # Create directories if they don't exist
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    
    # Set directory permissions
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Set ownership
    chown -R nobody:nogroup "$LOG_DIR"
    chown root:root "$CONFIG_DIR"
    
    # Create log files with proper permissions
    touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chown nobody:nogroup "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chmod 644 "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    
    # Fix config file permissions
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        chmod 644 "$CONFIG_DIR/config.json"
        chown root:root "$CONFIG_DIR/config.json"
    fi
    
    print_success "Permissions fixed"
}

restart_service() {
    print_status "Restarting Xray service..."
    
    systemctl stop xray 2>/dev/null || true
    sleep 1
    systemctl start xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "Xray service started successfully"
    else
        print_error "Failed to start Xray service"
        systemctl status xray --no-pager -l
        exit 1
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Permission Fix Tool                      ║"
    echo "║                 Fixing Xray Log Permissions                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    fix_permissions
    restart_service
    
    print_success "🎉 Permissions fixed! Xray should now work properly."
}

main "$@"
