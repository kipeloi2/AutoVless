#!/bin/bash

# Client Configuration Generator
# Generate configs and QR codes for mobile devices

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
OUTPUT_DIR="/root/vpn-clients"

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

install_qr_tools() {
    if ! command -v qrencode &> /dev/null; then
        print_status "Installing QR code generator..."
        apt update
        apt install -y qrencode
        print_success "QR code tools installed"
    fi
}

load_client_info() {
    if [[ ! -f "$CONFIG_DIR/client-info.json" ]]; then
        print_error "Client info file not found. Please run the installation script first."
        exit 1
    fi
    
    CLIENT_INFO=$(cat "$CONFIG_DIR/client-info.json")
    SERVER_IP=$(echo "$CLIENT_INFO" | jq -r '.server_ip')
    PORT=$(echo "$CLIENT_INFO" | jq -r '.port')
    UUID=$(echo "$CLIENT_INFO" | jq -r '.uuid')
    PUBLIC_KEY=$(echo "$CLIENT_INFO" | jq -r '.public_key')
    SHORT_ID=$(echo "$CLIENT_INFO" | jq -r '.short_id')
    SERVER_NAME=$(echo "$CLIENT_INFO" | jq -r '.server_name')
}

generate_vless_url() {
    local name="${1:-VPN-Reality}"
    echo "vless://$UUID@$SERVER_IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#$name"
}

generate_v2rayng_config() {
    local name="${1:-VPN-Reality}"
    
    cat << EOF
{
    "v": "2",
    "ps": "$name",
    "add": "$SERVER_IP",
    "port": "$PORT",
    "id": "$UUID",
    "aid": "0",
    "scy": "none",
    "net": "tcp",
    "type": "none",
    "host": "",
    "path": "",
    "tls": "reality",
    "sni": "$SERVER_NAME",
    "alpn": "",
    "fp": "chrome",
    "pbk": "$PUBLIC_KEY",
    "sid": "$SHORT_ID",
    "spx": "",
    "flow": "xtls-rprx-vision"
}
EOF
}

generate_clash_config() {
    local name="${1:-VPN-Reality}"
    
    cat << EOF
proxies:
  - name: "$name"
    type: vless
    server: $SERVER_IP
    port: $PORT
    uuid: $UUID
    network: tcp
    tls: true
    servername: $SERVER_NAME
    reality-opts:
      public-key: $PUBLIC_KEY
      short-id: $SHORT_ID
    client-fingerprint: chrome
    flow: xtls-rprx-vision

proxy-groups:
  - name: "VPN"
    type: select
    proxies:
      - "$name"

rules:
  - MATCH,VPN
EOF
}

generate_shadowrocket_config() {
    local name="${1:-VPN-Reality}"
    generate_vless_url "$name"
}

generate_qr_code() {
    local url="$1"
    local filename="$2"
    
    echo "$url" | qrencode -t PNG -o "$filename" -s 8 -m 2
    print_success "QR code saved to $filename"
}

