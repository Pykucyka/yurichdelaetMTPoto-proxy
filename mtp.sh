#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer with Telemt (Fake TLS)
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 7.8 (direct stable download, no API)
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
    echo -e "${CYAN}║${NC}                         ${GREEN}v7.8${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Telemt (native) | Fake TLS on port 443${CYAN}         ║${NC}"
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

get_params() {
    echo ""
    echo -e "${YELLOW}Выберите язык для вывода сообщений:${NC}"
    echo "   1) English"
    echo "   2) Русский"
    read -p "Ваш выбор [1/2]: " LANG_CHOICE
    if [[ "$LANG_CHOICE" == "2" ]]; then
        success "Выбран русский язык"
    else
        success "Selected English language"
    fi

    echo ""
    read -p "Введите домен маскировки (Fake TLS) [1c.ru]: " FAKE_DOMAIN
    FAKE_DOMAIN=${FAKE_DOMAIN:-1c.ru}
    success "Домен маскировки: $FAKE_DOMAIN"

    read -p "Введите порт для прокси (рекомендуется 443) [443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-443}
    if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
        error "Неверный порт"
    fi
    success "Порт: $PROXY_PORT"

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
}

# ---------- Надёжная установка telemt (без API, прямая загрузка стабильной версии) ----------
install_telemt_binary() {
    step "Загружаем telemt (стабильная версия 0.5.0)..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) error "Неподдерживаемая архитектура: $ARCH. Поддерживаются только x86_64 и arm64." ;;
    esac
    
    URL="https://github.com/telemt/telemt/releases/download/v0.5.0/telemt-linux-${ARCH}"
    step "Скачивание с $URL"
    curl -L --progress-bar --connect-timeout 15 --max-time 60 -o /usr/local/bin/telemt "$URL"
    if [[ ! -f /usr/local/bin/telemt ]]; then
        error "Не удалось скачать telemt. Проверьте соединение с GitHub."
    fi
    chmod +x /usr/local/bin/telemt
    success "Telemt установлен в /usr/local/bin/telemt"
}

create_telemt_config() {
    step "Создаём конфиг Telemt с Fake TLS секретом..."
    SECRET_PREFIX="ee"
    RANDOM_KEY=$(openssl rand -hex 16)
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps)
    SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
    
    mkdir -p /etc/telemt
    cat > /etc/telemt/config.toml << EOF
secret = "$SECRET"
bind = "0.0.0.0:$PROXY_PORT"
users = []
timeout = 300
keepalive = 30
fast_mode = true
ipv6 = false
trace = false

[censorship]
tls_domain = "$FAKE_DOMAIN"
EOF
    success "Конфиг создан (/etc/telemt/config.toml)"
}

enable_telemt_service() {
    step "Настраиваем systemd сервис для Telemt..."
    cat > /etc/systemd/system/telemt.service << EOF
[Unit]
Description=Telemt MTProto Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/telemt
ExecStart=/usr/local/bin/telemt /etc/telemt/config.toml
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

get_server_addr() {
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
    PROXY_LINK="tg://proxy?server=${SERVER}&port=${PROXY_PORT}&secret=${SECRET}"
    success "Ссылка для подключения готова"
}

create_global_command() {
    cat > /usr/local/bin/yurich << 'EOF'
#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[0;31mПожалуйста, запустите с sudo: sudo yurich\033[0m"
    exit 1
fi
echo -e "\033[0;36m=== Управление прокси Telemt ===\033[0m"
echo "1) Посмотреть логи"
echo "2) Перезапустить Telemt"
echo "3) Остановить Telemt"
echo "4) Запустить Telemt"
echo "5) Показать статус"
echo "6) Показать статистику (netstat)"
echo "0) Выход"
read -p "Выберите действие: " choice
case $choice in
    1) journalctl -u telemt -f ;;
    2) systemctl restart telemt ;;
    3) systemctl stop telemt ;;
    4) systemctl start telemt ;;
    5) systemctl status telemt --no-pager ;;
    6) ss -tlnp | grep telemt ;;
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
    echo -e "   ${WHITE}${SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────${NC}"
    echo -e "   ${BOLD}Telegram-ссылка:${NC} ${GREEN}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}📊 СТАТИСТИКА И ТЕЛЕМЕТРИЯ${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "   Для просмотра логов: ${WHITE}journalctl -u telemt -f${NC}"
    echo -e "   Для проверки статуса: ${WHITE}systemctl status telemt${NC}"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${SERVER}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   → вставь ПОЛНЫЙ секрет: ${YELLOW}${SECRET}${NC}"
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
    get_params
    install_telemt_binary
    create_telemt_config
    enable_telemt_service
    get_server_addr
    open_firewall
    get_proxy_link
    create_global_command
    print_result
}

main "$@"
