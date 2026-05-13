#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer with Telemt (binary) + Traefik (Docker)
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 7.1 (official telemt binary + traefik)
# ============================================================

set -euo pipefail

# ---------- Цвета ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
BLINK='\033[5m'
NC='\033[0m'

# ---------- Спиннер ----------
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" &>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ---------- Баннер ----------
banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██╗   ██╗██╗   ██╗██████╗ ██╗ ██████╗██╗  ██╗${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}╚██╗ ██╔╝██║   ██║██╔══██╗██║██╔════╝██║  ██║${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA} ╚████╔╝ ██║   ██║██████╔╝██║██║     ███████║${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}  ╚██╔╝  ██║   ██║██╔══██╗██║██║     ██╔══██║${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}   ██║   ╚██████╔╝██║  ██║██║╚██████╗██║  ██║${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝${CYAN}           ║${NC}"
    echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██████╗ ███████╗██╗      █████╗ ███████╗████████╗${CYAN}       ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██╔══██╗██╔════╝██║     ██╔══██╗██╔════╝╚══██╔══╝${CYAN}       ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██║  ██║█████╗  ██║     ███████║█████╗     ██║${CYAN}          ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██║  ██║██╔══╝  ██║     ██╔══██║██╔══╝     ██║${CYAN}          ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}██████╔╝███████╗███████╗██║  ██║███████╗   ██║${CYAN}          ║${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝${CYAN}          ║${NC}"
    echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}🚀 MTProto Proxy for Telegram 🚀${CYAN}               ║${NC}"
    echo -e "${CYAN}║${NC}                         ${GREEN}v7.1${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Telemt (binary) + Traefik | Fake TLS on 443${CYAN}    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() { echo -e "${BLUE}[➜]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Запустите скрипт с правами root: sudo ./mtp.sh"
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        step "Docker не найден. Устанавливаем..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
        systemctl start docker > /dev/null 2>&1
        rm -f get-docker.sh
        success "Docker установлен"
    else
        success "Docker уже установлен"
    fi

    if ! command -v docker-compose &> /dev/null; then
        step "Устанавливаем docker-compose..."
        curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        success "docker-compose установлен"
    else
        success "docker-compose уже установлен"
    fi
}

install_telemt() {
    step "Устанавливаем Telemt (официальный бинарный файл)..."
    curl -fsSL https://raw.githubusercontent.com/telemt/telemt/main/install.sh | sh
    success "Telemt установлен"
}

get_params() {
    echo ""
    step "Настройка прокси"
    read -p "Введите порт для Traefik (внешний) [443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-443}
    if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
        error "Неверный порт"
    fi

    echo ""
    echo -e "${YELLOW}Выберите тип адреса для подключения:${NC}"
    echo "   1) IP-адрес (автоопределение)"
    echo "   2) Домен (введите вручную)"
    read -p "Ваш выбор (1 или 2): " ADDR_TYPE
    if [[ "$ADDR_TYPE" == "2" ]]; then
        read -p "Введите ваш домен (например: proxy.example.com): " CUSTOM_DOMAIN
        if [[ -z "$CUSTOM_DOMAIN" ]]; then
            error "Домен не может быть пустым"
        fi
        SERVER_ADDR="$CUSTOM_DOMAIN"
        CURRENT_IP=$(curl -s -4 ifconfig.me || echo "")
        DOMAIN_IP=$(dig +short "$CUSTOM_DOMAIN" | head -1 || echo "")
        if [[ -n "$DOMAIN_IP" && -n "$CURRENT_IP" && "$DOMAIN_IP" != "$CURRENT_IP" ]]; then
            warn "Домен $CUSTOM_DOMAIN не указывает на текущий IP ($CURRENT_IP). Подключение может не работать!"
        elif [[ -z "$DOMAIN_IP" ]]; then
            warn "Не удалось определить IP домена $CUSTOM_DOMAIN. Убедитесь, что DNS запись существует."
        else
            success "Домен $CUSTOM_DOMAIN -> $DOMAIN_IP (OK)"
        fi
    else
        SERVER_ADDR=""
    fi

    read -p "Домен маскировки (Fake TLS) [1c.ru]: " FAKE_DOMAIN
    FAKE_DOMAIN=${FAKE_DOMAIN:-1c.ru}
    success "Порт: $PROXY_PORT, домен маскировки: $FAKE_DOMAIN"
}

generate_secret() {
    step "Генерация Fake TLS секрета..."
    SECRET_PREFIX="ee"
    RANDOM_KEY=$(openssl rand -hex 16)
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps)
    FULL_SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
    success "Секрет создан"
}

setup_directories() {
    INSTALL_DIR="/opt/mtproto-telemt"
    mkdir -p "$INSTALL_DIR"/{traefik/dynamic,traefik/static}
    cd "$INSTALL_DIR"
    success "Директория установки: $INSTALL_DIR"
}

create_telemt_config() {
    cat > "$INSTALL_DIR/telemt.toml" << EOF
# Telemt configuration for Fake TLS
secret = "$FULL_SECRET"
bind = "127.0.0.1:1234"
users = []
timeout = 300
keepalive = 30
fast_mode = true
ipv6 = false
trace = false

[censorship]
tls_domain = "$FAKE_DOMAIN"
EOF
    success "Конфиг telemt.toml создан"
}

create_telemt_service() {
    cat > /etc/systemd/system/telemt.service << EOF
[Unit]
Description=Telemt MTProto Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/telemt $INSTALL_DIR/telemt.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable telemt
    systemctl start telemt
    success "Telemt запущен как systemd сервис"
}

