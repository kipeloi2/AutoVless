#!/bin/bash

# Quick Deploy Script - One-click VPN setup
# Автоматическое развертывание VPN сервера одной командой

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 VPN Quick Deploy 🚀                   ║"
    echo "║                                                              ║"
    echo "║           Автоматическое развертывание VPN сервера           ║"
    echo "║                  VLESS + Reality Protocol                   ║"
    echo "║                                                              ║"
    echo "║  • Полная автоматизация установки                           ║"
    echo "║  • Максимальная скрытность трафика                          ║"
    echo "║  • Готовые конфигурации для телефона                       ║"
    echo "║  • Инструменты мониторинга                                  ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

check_requirements() {
    print_status "Проверка системных требований..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен запускаться с правами root"
        echo "Используйте: sudo $0"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_warning "Скрипт оптимизирован для Ubuntu, но попробуем продолжить..."
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "Нет подключения к интернету"
        exit 1
    fi
    
    # Check available space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # Less than 1GB
        print_warning "Мало свободного места на диске (менее 1GB)"
    fi
    
    print_success "Системные требования выполнены"
}

interactive_setup() {
    echo
    print_status "Интерактивная настройка VPN сервера"
    echo
    
    # Server port
    echo -e "${YELLOW}Выберите порт для VPN сервера:${NC}"
    echo "1) 443 (рекомендуется - стандартный HTTPS)"
    echo "2) 8443 (альтернативный HTTPS)"
    echo "3) 2053 (Cloudflare compatible)"
    echo "4) Свой порт"
    read -p "Ваш выбор [1]: " port_choice
    
    case ${port_choice:-1} in
        1) VPN_PORT=443 ;;
        2) VPN_PORT=8443 ;;
        3) VPN_PORT=2053 ;;
        4) 
            read -p "Введите порт (1-65535): " custom_port
            if [[ $custom_port =~ ^[0-9]+$ ]] && [[ $custom_port -ge 1 ]] && [[ $custom_port -le 65535 ]]; then
                VPN_PORT=$custom_port
            else
                print_error "Неверный порт, используем 443"
                VPN_PORT=443
            fi
            ;;
        *) VPN_PORT=443 ;;
    esac
    
    # Masquerade site
    echo
    echo -e "${YELLOW}Выберите сайт для маскировки:${NC}"
    echo "1) www.microsoft.com (рекомендуется)"
    echo "2) www.cloudflare.com"
    echo "3) www.bing.com"
    echo "4) discord.com"
    echo "5) Свой сайт"
    read -p "Ваш выбор [1]: " site_choice
    
    case ${site_choice:-1} in
        1) 
            DEST_SITE="www.microsoft.com:443"
            SERVER_NAME="www.microsoft.com"
            ;;
        2) 
            DEST_SITE="www.cloudflare.com:443"
            SERVER_NAME="www.cloudflare.com"
            ;;
        3) 
            DEST_SITE="www.bing.com:443"
            SERVER_NAME="www.bing.com"
            ;;
        4) 
            DEST_SITE="discord.com:443"
            SERVER_NAME="discord.com"
            ;;
        5) 
            read -p "Введите домен (например, example.com): " custom_site
            if [[ $custom_site =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                DEST_SITE="$custom_site:443"
                SERVER_NAME="$custom_site"
            else
                print_error "Неверный домен, используем microsoft.com"
                DEST_SITE="www.microsoft.com:443"
                SERVER_NAME="www.microsoft.com"
            fi
            ;;
        *) 
            DEST_SITE="www.microsoft.com:443"
            SERVER_NAME="www.microsoft.com"
            ;;
    esac
    
    # Client name
    echo
    read -p "Введите имя для клиентской конфигурации [My-VPN]: " client_name
    CLIENT_NAME=${client_name:-My-VPN}
    
    # Additional users
    echo
    read -p "Сколько дополнительных пользователей создать? [0]: " additional_users
    ADDITIONAL_USERS=${additional_users:-0}
    
    # Confirmation
    echo
    echo -e "${CYAN}Параметры установки:${NC}"
    echo "  Порт: $VPN_PORT"
    echo "  Маскировка: $SERVER_NAME"
    echo "  Имя клиента: $CLIENT_NAME"
    echo "  Дополнительные пользователи: $ADDITIONAL_USERS"
    echo
    read -p "Продолжить установку? [y/N]: " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Установка отменена пользователем"
        exit 0
    fi
}

make_scripts_executable() {
    print_status "Настройка прав доступа к скриптам..."
    
    chmod +x install-vpn.sh
    chmod +x vpn-manager.sh
    chmod +x generate-client-config.sh
    chmod +x monitor.sh
    chmod +x quick-deploy.sh
    
    print_success "Права доступа настроены"
}

run_installation() {
    print_status "Запуск основной установки..."
    
    # Modify install script with our parameters
    sed -i "s/DEFAULT_PORT=443/DEFAULT_PORT=$VPN_PORT/" install-vpn.sh
    sed -i "s/DEFAULT_DEST_SITE=\"www.microsoft.com:443\"/DEFAULT_DEST_SITE=\"$DEST_SITE\"/" install-vpn.sh
    sed -i "s/DEFAULT_SERVER_NAME=\"www.microsoft.com\"/DEFAULT_SERVER_NAME=\"$SERVER_NAME\"/" install-vpn.sh
    
    # Run installation
    ./install-vpn.sh
    
    if [[ $? -eq 0 ]]; then
        print_success "Основная установка завершена успешно"
    else
        print_error "Ошибка при установке"
        exit 1
    fi
}

