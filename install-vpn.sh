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

    # Use variables from interactive setup or defaults
    local port=${VPN_PORT:-443}
    local dest_site=${DEST_SITE:-"www.microsoft.com:443"}
    local server_name=${SERVER_NAME:-"www.microsoft.com"}

    cat > /usr/local/etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log"
    },
    "inbounds": [
        {
            "port": $port,
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
                    "dest": "$dest_site",
                    "xver": 0,
                    "serverNames": [
                        "$server_name"
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
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

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
        cat /usr/local/etc/xray/config.json
        exit 1
    fi

    print_status "Checking port availability..."
    if netstat -tlnp | grep -q ":443 "; then
        print_warning "Port 443 is already in use:"
        netstat -tlnp | grep ":443 "
        print_status "Trying to free port 443..."
        # Try to stop common services that might use port 443
        systemctl stop apache2 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        systemctl stop httpd 2>/dev/null || true
        sleep 2
    fi

    print_status "Testing direct Xray execution..."
    timeout 5s /usr/local/bin/xray run -config /usr/local/etc/xray/config.json &
    XRAY_PID=$!
    sleep 2

    if kill -0 $XRAY_PID 2>/dev/null; then
        print_success "Xray can run directly"
        kill $XRAY_PID 2>/dev/null || true
    else
        print_error "Xray fails to run directly"
        print_error "Trying to run Xray manually for debugging..."
        /usr/local/bin/xray run -config /usr/local/etc/xray/config.json
        exit 1
    fi

    print_status "Starting systemd service..."
    systemctl start xray
    sleep 3

    if systemctl is-active --quiet xray; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        print_error "Service status:"
        systemctl status xray --no-pager -l
        print_error "Recent logs:"
        journalctl -u xray --no-pager -n 20
        print_error "Configuration content:"
        cat /usr/local/etc/xray/config.json
        exit 1
    fi
}

save_client_info() {
    print_status "Saving client info..."

    SERVER_IP=$(curl -s ifconfig.me)

    # Use variables from interactive setup or defaults
    local port=${VPN_PORT:-443}
    local server_name=${SERVER_NAME:-"www.microsoft.com"}
    local client_name=${CLIENT_NAME:-"My-VPN"}

    cat > /usr/local/etc/xray/client-info.json << EOF
{
    "server_ip": "$SERVER_IP",
    "port": $port,
    "uuid": "$USER_UUID",
    "public_key": "$PUBLIC_KEY",
    "short_id": "$SHORT_ID",
    "server_name": "$server_name",
    "client_name": "$client_name",
    "protocol": "vless",
    "security": "reality",
    "flow": "xtls-rprx-vision"
}
EOF

    print_success "Client info saved"
}

configure_firewall() {
    print_status "Configuring firewall..."

    # Use port from interactive setup or default
    local port=${VPN_PORT:-443}

    if command -v ufw &> /dev/null; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow $port
        ufw --force enable
        print_success "Firewall configured for port $port"
    else
        print_warning "UFW not found, skipping firewall configuration"
    fi
}

show_result() {
    print_success "🎉 VPN installation completed!"
    echo

    SERVER_IP=$(curl -s ifconfig.me)

    # Use variables from interactive setup or defaults
    local port=${VPN_PORT:-443}
    local server_name=${SERVER_NAME:-"www.microsoft.com"}
    local client_name=${CLIENT_NAME:-"My-VPN"}
    local site_desc=${SITE_DESC:-"Microsoft"}

    VLESS_URL="vless://$USER_UUID@$SERVER_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#$client_name"

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Информация для подключения               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}Название клиента:${NC} $client_name"
    echo -e "${GREEN}Сервер:${NC} $SERVER_IP:$port"
    echo -e "${GREEN}Протокол:${NC} VLESS + Reality"
    echo -e "${GREEN}Маскировка:${NC} $site_desc ($server_name)"
    echo -e "${GREEN}UUID:${NC} $USER_UUID"
    echo -e "${GREEN}Public Key:${NC} $PUBLIC_KEY"
    echo -e "${GREEN}Short ID:${NC} $SHORT_ID"
    echo
    echo -e "${YELLOW}VLESS URL для мобильных приложений:${NC}"
    echo "$VLESS_URL"
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      Полезные команды                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}Управление:${NC}"
    echo "  ./vpn-manager.sh status    - Проверить статус"
    echo "  ./vpn-manager.sh restart   - Перезапустить"
    echo "  ./monitor.sh dashboard     - Мониторинг"
    echo
    echo -e "${GREEN}Клиентские конфигурации:${NC}"
    echo "  ./generate-client-config.sh show     - Показать все конфигурации"
    echo "  ./generate-client-config.sh qr       - Создать QR-код"
    echo "  ./generate-client-config.sh package  - Создать пакет конфигураций"
    echo
    print_warning "💾 Сохраните эту информацию в безопасном месте!"
}

