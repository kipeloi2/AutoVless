#!/bin/bash

# Clean Installation Script
# Полная очистка и переустановка VPN сервера

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

clean_previous_installation() {
    print_status "Cleaning previous installation..."
    
    # Stop and disable service
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    
    # Remove files
    rm -rf /usr/local/etc/xray
    rm -rf /var/log/xray
    rm -f /etc/systemd/system/xray.service
    rm -f /usr/local/bin/xray
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Previous installation cleaned"
}

install_dependencies() {
    print_status "Installing dependencies..."
    
    apt update
    apt install -y curl wget unzip jq openssl uuid-runtime
    
    print_success "Dependencies installed"
}

download_and_install_xray() {
    print_status "Downloading and installing Xray..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="64" ;;
        aarch64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="arm32-v7a" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Download Xray
    cd /tmp
    wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/v1.8.8/Xray-linux-${ARCH}.zip"
    unzip -o xray.zip
    
    # Install Xray
    mkdir -p /usr/local/bin /usr/local/etc/xray /var/log/xray
    cp xray /usr/local/bin/
    chmod +x /usr/local/bin/xray
    
    # Set proper permissions
    chown -R nobody:nogroup /var/log/xray
    chmod 755 /var/log/xray
    
    # Create log files
    touch /var/log/xray/access.log /var/log/xray/error.log
    chown nobody:nogroup /var/log/xray/access.log /var/log/xray/error.log
    chmod 644 /var/log/xray/access.log /var/log/xray/error.log
    
    # Clean up
    rm -f xray.zip xray geoip.dat geosite.dat
    
    print_success "Xray installed"
}

generate_keys() {
    print_status "Generating keys..."
    
    # Generate UUID
    USER_UUID=$(uuidgen)
    
    # Generate Reality keys
    REALITY_OUTPUT=$(/usr/local/bin/xray x25519)
    PRIVATE_KEY=$(echo "$REALITY_OUTPUT" | grep "Private key:" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$REALITY_OUTPUT" | grep "Public key:" | awk '{print $3}')
    
    # Generate short ID
    SHORT_ID=$(openssl rand -hex 8)
    
    print_success "Keys generated"
    echo "UUID: $USER_UUID"
    echo "Private Key: $PRIVATE_KEY"
    echo "Public Key: $PUBLIC_KEY"
    echo "Short ID: $SHORT_ID"
}

create_config() {
    print_status "Creating configuration..."
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    
    cat > /usr/local/etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log"
    },
    "inbounds": [
        {
            "port": 443,
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
                    "dest": "www.microsoft.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.microsoft.com"
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
        }
    ]
}
EOF
    
    chmod 644 /usr/local/etc/xray/config.json
    
    print_success "Configuration created"
}

create_service() {
    print_status "Creating systemd service..."
    
    cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xray
    
    print_success "Service created"
}

test_and_start() {
    print_status "Testing configuration..."
    
    if /usr/local/bin/xray -test -config /usr/local/etc/xray/config.json; then
        print_success "Configuration is valid"
    else
        print_error "Configuration is invalid"
        exit 1
    fi
    
    print_status "Starting service..."
    systemctl start xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        systemctl status xray
        exit 1
    fi
}

save_client_info() {
    print_status "Saving client info..."
    
    SERVER_IP=$(curl -s ifconfig.me)
    
    cat > /usr/local/etc/xray/client-info.json << EOF
{
    "server_ip": "$SERVER_IP",
    "port": 443,
    "uuid": "$USER_UUID",
    "public_key": "$PUBLIC_KEY",
    "short_id": "$SHORT_ID",
    "server_name": "www.microsoft.com",
    "protocol": "vless",
    "security": "reality",
    "flow": "xtls-rprx-vision"
}
EOF
    
    print_success "Client info saved"
}

configure_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 443
        ufw --force enable
        print_success "Firewall configured"
    else
        print_warning "UFW not found, skipping firewall configuration"
    fi
}

show_result() {
    print_success "🎉 VPN installation completed!"
    echo
    
    SERVER_IP=$(curl -s ifconfig.me)
    VLESS_URL="vless://$USER_UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#Clean-Install-VPN"
    
    echo "Server: $SERVER_IP:443"
    echo "UUID: $USER_UUID"
    echo "Public Key: $PUBLIC_KEY"
    echo "Short ID: $SHORT_ID"
    echo
    echo "VLESS URL:"
    echo "$VLESS_URL"
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Clean VPN Installation                   ║"
    echo "║                  Full Clean and Reinstall                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    clean_previous_installation
    install_dependencies
    download_and_install_xray
    generate_keys
    create_config
    create_service
    configure_firewall
    test_and_start
    save_client_info
    show_result
}

main "$@"
