#!/bin/bash

# VPN Monitoring and Health Check Script
# Monitor VPN performance, connections, and system health

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
LOG_DIR="/var/log/xray"
MONITOR_LOG="/var/log/vpn-monitor.log"

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

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

get_service_status() {
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}●${NC} Running"
        return 0
    else
        echo -e "${RED}●${NC} Stopped"
        return 1
    fi
}

get_port_info() {
    local port=$(jq -r '.inbounds[0].port' "$CONFIG_DIR/config.json" 2>/dev/null || echo "443")
    echo "$port"
}

get_active_connections() {
    local port=$(get_port_info)
    netstat -an 2>/dev/null | grep ":$port " | grep ESTABLISHED | wc -l
}

get_total_connections() {
    local port=$(get_port_info)
    netstat -an 2>/dev/null | grep ":$port " | wc -l
}

get_system_load() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','
}

get_memory_usage() {
    free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}'
}

get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | tr -d '%'
}

get_network_stats() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$interface" ]]; then
        local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
        local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")
        
        # Convert to MB
        local rx_mb=$((rx_bytes / 1024 / 1024))
        local tx_mb=$((tx_bytes / 1024 / 1024))
        
        echo "RX: ${rx_mb}MB, TX: ${tx_mb}MB"
    else
        echo "N/A"
    fi
}

check_xray_process() {
    if pgrep -x "xray" > /dev/null; then
        local pid=$(pgrep -x "xray")
        local cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
        local mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ' || echo "0")
        echo -e "${GREEN}●${NC} PID: $pid, CPU: ${cpu}%, MEM: ${mem}%"
        return 0
    else
        echo -e "${RED}●${NC} Not running"
        return 1
    fi
}

check_port_listening() {
    local port=$(get_port_info)
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}●${NC} Port $port is listening"
        return 0
    else
        echo -e "${RED}●${NC} Port $port is not listening"
        return 1
    fi
}

check_config_validity() {
    if /usr/local/bin/xray -test -config "$CONFIG_DIR/config.json" &>/dev/null; then
        echo -e "${GREEN}●${NC} Configuration is valid"
        return 0
    else
        echo -e "${RED}●${NC} Configuration has errors"
        return 1
    fi
}

check_log_errors() {
    local error_count=0
    
    if [[ -f "$LOG_DIR/error.log" ]]; then
        error_count=$(grep -c "ERROR\|FATAL" "$LOG_DIR/error.log" 2>/dev/null || echo "0")
    fi
    
    if [[ $error_count -gt 0 ]]; then
        echo -e "${YELLOW}●${NC} $error_count errors in logs"
        return 1
    else
        echo -e "${GREEN}●${NC} No errors in logs"
        return 0
    fi
}

test_connectivity() {
    local server_ip=$(jq -r '.server_ip' "$CONFIG_DIR/client-info.json" 2>/dev/null || curl -s ifconfig.me)
    local port=$(get_port_info)
    
    print_status "Testing connectivity to $server_ip:$port..."
    
    if timeout 5 bash -c "</dev/tcp/$server_ip/$port" 2>/dev/null; then
        print_success "Port $port is accessible"
        return 0
    else
        print_error "Port $port is not accessible"
        return 1
    fi
}

show_dashboard() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      VPN Monitor Dashboard                   ║"
    echo "║                    $(date '+%Y-%m-%d %H:%M:%S')                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Service Status
    echo -e "${PURPLE}Service Status:${NC}"
    echo "  Xray Service: $(get_service_status)"
    echo "  Xray Process: $(check_xray_process)"
    echo "  Port Status:  $(check_port_listening)"
    echo "  Config Valid: $(check_config_validity)"
    echo "  Log Status:   $(check_log_errors)"
    echo
    
    # Connection Stats
    echo -e "${PURPLE}Connection Statistics:${NC}"
    echo "  Active Connections: $(get_active_connections)"
    echo "  Total Connections:  $(get_total_connections)"
    echo "  Listening Port:     $(get_port_info)"
    echo
    
    # System Resources
    echo -e "${PURPLE}System Resources:${NC}"
    echo "  Load Average:  $(get_system_load)"
    echo "  Memory Usage:  $(get_memory_usage)%"
    echo "  Disk Usage:    $(get_disk_usage)%"
    echo "  Network Stats: $(get_network_stats)"
    echo
    
    # Recent Activity
    echo -e "${PURPLE}Recent Activity:${NC}"
    if [[ -f "$LOG_DIR/access.log" ]]; then
        echo "  Last 3 connections:"
        tail -n 3 "$LOG_DIR/access.log" 2>/dev/null | while read -r line; do
            echo "    $line"
        done
    else
        echo "  No access logs available"
    fi
    echo
    
    # Uptime
    echo -e "${PURPLE}System Information:${NC}"
    echo "  System Uptime: $(uptime -p)"
    if systemctl is-active --quiet xray; then
        local start_time=$(systemctl show xray --property=ActiveEnterTimestamp --value)
        echo "  Service Uptime: Since $start_time"
    fi
}