interactive_setup() {
    echo
    print_status "🎯 Интерактивная настройка VPN сервера"
    echo

    # Client name
    echo -e "${YELLOW}Введите название клиента (будет отображаться в приложении):${NC}"
    read -p "Название [My-VPN]: " CLIENT_NAME
    CLIENT_NAME=${CLIENT_NAME:-My-VPN}

    # Masquerade site selection
    echo
    echo -e "${YELLOW}Выберите сайт для маскировки трафика:${NC}"
    echo "1) microsoft.com (рекомендуется - стабильно работает)"
    echo "2) apple.com (популярный, не заблокирован)"
    echo "3) cloudflare.com (отличная производительность)"
    echo "4) github.com (для разработчиков)"
    echo "5) amazon.com (крупный сервис)"
    echo "6) stackoverflow.com (техническая тематика)"
    echo "7) ubuntu.com (серверная тематика)"
    echo "8) docker.com (DevOps тематика)"
    echo "9) Свой сайт"

    read -p "Ваш выбор [1]: " SITE_CHOICE

    case ${SITE_CHOICE:-1} in
        1)
            DEST_SITE="www.microsoft.com:443"
            SERVER_NAME="www.microsoft.com"
            SITE_DESC="Microsoft"
            ;;
        2)
            DEST_SITE="www.apple.com:443"
            SERVER_NAME="www.apple.com"
            SITE_DESC="Apple"
            ;;
        3)
            DEST_SITE="www.cloudflare.com:443"
            SERVER_NAME="www.cloudflare.com"
            SITE_DESC="Cloudflare"
            ;;
        4)
            DEST_SITE="github.com:443"
            SERVER_NAME="github.com"
            SITE_DESC="GitHub"
            ;;
        5)
            DEST_SITE="www.amazon.com:443"
            SERVER_NAME="www.amazon.com"
            SITE_DESC="Amazon"
            ;;
        6)
            DEST_SITE="stackoverflow.com:443"
            SERVER_NAME="stackoverflow.com"
            SITE_DESC="Stack Overflow"
            ;;
        7)
            DEST_SITE="ubuntu.com:443"
            SERVER_NAME="ubuntu.com"
            SITE_DESC="Ubuntu"
            ;;
        8)
            DEST_SITE="www.docker.com:443"
            SERVER_NAME="www.docker.com"
            SITE_DESC="Docker"
            ;;
        9)
            echo
            read -p "Введите домен (например, example.com): " CUSTOM_SITE
            if [[ $CUSTOM_SITE =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                DEST_SITE="$CUSTOM_SITE:443"
                SERVER_NAME="$CUSTOM_SITE"
                SITE_DESC="$CUSTOM_SITE"
            else
                print_error "Неверный домен, используем microsoft.com"
                DEST_SITE="www.microsoft.com:443"
                SERVER_NAME="www.microsoft.com"
                SITE_DESC="Microsoft"
            fi
            ;;
        *)
            DEST_SITE="www.microsoft.com:443"
            SERVER_NAME="www.microsoft.com"
            SITE_DESC="Microsoft"
            ;;
    esac

    # Port selection
    echo
    echo -e "${YELLOW}Выберите порт для VPN сервера:${NC}"
    echo "1) 443 (рекомендуется - стандартный HTTPS)"
    echo "2) 8443 (альтернативный HTTPS)"
    echo "3) 2053 (Cloudflare compatible)"
    echo "4) 2083 (альтернативный)"
    echo "5) Свой порт"

    read -p "Ваш выбор [1]: " PORT_CHOICE

    case ${PORT_CHOICE:-1} in
        1) VPN_PORT=443 ;;
        2) VPN_PORT=8443 ;;
        3) VPN_PORT=2053 ;;
        4) VPN_PORT=2083 ;;
        5)
            read -p "Введите порт (1-65535): " CUSTOM_PORT
            if [[ $CUSTOM_PORT =~ ^[0-9]+$ ]] && [[ $CUSTOM_PORT -ge 1 ]] && [[ $CUSTOM_PORT -le 65535 ]]; then
                VPN_PORT=$CUSTOM_PORT
            else
                print_error "Неверный порт, используем 443"
                VPN_PORT=443
            fi
            ;;
        *) VPN_PORT=443 ;;
    esac

    # Confirmation
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Параметры установки                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}Название клиента:${NC} $CLIENT_NAME"
    echo -e "${GREEN}Маскировка:${NC} $SITE_DESC ($SERVER_NAME)"
    echo -e "${GREEN}Порт:${NC} $VPN_PORT"
    echo

    read -p "Продолжить установку с этими параметрами? [y/N]: " CONFIRM

    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_error "Установка отменена пользователем"
        exit 0
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 VPN Auto-Setup Tool 🚀                ║"
    echo "║                  VLESS + Reality Protocol                   ║"
    echo "║                   Ubuntu 24.04.02 Ready                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_root

    # Check if running in interactive mode
    if [[ -t 0 ]]; then
        interactive_setup
    else
        # Non-interactive mode with defaults
        CLIENT_NAME="My-VPN"
        DEST_SITE="www.microsoft.com:443"
        SERVER_NAME="www.microsoft.com"
        SITE_DESC="Microsoft"
        VPN_PORT=443
        print_status "Запуск в неинтерактивном режиме с настройками по умолчанию"
    fi

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