create_traefik_static() {
    cat > "$INSTALL_DIR/traefik/static/traefik.yml" << EOF
global:
  sendAnonymousUsage: false

entryPoints:
  websecure:
    address: ":${PROXY_PORT}"

providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true

log:
  level: INFO
EOF
    success "Статический конфиг Traefik создан"
}

create_traefik_dynamic() {
    cat > "$INSTALL_DIR/traefik/dynamic/tcp.yml" << EOF
tcp:
  routers:
    telemt-router:
      entryPoints:
        - websecure
      rule: "HostSNI(\`$FAKE_DOMAIN\`)"
      service: telemt-service
      tls:
        passthrough: true

  services:
    telemt-service:
      loadBalancer:
        servers:
          - address: "host.docker.internal:1234"
EOF
    success "Динамический конфиг Traefik создан"
}

create_docker_compose() {
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: always
    ports:
      - "${PROXY_PORT}:${PROXY_PORT}"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./traefik/static:/etc/traefik:ro
      - ./traefik/dynamic:/etc/traefik/dynamic:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
EOF
    success "docker-compose.yml создан"
}

start_traefik() {
    step "Запускаем Traefik в Docker..."
    cd "$INSTALL_DIR"
    docker-compose up -d
    sleep 3
    success "Traefik запущен"
}

get_public_ip() {
    if [[ -n "$SERVER_ADDR" ]]; then
        SERVER="$SERVER_ADDR"
        success "Используем домен: $SERVER"
    else
        step "Определяем внешний IP..."
        SERVER=$(curl -s --max-time 5 -4 ifconfig.me || curl -s --max-time 5 -4 icanhazip.com || curl -s --max-time 5 -4 ipinfo.io/ip || echo "")
        if [[ -z "$SERVER" ]]; then
            warn "Не удалось определить IP автоматически"
            read -p "Введите IP сервера вручную: " SERVER
            [[ -z "$SERVER" ]] && error "IP не введён"
        else
            success "IP: $SERVER"
        fi
    fi
}

open_firewall() {
    if command -v ufw &> /dev/null; then
        step "Открываем порт $PROXY_PORT в UFW..."
        ufw allow ${PROXY_PORT}/tcp > /dev/null 2>&1
        success "Порт открыт (UFW)"
    elif command -v firewall-cmd &> /dev/null; then
        step "Открываем порт $PROXY_PORT в firewalld..."
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        success "Порт открыт (firewalld)"
    else
        warn "Firewall не обнаружен. Убедитесь, что порт $PROXY_PORT открыт вручную."
    fi
}

get_proxy_link() {
    PROXY_LINK="tg://proxy?server=${SERVER}&port=${PROXY_PORT}&secret=${FULL_SECRET}"
    success "Ссылка для подключения готова"
}

create_global_command() {
    cat > /usr/local/bin/yurich << 'EOF'
#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[0;31mПожалуйста, запустите с sudo: sudo yurich\033[0m"
    exit 1
fi
INSTALL_DIR="/opt/mtproto-telemt"
cd "$INSTALL_DIR"
echo -e "\033[0;36m=== Управление прокси Telemt+Traefik ===\033[0m"
echo "1) Посмотреть логи Telemt"
echo "2) Посмотреть логи Traefik"
echo "3) Перезапустить всё"
echo "4) Остановить всё"
echo "5) Показать статус"
echo "6) Показать статистику (docker stats)"
echo "0) Выход"
read -p "Выберите действие: " choice
case $choice in
    1) journalctl -u telemt -f ;;
    2) docker-compose logs -f traefik ;;
    3) systemctl restart telemt && docker-compose restart ;;
    4) systemctl stop telemt && docker-compose down ;;
    5) systemctl status telemt --no-pager && docker-compose ps ;;
    6) docker stats traefik ;;
    0) exit 0 ;;
    *) echo "Неверный выбор" ;;
esac
EOF
    chmod +x /usr/local/bin/yurich
    success "Глобальная команда 'yurich' создана (запускайте: sudo yurich)"
}

print_result() {
    clear
    banner
    echo -e "${GREEN}✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА${NC}"
    echo ""
    echo -e "${CYAN}📡 ПАРАМЕТРЫ ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    printf "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}%s${NC}\n" "$SERVER"
    printf "   ${BOLD}Порт:${NC}                 ${YELLOW}%s${NC}\n" "$PROXY_PORT"
    printf "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}%s${NC}\n" "$FAKE_DOMAIN"
    printf "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}\n"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────${NC}"
    echo -e "   ${BOLD}Telegram-ссылка:${NC} ${GREEN}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}📊 СТАТИСТИКА И ТЕЛЕМЕТРИЯ${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "   Для просмотра логов Telemt: ${WHITE}journalctl -u telemt -f${NC}"
    echo -e "   Для просмотра логов Traefik: ${WHITE}docker-compose logs -f traefik${NC} (в $INSTALL_DIR)"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${SERVER}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   → вставь ПОЛНЫЙ секрет: ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${GREEN}💡 Теперь вы можете управлять прокси командой:${NC}"
    echo -e "   ${YELLOW}sudo yurich${NC}"
    echo ""
    show_github_link
}

show_github_link() {
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BLINK}   ⭐ Если скрипт был полезен, поставь звезду на GitHub!   ${NC}"
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/Pykucyka/yurichdelaetMTPoto-proxy${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ---------- Основная установка ----------
main() {
    banner
    check_root
    install_docker
    install_telemt
    get_params
    generate_secret
    setup_directories
    create_telemt_config
    create_telemt_service
    create_traefik_static
    create_traefik_dynamic
    create_docker_compose
    start_traefik
    get_public_ip
    open_firewall
    get_proxy_link
    create_global_command
    print_result
}

main "$@"