run_health_check() {
    print_status "Running comprehensive health check..."
    echo
    
    local issues=0
    
    # Check service status
    if ! systemctl is-active --quiet xray; then
        print_error "Xray service is not running"
        ((issues++))
    else
        print_success "Xray service is running"
    fi
    
    # Check process
    if ! pgrep -x "xray" > /dev/null; then
        print_error "Xray process not found"
        ((issues++))
    else
        print_success "Xray process is active"
    fi
    
    # Check port
    local port=$(get_port_info)
    if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        print_error "Port $port is not listening"
        ((issues++))
    else
        print_success "Port $port is listening"
    fi
    
    # Check configuration
    if ! /usr/local/bin/xray -test -config "$CONFIG_DIR/config.json" &>/dev/null; then
        print_error "Configuration file has errors"
        ((issues++))
    else
        print_success "Configuration is valid"
    fi
    
    # Check connectivity
    if ! test_connectivity; then
        print_error "External connectivity test failed"
        ((issues++))
    else
        print_success "External connectivity test passed"
    fi
    
    # Check disk space
    local disk_usage=$(get_disk_usage)
    if [[ $disk_usage -gt 90 ]]; then
        print_warning "Disk usage is high: ${disk_usage}%"
        ((issues++))
    else
        print_success "Disk usage is normal: ${disk_usage}%"
    fi
    
    # Check memory
    local mem_usage=$(get_memory_usage)
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        print_warning "Memory usage is high: ${mem_usage}%"
        ((issues++))
    else
        print_success "Memory usage is normal: ${mem_usage}%"
    fi
    
    echo
    if [[ $issues -eq 0 ]]; then
        print_success "All health checks passed! VPN is running optimally."
        log_message "Health check passed - no issues found"
    else
        print_warning "Found $issues issue(s) that need attention."
        log_message "Health check found $issues issues"
    fi
    
    return $issues
}

monitor_realtime() {
    print_status "Starting real-time monitoring (Press Ctrl+C to stop)..."
    echo
    
    while true; do
        show_dashboard
        
        echo -e "${CYAN}Press Ctrl+C to stop monitoring...${NC}"
        sleep 5
    done
}

generate_report() {
    local report_file="/root/vpn-report-$(date +%Y%m%d-%H%M%S).txt"
    
    print_status "Generating detailed report..."
    
    {
        echo "VPN Server Health Report"
        echo "======================="
        echo "Generated: $(date)"
        echo "Server: $(hostname)"
        echo
        
        echo "Service Status:"
        echo "  Xray Service: $(systemctl is-active xray)"
        echo "  Process ID: $(pgrep -x xray || echo 'Not running')"
        echo "  Configuration: $(/usr/local/bin/xray -test -config "$CONFIG_DIR/config.json" &>/dev/null && echo 'Valid' || echo 'Invalid')"
        echo
        
        echo "System Resources:"
        echo "  Load Average: $(get_system_load)"
        echo "  Memory Usage: $(get_memory_usage)%"
        echo "  Disk Usage: $(get_disk_usage)%"
        echo "  Network: $(get_network_stats)"
        echo
        
        echo "Connection Statistics:"
        echo "  Active Connections: $(get_active_connections)"
        echo "  Total Connections: $(get_total_connections)"
        echo "  Listening Port: $(get_port_info)"
        echo
        
        echo "Recent Logs (Last 20 entries):"
        if [[ -f "$LOG_DIR/access.log" ]]; then
            tail -n 20 "$LOG_DIR/access.log"
        else
            echo "  No access logs available"
        fi
        
        echo
        echo "Error Logs (Last 10 entries):"
        if [[ -f "$LOG_DIR/error.log" ]]; then
            tail -n 10 "$LOG_DIR/error.log"
        else
            echo "  No error logs available"
        fi
        
    } > "$report_file"
    
    print_success "Report saved to: $report_file"
}

show_help() {
    echo -e "${BLUE}VPN Monitoring Tool${NC}"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  dashboard       Show real-time dashboard"
    echo "  health          Run comprehensive health check"
    echo "  monitor         Start real-time monitoring"
    echo "  report          Generate detailed report"
    echo "  connectivity    Test external connectivity"
    echo "  stats           Show current statistics"
    echo "  help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 dashboard"
    echo "  $0 health"
    echo "  $0 monitor"
}

main() {
    case "${1:-dashboard}" in
        "dashboard")
            show_dashboard
            ;;
        "health")
            run_health_check
            ;;
        "monitor")
            monitor_realtime
            ;;
        "report")
            generate_report
            ;;
        "connectivity")
            test_connectivity
            ;;
        "stats")
            echo "Active Connections: $(get_active_connections)"
            echo "Total Connections: $(get_total_connections)"
            echo "System Load: $(get_system_load)"
            echo "Memory Usage: $(get_memory_usage)%"
            echo "Disk Usage: $(get_disk_usage)%"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
