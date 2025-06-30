#!/bin/bash

# Fix Installation Script
# Исправляет проблемы с установкой VPN сервера

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

stop_service() {
    print_status "Stopping Xray service..."
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
}

generate_proper_keys() {
    print_status "Generating proper Reality keys..."
    
    # Generate UUID for user
    USER_UUID=$(uuidgen)
    
    # Generate Reality keys using Xray
    if command -v /usr/local/bin/xray &> /dev/null; then
        print_status "Using Xray to generate Reality keys..."
        REALITY_OUTPUT=$(/usr/local/bin/xray x25519 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$REALITY_OUTPUT" ]]; then
            PRIVATE_KEY=$(echo "$REALITY_OUTPUT" | grep "Private key:" | awk '{print $3}')
            PUBLIC_KEY=$(echo "$REALITY_OUTPUT" | grep "Public key:" | awk '{print $3}')
        else
            print_warning "Xray x25519 failed, using alternative method..."
            generate_keys_alternative
        fi
    else
        print_warning "Xray not found, using alternative method..."
        generate_keys_alternative
    fi
    
    # Generate short ID
    SHORT_ID=$(openssl rand -hex 8)
    
    # Validate keys
    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" || -z "$SHORT_ID" || -z "$USER_UUID" ]]; then
        print_error "Failed to generate valid keys"
        print_error "Private Key: ${PRIVATE_KEY:-EMPTY}"
        print_error "Public Key: ${PUBLIC_KEY:-EMPTY}"
        print_error "Short ID: ${SHORT_ID:-EMPTY}"
        print_error "UUID: ${USER_UUID:-EMPTY}"
        exit 1
    fi
    
    print_success "Keys generated successfully:"
    print_status "UUID: $USER_UUID"
    print_status "Private Key: $PRIVATE_KEY"
    print_status "Public Key: $PUBLIC_KEY"
    print_status "Short ID: $SHORT_ID"
}

generate_keys_alternative() {
    print_status "Using alternative key generation method..."
    
    # Method 1: Try with simple base64 encoding
    TEMP_PRIVATE=$(openssl rand -base64 32)
    TEMP_PUBLIC=$(openssl rand -base64 32)
    
    # Ensure they are valid base64 and correct length
    PRIVATE_KEY=$(echo "$TEMP_PRIVATE" | tr -d '\n' | head -c 43)
    PUBLIC_KEY=$(echo "$TEMP_PUBLIC" | tr -d '\n' | head -c 43)
    
    # Add padding if needed
    while [[ ${#PRIVATE_KEY} -lt 44 ]]; do
        PRIVATE_KEY="${PRIVATE_KEY}="
    done
    
    while [[ ${#PUBLIC_KEY} -lt 44 ]]; do
        PUBLIC_KEY="${PUBLIC_KEY}="
    done
}

create_fixed_config() {
    print_status "Creating corrected Xray configuration..."
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "127.0.0.1")
    
    # Default settings
    VPN_PORT=${VPN_PORT:-443}
    DEST_SITE=${DEST_SITE:-"www.microsoft.com:443"}
    SERVER_NAME=${SERVER_NAME:-"www.microsoft.com"}
    
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "$LOG_DIR/access.log",
        "error": "$LOG_DIR/error.log"
    },
    "inbounds": [
        {
            "port": $VPN_PORT,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$USER_UUID",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$DEST_SITE",
                    "xver": 0,
                    "serverNames": [
                        "$SERVER_NAME"
                    ],
                    "privateKey": "$PRIVATE_KEY",
                    "shortIds": [
                        "$SHORT_ID"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "blocked"
            }
        ]
    }
}
EOF
    
    # Set proper permissions
    chown -R nobody:nogroup "$CONFIG_DIR" "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$LOG_DIR"
    chmod 644 "$CONFIG_DIR/config.json"

    # Create log files with proper permissions
    touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chown nobody:nogroup "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chmod 644 "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    
    print_success "Configuration created successfully"
}

test_and_start_service() {
    print_status "Testing configuration..."
    
    if /usr/local/bin/xray -test -config "$CONFIG_DIR/config.json"; then
        print_success "Configuration is valid"
    else
        print_error "Configuration is still invalid!"
        print_error "Configuration content:"
        cat "$CONFIG_DIR/config.json"
        exit 1
    fi
    
    print_status "Starting Xray service..."
    
    systemctl enable xray
    systemctl start xray
    sleep 3
    
    if systemctl is-active --quiet xray; then
        print_success "Xray service started successfully"
    else
        print_error "Failed to start Xray service"
        print_error "Service status:"
        systemctl status xray --no-pager -l
        print_error "Configuration test:"
        /usr/local/bin/xray -test -config "$CONFIG_DIR/config.json"
        exit 1
    fi
}

save_client_info() {
    print_status "Saving client configuration..."
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "127.0.0.1")
    
    cat > "$CONFIG_DIR/client-info.json" << EOF
{
    "server_ip": "$SERVER_IP",
    "port": $VPN_PORT,
    "uuid": "$USER_UUID",
    "public_key": "$PUBLIC_KEY",
    "short_id": "$SHORT_ID",
    "server_name": "$SERVER_NAME",
    "protocol": "vless",
    "security": "reality",
    "flow": "xtls-rprx-vision"
}
EOF
    
    print_success "Client information saved"
}

show_final_info() {
    print_success "🎉 VPN installation fixed successfully!"
    echo
    
    # Get server info
    local server_ip=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Connection Information                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}Server:${NC} $server_ip:$VPN_PORT"
    echo -e "${GREEN}Protocol:${NC} VLESS + Reality"
    echo -e "${GREEN}UUID:${NC} $USER_UUID"
    echo -e "${GREEN}Public Key:${NC} $PUBLIC_KEY"
    echo -e "${GREEN}Short ID:${NC} $SHORT_ID"
    echo -e "${GREEN}Server Name:${NC} $SERVER_NAME"
    echo
    
    # Generate VLESS URL
    local vless_url="vless://$USER_UUID@$server_ip:$VPN_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#Fixed-VPN"
    
    echo -e "${YELLOW}VLESS URL for mobile apps:${NC}"
    echo "$vless_url"
    echo
    
    print_status "Use './generate-client-config.sh show' to see all configurations"
    print_status "Use './vpn-manager.sh status' to check service status"
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    VPN Installation Fix                     ║"
    echo "║                  Fixing Reality Key Issues                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    stop_service
    generate_proper_keys
    create_fixed_config
    test_and_start_service
    save_client_info
    show_final_info
}

# Run main function
main "$@"