create_client_package() {
    local client_name="${1:-default}"
    local package_dir="$OUTPUT_DIR/$client_name"
    
    print_status "Creating client package for: $client_name"
    
    mkdir -p "$package_dir"
    
    # Generate VLESS URL
    local vless_url=$(generate_vless_url "$client_name")
    
    # Save configurations
    echo "$vless_url" > "$package_dir/vless-url.txt"
    generate_v2rayng_config "$client_name" > "$package_dir/v2rayng-config.json"
    generate_clash_config "$client_name" > "$package_dir/clash-config.yaml"
    
    # Generate QR codes
    generate_qr_code "$vless_url" "$package_dir/qr-code.png"
    
    # Create connection info
    cat > "$package_dir/connection-info.txt" << EOF
VPN Connection Information
=========================

Client Name: $client_name
Server: $SERVER_IP:$PORT
Protocol: VLESS + Reality
Security: TLS with Reality camouflage

Connection Details:
- UUID: $UUID
- Public Key: $PUBLIC_KEY
- Short ID: $SHORT_ID
- Server Name: $SERVER_NAME
- Flow: xtls-rprx-vision

VLESS URL (for most apps):
$vless_url

Supported Apps:
- v2rayNG (Android)
- v2rayN (Windows)
- Shadowrocket (iOS)
- Clash (Multi-platform)
- Qv2ray (Multi-platform)

Setup Instructions:
1. Install a compatible VPN app
2. Scan the QR code or import the VLESS URL
3. Connect and enjoy secure browsing!

Generated on: $(date)
EOF
    
    # Create README
    cat > "$package_dir/README.md" << EOF
# VPN Client Configuration

This package contains all necessary files to connect to your VPN server.

## Files Included

- \`vless-url.txt\` - Direct VLESS URL for quick setup
- \`qr-code.png\` - QR code for mobile apps
- \`v2rayng-config.json\` - Configuration for v2rayNG
- \`clash-config.yaml\` - Configuration for Clash
- \`connection-info.txt\` - Detailed connection information

## Quick Setup

### Android (v2rayNG)
1. Install v2rayNG from Google Play or F-Droid
2. Open the app and tap the "+" button
3. Select "Import config from QR code"
4. Scan the QR code from \`qr-code.png\`
5. Tap the connection to activate it

### iOS (Shadowrocket)
1. Install Shadowrocket from App Store
2. Open the app and tap the "+" button
3. Scan the QR code or paste the VLESS URL
4. Tap the connection to activate it

### Windows/Mac/Linux (v2rayN/Qv2ray)
1. Install v2rayN (Windows) or Qv2ray (cross-platform)
2. Import the VLESS URL or use the configuration files
3. Connect and enjoy!

## Troubleshooting

If you can't connect:
1. Check your internet connection
2. Try different server names (microsoft.com, cloudflare.com)
3. Contact your VPN administrator

Generated on: $(date)
EOF
    
    print_success "Client package created in: $package_dir"
    
    # Show package contents
    print_status "Package contents:"
    ls -la "$package_dir"
}

show_all_configs() {
    print_status "=== VPN Client Configurations ==="
    echo
    
    load_client_info
    
    local vless_url=$(generate_vless_url "VPN-Reality")
    
    echo -e "${GREEN}VLESS URL (Universal):${NC}"
    echo "$vless_url"
    echo
    
    echo -e "${GREEN}Connection Details:${NC}"
    echo "Server: $SERVER_IP:$PORT"
    echo "UUID: $UUID"
    echo "Public Key: $PUBLIC_KEY"
    echo "Short ID: $SHORT_ID"
    echo "Server Name: $SERVER_NAME"
    echo "Protocol: VLESS + Reality"
    echo "Flow: xtls-rprx-vision"
    echo
    
    echo -e "${YELLOW}Recommended Apps:${NC}"
    echo "• Android: v2rayNG"
    echo "• iOS: Shadowrocket, Quantumult X"
    echo "• Windows: v2rayN, Clash for Windows"
    echo "• macOS: ClashX, Qv2ray"
    echo "• Linux: Qv2ray, Clash"
}

generate_multiple_users() {
    local count="${1:-5}"
    print_status "Generating $count user configurations..."
    
    for i in $(seq 1 "$count"); do
        local user_name="user-$i"
        local new_uuid=$(uuidgen)
        
        # Create user-specific package
        mkdir -p "$OUTPUT_DIR/$user_name"
        
        # Generate VLESS URL with unique UUID
        local vless_url="vless://$new_uuid@$SERVER_IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#$user_name"
        
        echo "$vless_url" > "$OUTPUT_DIR/$user_name/vless-url.txt"
        generate_qr_code "$vless_url" "$OUTPUT_DIR/$user_name/qr-code.png"
        
        echo "User: $user_name, UUID: $new_uuid" >> "$OUTPUT_DIR/users-list.txt"
        
        print_success "Generated config for $user_name"
    done
    
    print_warning "Note: You need to manually add these UUIDs to your Xray configuration!"
    print_status "User list saved to: $OUTPUT_DIR/users-list.txt"
}

show_help() {
    echo -e "${BLUE}VPN Client Configuration Generator${NC}"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  show                    Show all configuration details"
    echo "  package [NAME]          Create complete client package"
    echo "  qr [NAME]              Generate QR code only"
    echo "  multi [COUNT]          Generate multiple user configs"
    echo "  url [NAME]             Generate VLESS URL only"
    echo "  help                   Show this help message"
    echo
    echo "Examples:"
    echo "  $0 show"
    echo "  $0 package my-phone"
    echo "  $0 qr mobile-client"
    echo "  $0 multi 10"
    echo "  $0 url laptop"
}

main() {
    mkdir -p "$OUTPUT_DIR"
    
    case "${1:-show}" in
        "show")
            load_client_info
            show_all_configs
            ;;
        "package")
            install_qr_tools
            load_client_info
            create_client_package "${2:-default}"
            ;;
        "qr")
            install_qr_tools
            load_client_info
            local name="${2:-VPN-Reality}"
            local vless_url=$(generate_vless_url "$name")
            generate_qr_code "$vless_url" "$OUTPUT_DIR/$name-qr.png"
            echo "VLESS URL: $vless_url"
            ;;
        "multi")
            install_qr_tools
            load_client_info
            generate_multiple_users "${2:-5}"
            ;;
        "url")
            load_client_info
            generate_vless_url "${2:-VPN-Reality}"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
