#!/bin/bash

# VPN Auto-Setup Script for Ubuntu 24.04.02
# Supports VLESS + Reality protocol for maximum stealth
# Author: VPN Auto-Setup Tool

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
XRAY_VERSION="1.8.8"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/xray"
LOG_DIR="/var/log/xray"
SERVICE_FILE="/etc/systemd/system/xray.service"

# Default settings
DEFAULT_PORT=443
DEFAULT_DEST_SITE="www.microsoft.com:443"
DEFAULT_SERVER_NAME="www.microsoft.com"

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

check_system() {
    print_status "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        print_warning "This script is optimized for Ubuntu 24.04, but will try to continue..."
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection available"
        exit 1
    fi
    
    print_success "System check passed"
}

install_dependencies() {
    print_status "Installing dependencies..."
    
    apt update
    apt install -y curl wget unzip jq openssl uuid-runtime
    
    print_success "Dependencies installed"
}

generate_keys() {
    print_status "Generating cryptographic keys..."
    
    # Generate UUID for user
    USER_UUID=$(uuidgen)
    
    # Generate private key for Reality
    PRIVATE_KEY=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout | grep -A 5 "priv:" | tail -n +2 | tr -d '[:space:]:' | xxd -r -p | base64)
    
    # Generate public key
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | base64 -d | xxd -p -c 32 | xxd -r -p | openssl pkey -inform raw -keyform raw -pubin -pubout -outform DER | tail -c 32 | base64)
    
    # Generate short ID
    SHORT_ID=$(openssl rand -hex 8)
    
    print_success "Keys generated successfully"
}

download_xray() {
    print_status "Downloading Xray-core v${XRAY_VERSION}..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="64" ;;
        aarch64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="arm32-v7a" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Download Xray
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${ARCH}.zip"
    
    cd /tmp
    wget -O xray.zip "$DOWNLOAD_URL"
    unzip -o xray.zip
    
    # Install Xray
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
    cp xray "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/xray"
    
    # Clean up
    rm -f xray.zip xray geoip.dat geosite.dat
    
    print_success "Xray installed successfully"
}

create_config() {
    print_status "Creating Xray configuration..."
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "$LOG_DIR/access.log",
        "error": "$LOG_DIR/error.log"
    },
    "inbounds": [
        {
            "port": $DEFAULT_PORT,
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
                    "dest": "$DEFAULT_DEST_SITE",
                    "xver": 0,
                    "serverNames": [
                        "$DEFAULT_SERVER_NAME"
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
    
    print_success "Configuration created"
}

create_service() {
    print_status "Creating systemd service..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$INSTALL_DIR/xray run -config $CONFIG_DIR/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xray
    
    print_success "Service created and enabled"
}

configure_firewall() {
    print_status "Configuring firewall..."
    
    # Install ufw if not present
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw
    fi
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow $DEFAULT_PORT
    ufw --force enable
    
    print_success "Firewall configured"
}

save_client_info() {
    print_status "Saving client configuration..."
    
    # Create client info file
    cat > "$CONFIG_DIR/client-info.json" << EOF
{
    "server_ip": "$SERVER_IP",
    "port": $DEFAULT_PORT,
    "uuid": "$USER_UUID",
    "public_key": "$PUBLIC_KEY",
    "short_id": "$SHORT_ID",
    "server_name": "$DEFAULT_SERVER_NAME",
    "protocol": "vless",
    "security": "reality",
    "flow": "xtls-rprx-vision"
}
EOF
    
    print_success "Client information saved to $CONFIG_DIR/client-info.json"
}

start_service() {
    print_status "Starting Xray service..."
    
    systemctl start xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "Xray service started successfully"
    else
        print_error "Failed to start Xray service"
        systemctl status xray
        exit 1
    fi
}

show_client_config() {
    print_success "=== VPN Installation Completed Successfully! ==="
    echo
    print_status "Server Information:"
    echo "  Server IP: $SERVER_IP"
    echo "  Port: $DEFAULT_PORT"
    echo "  Protocol: VLESS + Reality"
    echo
    print_status "Client Configuration:"
    echo "  UUID: $USER_UUID"
    echo "  Public Key: $PUBLIC_KEY"
    echo "  Short ID: $SHORT_ID"
    echo "  Server Name: $DEFAULT_SERVER_NAME"
    echo
    print_status "VLESS URL for mobile apps:"
    VLESS_URL="vless://$USER_UUID@$SERVER_IP:$DEFAULT_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$DEFAULT_SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#VPN-Reality"
    echo "$VLESS_URL"
    echo
    print_warning "Save this information! You'll need it to configure your mobile client."
    print_status "Use './vpn-manager.sh' to manage the service"
    print_status "Use './generate-client-config.sh' to generate QR codes and configs"
}

main() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    VPN Auto-Setup Tool                      ║"
    echo "║                  VLESS + Reality Protocol                   ║"
    echo "║                   Ubuntu 24.04.02 Ready                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    check_system
    install_dependencies
    generate_keys
    download_xray
    create_config
    create_service
    configure_firewall
    save_client_info
    start_service
    show_client_config
}

# Run main function
main "$@"
