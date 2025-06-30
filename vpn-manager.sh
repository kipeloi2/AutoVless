#!/bin/bash

# VPN Service Manager
# Manage Xray VPN service with ease

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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

show_status() {
    print_status "Checking VPN service status..."
    echo
    
    if systemctl is-active --quiet xray; then
        print_success "✓ Xray service is running"
        echo "  Status: $(systemctl is-active xray)"
        echo "  Uptime: $(systemctl show xray --property=ActiveEnterTimestamp --value | cut -d' ' -f2-)"
    else
        print_error "✗ Xray service is not running"
        echo "  Status: $(systemctl is-active xray)"
    fi
    
    echo
    print_status "Service details:"
    systemctl status xray --no-pager -l
    
    echo
    print_status "Network connections:"
    netstat -tlnp | grep xray || echo "No active connections found"
    
    echo
    print_status "Recent logs:"
    journalctl -u xray --no-pager -n 10
}

start_service() {
    print_status "Starting VPN service..."
    
    if systemctl is-active --quiet xray; then
        print_warning "Service is already running"
        return
    fi
    
    systemctl start xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "VPN service started successfully"
    else
        print_error "Failed to start VPN service"
        journalctl -u xray --no-pager -n 20
        exit 1
    fi
}

stop_service() {
    print_status "Stopping VPN service..."
    
    if ! systemctl is-active --quiet xray; then
        print_warning "Service is already stopped"
        return
    fi
    
    systemctl stop xray
    sleep 1
    
    if ! systemctl is-active --quiet xray; then
        print_success "VPN service stopped successfully"
    else
        print_error "Failed to stop VPN service"
        exit 1
    fi
}

restart_service() {
    print_status "Restarting VPN service..."
    
    systemctl restart xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "VPN service restarted successfully"
    else
        print_error "Failed to restart VPN service"
        journalctl -u xray --no-pager -n 20
        exit 1
    fi
}

reload_config() {
    print_status "Reloading VPN configuration..."
    
    # Test configuration first
    if /usr/local/bin/xray -test -config "$CONFIG_DIR/config.json"; then
        print_success "Configuration is valid"
        systemctl reload xray
        print_success "Configuration reloaded successfully"
    else
        print_error "Configuration is invalid. Please check your config file."
        exit 1
    fi
}

show_logs() {
    local lines=${1:-50}
    print_status "Showing last $lines log entries..."
    echo
    
    if [[ -f "$LOG_DIR/error.log" ]]; then
        echo -e "${RED}=== Error Logs ===${NC}"
        tail -n "$lines" "$LOG_DIR/error.log"
        echo
    fi
    
    if [[ -f "$LOG_DIR/access.log" ]]; then
        echo -e "${GREEN}=== Access Logs ===${NC}"
        tail -n "$lines" "$LOG_DIR/access.log"
        echo
    fi
    
    echo -e "${BLUE}=== System Logs ===${NC}"
    journalctl -u xray --no-pager -n "$lines"
}

show_config() {
    print_status "Current VPN configuration:"
    echo
    
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        cat "$CONFIG_DIR/config.json" | jq '.'
    else
        print_error "Configuration file not found"
        exit 1
    fi
}

show_client_info() {
    print_status "Client connection information:"
    echo
    
    if [[ -f "$CONFIG_DIR/client-info.json" ]]; then
        local info=$(cat "$CONFIG_DIR/client-info.json")
        local server_ip=$(echo "$info" | jq -r '.server_ip')
        local port=$(echo "$info" | jq -r '.port')
        local uuid=$(echo "$info" | jq -r '.uuid')
        local public_key=$(echo "$info" | jq -r '.public_key')
        local short_id=$(echo "$info" | jq -r '.short_id')
        local server_name=$(echo "$info" | jq -r '.server_name')
        
        echo "Server IP: $server_ip"
        echo "Port: $port"
        echo "UUID: $uuid"
        echo "Public Key: $public_key"
        echo "Short ID: $short_id"
        echo "Server Name: $server_name"
        echo
        
        local vless_url="vless://$uuid@$server_ip:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#VPN-Reality"
        echo "VLESS URL:"
        echo "$vless_url"
    else
        print_error "Client info file not found"
        exit 1
    fi
}

monitor_traffic() {
    print_status "Monitoring VPN traffic (Press Ctrl+C to stop)..."
    echo
    
    # Monitor network traffic on the VPN port
    local port=$(jq -r '.inbounds[0].port' "$CONFIG_DIR/config.json")
    
    print_status "Monitoring port $port..."
    
    while true; do
        local connections=$(netstat -an | grep ":$port " | wc -l)
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo "[$timestamp] Active connections: $connections"
        
        # Show recent access logs if available
        if [[ -f "$LOG_DIR/access.log" ]]; then
            local recent_access=$(tail -n 1 "$LOG_DIR/access.log" 2>/dev/null || echo "No recent access")
            echo "  Last access: $recent_access"
        fi
        
        sleep 5
    done
}

backup_config() {
    local backup_dir="/root/vpn-backup-$(date +%Y%m%d-%H%M%S)"
    print_status "Creating backup in $backup_dir..."
    
    mkdir -p "$backup_dir"
    cp -r "$CONFIG_DIR" "$backup_dir/"
    
    if [[ -d "$LOG_DIR" ]]; then
        cp -r "$LOG_DIR" "$backup_dir/"
    fi
    
    print_success "Backup created successfully in $backup_dir"
}

show_help() {
    echo -e "${BLUE}VPN Service Manager${NC}"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  status      Show service status and details"
    echo "  start       Start the VPN service"
    echo "  stop        Stop the VPN service"
    echo "  restart     Restart the VPN service"
    echo "  reload      Reload configuration without stopping service"
    echo "  logs [N]    Show last N log entries (default: 50)"
    echo "  config      Show current configuration"
    echo "  client      Show client connection information"
    echo "  monitor     Monitor VPN traffic in real-time"
    echo "  backup      Create configuration backup"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs 100"
    echo "  $0 restart"
}

main() {
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "start")
            check_root
            start_service
            ;;
        "stop")
            check_root
            stop_service
            ;;
        "restart")
            check_root
            restart_service
            ;;
        "reload")
            check_root
            reload_config
            ;;
        "logs")
            show_logs "${2:-50}"
            ;;
        "config")
            show_config
            ;;
        "client")
            show_client_info
            ;;
        "monitor")
            monitor_traffic
            ;;
        "backup")
            check_root
            backup_config
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
