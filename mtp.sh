#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer (Telemt from source)
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 11.0 (build from source, always latest)
# ============================================================

set -euo pipefail

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
    echo -e "${CYAN}║${NC}                         ${GREEN}v11.0${CYAN}                               ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Telemt (built from source) | Fake TLS${CYAN}         ║${NC}"
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

install_rust() {
    if ! command -v cargo &> /dev/null; then
        step "Rust не найден. Устанавливаем..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        success "Rust установлен"
    else
        success "Rust уже установлен"
    fi
}

build_telemt() {
    step "Клонируем репозиторий telemt..."
    cd /opt
    rm -rf telemt
    git clone https://github.com/telemt/telemt
    cd telemt

    step "Сборка telemt (cargo build --release)..."
    cargo build --release
    if [[ ! -f ./target/release/telemt ]]; then
        error "Сборка не удалась"
    fi

    cp ./target/release/telemt /usr/local/bin/telemt
    chmod +x /usr/local/bin/telemt
    success "Telemt собран и установлен в /usr/local/bin/telemt"
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

    read -p "Введите порт для прокси [443]: " PROXY_PORT
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

generate_secret() {
    step "Генерация Fake TLS секрета..."
    SECRET_PREFIX="ee"
    RANDOM_KEY=$(openssl rand -hex 16)
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps)
    SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
    success "Секрет создан"
}

create_config() {
    step "Создаём конфиг /etc/telemt/config.toml..."
    mkdir -p /etc/telemt
    cat > /etc/telemt/config.toml << EOF
# Telemt configuration with Fake TLS
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
    success "Конфиг создан"
}

create_systemd_service() {
    step "Настраиваем systemd сервис..."
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
    sleep 2
    if systemctl is-active --quiet telemt; then
        success "Telemt сервис запущен"
    else
        warn "Сервис не запустился. Проверьте логи: journalctl -u telemt"
    fi
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
    mkdir -p /opt/mtproto-proxy
    cat > /opt/mtproto-proxy/mtp.sh << 'EOF'
#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[0;31mЗапустите с sudo: sudo yurich\033[0m"
    exit 1
fi
while true; do
    clear
    echo -e "\033[0;36m=== Управление прокси Telemt ===\033[0m"
    echo "1) Посмотреть логи"
    echo "2) Перезапустить прокси"
    echo "3) Остановить прокси"
    echo "4) Запустить прокси"
    echo "5) Статус прокси"
    echo "6) Статистика (netstat)"
    echo "7) Показать ссылку"
    echo "0) Выход"
    read -p "Выберите действие: " choice
    case $choice in
        1) journalctl -u telemt -f ;;
        2) systemctl restart telemt ;;
        3) systemctl stop telemt ;;
        4) systemctl start telemt ;;
        5) systemctl status telemt --no-pager ;;
        6) ss -tlnp | grep telemt ;;
        7)
            SECRET=$(grep '^secret' /etc/telemt/config.toml | cut -d'"' -f2)
            PORT=$(grep '^bind' /etc/telemt/config.toml | grep -oP ':\K[0-9]+')
            IP=$(curl -s -4 ifconfig.me)
            echo -e "\033[0;32mСсылка: tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}\033[0m"
            read -p "Нажмите Enter..."
            ;;
        0) exit 0 ;;
        *) echo "Неверный выбор" ;;
    esac
done
EOF
    chmod +x /opt/mtproto-proxy/mtp.sh
    cat > /usr/local/bin/yurich << 'EOF'
#!/bin/bash
exec bash /opt/mtproto-proxy/mtp.sh
EOF
    chmod +x /usr/local/bin/yurich
    success "Глобальная команда 'yurich' создана"
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
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BLINK}   ⭐ Если скрипт был полезен, поставь звезду на GitHub!   ${NC}"
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/Pykucyka/yurichdelaetMTPoto-proxy${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

main() {
    banner
    check_root
    install_rust
    build_telemt
    get_params
    generate_secret
    create_config
    create_systemd_service
    get_server_addr
    open_firewall
    get_proxy_link
    create_global_command
    print_result
}

main "$@"