generate_client_configs() {
    print_status "Генерация клиентских конфигураций..."
    
    # Generate main client config
    ./generate-client-config.sh package "$CLIENT_NAME"
    
    # Generate additional users if requested
    if [[ $ADDITIONAL_USERS -gt 0 ]]; then
        ./generate-client-config.sh multi "$ADDITIONAL_USERS"
    fi
    
    print_success "Клиентские конфигурации созданы"
}

setup_monitoring() {
    print_status "Настройка мониторинга..."
    
    # Create monitoring cron job
    cat > /etc/cron.d/vpn-monitor << EOF
# VPN Health Check - every 5 minutes
*/5 * * * * root /root/monitor.sh health >> /var/log/vpn-health.log 2>&1

# VPN Report - daily at 2 AM
0 2 * * * root /root/monitor.sh report

# Log rotation - weekly
0 0 * * 0 root find /var/log/xray/ -name "*.log" -mtime +7 -delete
EOF
    
    # Create log rotation config
    cat > /etc/logrotate.d/xray << EOF
/var/log/xray/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 nobody nogroup
    postrotate
        systemctl reload xray
    endscript
}
EOF
    
    print_success "Мониторинг настроен"
}

create_management_aliases() {
    print_status "Создание удобных команд..."
    
    # Create aliases for easy management
    cat >> /root/.bashrc << EOF

# VPN Management Aliases
alias vpn-status='./vpn-manager.sh status'
alias vpn-start='./vpn-manager.sh start'
alias vpn-stop='./vpn-manager.sh stop'
alias vpn-restart='./vpn-manager.sh restart'
alias vpn-logs='./vpn-manager.sh logs'
alias vpn-client='./vpn-manager.sh client'
alias vpn-monitor='./monitor.sh dashboard'
alias vpn-health='./monitor.sh health'
alias vpn-config='./generate-client-config.sh show'
alias vpn-qr='./generate-client-config.sh qr'
EOF
    
    print_success "Команды управления созданы"
}

show_final_info() {
    echo
    print_success "🎉 VPN сервер успешно развернут!"
    echo
    
    # Get server info
    local server_ip=$(curl -s ifconfig.me)
    local client_info_file="/usr/local/etc/xray/client-info.json"
    
    if [[ -f "$client_info_file" ]]; then
        local uuid=$(jq -r '.uuid' "$client_info_file")
        local public_key=$(jq -r '.public_key' "$client_info_file")
        local short_id=$(jq -r '.short_id' "$client_info_file")
        
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                    Информация для подключения               ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${GREEN}Сервер:${NC} $server_ip:$VPN_PORT"
        echo -e "${GREEN}Протокол:${NC} VLESS + Reality"
        echo -e "${GREEN}Маскировка:${NC} $SERVER_NAME"
        echo -e "${GREEN}UUID:${NC} $uuid"
        echo
        
        # Generate VLESS URL
        local vless_url="vless://$uuid@$server_ip:$VPN_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#$CLIENT_NAME"
        
        echo -e "${YELLOW}VLESS URL для мобильных приложений:${NC}"
        echo "$vless_url"
        echo
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      Полезные команды                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}Управление сервисом:${NC}"
    echo "  vpn-status    - Проверить статус"
    echo "  vpn-restart   - Перезапустить сервис"
    echo "  vpn-logs      - Посмотреть логи"
    echo
    echo -e "${GREEN}Клиентские конфигурации:${NC}"
    echo "  vpn-config    - Показать все конфигурации"
    echo "  vpn-qr        - Создать QR-код"
    echo "  ./generate-client-config.sh package <имя> - Создать пакет"
    echo
    echo -e "${GREEN}Мониторинг:${NC}"
    echo "  vpn-monitor   - Дашборд мониторинга"
    echo "  vpn-health    - Проверка здоровья системы"
    echo "  ./monitor.sh report - Создать отчет"
    echo
    echo -e "${YELLOW}Файлы конфигураций находятся в:${NC}"
    echo "  /root/vpn-clients/$CLIENT_NAME/"
    echo
    echo -e "${YELLOW}Документация:${NC}"
    echo "  README.md - Основная документация"
    echo "  examples/android-setup.md - Настройка Android"
    echo "  examples/ios-setup.md - Настройка iOS"
    echo "  examples/troubleshooting.md - Устранение неполадок"
    echo
    
    print_warning "Сохраните эту информацию в безопасном месте!"
    print_status "Для получения QR-кода выполните: vpn-qr $CLIENT_NAME"
}

main() {
    print_banner
    
    # Check if running in interactive mode
    if [[ -t 0 ]]; then
        check_requirements
        interactive_setup
    else
        # Non-interactive mode with defaults
        VPN_PORT=443
        DEST_SITE="www.microsoft.com:443"
        SERVER_NAME="www.microsoft.com"
        CLIENT_NAME="My-VPN"
        ADDITIONAL_USERS=0
        check_requirements
    fi
    
    print_status "Начинаем развертывание VPN сервера..."
    echo
    
    make_scripts_executable
    run_installation
    generate_client_configs
    setup_monitoring
    create_management_aliases
    
    show_final_info
    
    echo
    print_success "✅ Развертывание завершено! Ваш VPN сервер готов к использованию."
    print_status "Перезагрузите терминал или выполните 'source ~/.bashrc' для активации команд"
}

# Handle script interruption
trap 'echo -e "\n${RED}Установка прервана пользователем${NC}"; exit 1' INT TERM

main "$@"
