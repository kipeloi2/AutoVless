#!/bin/bash

# Quick Deploy Script - Simple wrapper for install-vpn.sh
# Быстрое развертывание VPN сервера

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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
        print_error "Скрипт должен запускаться с правами root"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

check_install_script() {
    if [[ ! -f "./install-vpn.sh" ]]; then
        print_error "Файл install-vpn.sh не найден"
        print_error "Убедитесь, что вы находитесь в директории проекта"
        exit 1
    fi
    
    if [[ ! -x "./install-vpn.sh" ]]; then
        print_status "Делаем install-vpn.sh исполняемым..."
        chmod +x ./install-vpn.sh
    fi
}

main() {
    print_banner
    
    print_status "Запуск быстрого развертывания VPN сервера..."
    echo
    
    check_root
    check_install_script
    
    print_status "Запуск основного скрипта установки..."
    echo
    
    # Запускаем основной скрипт установки
    ./install-vpn.sh
    
    if [[ $? -eq 0 ]]; then
        echo
        print_success "✅ Быстрое развертывание завершено успешно!"
        print_status "Используйте './generate-client-config.sh show' для получения конфигураций"
        print_status "Используйте './vpn-manager.sh status' для проверки статуса"
    else
        print_error "❌ Ошибка при развертывании"
        exit 1
    fi
}

main "$@"
