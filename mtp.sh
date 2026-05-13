#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer with Fake TLS + Traefik
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 7.0 (Telemt + Traefik, single port 443)
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
    echo -e "${CYAN}║${NC}                         ${GREEN}v7.0${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Telemt + Traefik | Single Port 443${CYAN}            ║${NC}"
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
        step "Docker не найден. Скачиваем установщик..."
        curl -s --fail -o get-docker.sh https://get.docker.com || error "Не удалось скачать установщик Docker"
        echo -e "${GREEN}✓ Установщик загружен${NC}"
        step "Устанавливаем Docker (это может занять минуту)..."
        bash get-docker.sh > docker_install.log 2>&1 &
        spinner $!
        if [[ $? -eq 0 ]]; then
            rm -f get-docker.sh docker_install.log
            systemctl enable docker > /dev/null 2>&1
            systemctl start docker > /dev/null 2>&1
            success "Docker установлен"
        else
            error "Ошибка установки Docker. Логи: cat docker_install.log"
        fi
    else
        success "Docker уже установлен"
    fi
}

install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        step "Устанавливаем Docker Compose..."
        curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        success "Docker Compose установлен"
    else
        success "Docker Compose уже установлен"
    fi
}

get_params() {
    echo ""
    step "Настройка прокси (Telemt + Traefik)"
    echo -e "${YELLOW}Все подключения будут на порту 443 (единственный).${NC}"
    
    echo ""
    echo -e "${YELLOW}Выберите тип адреса для подключения:${NC}"
    echo "   1) IP-адрес (автоопределение)"
    echo "   2) Домен (введите вручную, должен указывать на этот сервер)"
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
        success "Будет использован домен: $CUSTOM_DOMAIN"
    else
        SERVER_ADDR=""
        success "Будет использован IP-адрес сервера"
    fi

    read -p "Домен маскировки (Fake TLS, например 1c.ru или sberbank.ru) [1c.ru]: " MASK_DOMAIN
    MASK_DOMAIN=${MASK_DOMAIN:-1c.ru}
    success "Домен маскировки: $MASK_DOMAIN"
}

generate_secret() {
    step "Генерация 32-символьного секрета (hex)..."
    SECRET=$(openssl rand -hex 16)
    success "Секрет: $SECRET"
}

setup_files() {
    step "Создаём структуру каталогов и конфигурационные файлы..."
    
    INSTALL_DIR="/opt/mtproto-proxy"
    mkdir -p "$INSTALL_DIR"/{traefik/static,traefik/dynamic}
    cd "$INSTALL_DIR"
    
    # docker-compose.yml
    cat > docker-compose.yml << 'EOF'
services:
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    network_mode: host
    command:
      - "--configFile=/traefik.yml"
    volumes:
      - ./traefik/static/traefik.yml:/traefik.yml:ro
      - ./traefik/dynamic/tcp.yml:/dynamic/tcp.yml:ro
    logging:
      options:
        max-size: "10m"

  telemt:
    image: whn0thacked/telemt-docker:latest
    container_name: mtproxy-telemt
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./telemt.toml:/app/telemt.toml:ro
    environment:
      - RUST_LOG=info
    logging:
      options:
        max-size: "10m"
EOF

    # traefik/static/traefik.yml
    cat > traefik/static/traefik.yml << 'EOF'
global:
  sendAnonymousUsage: false

log:
  level: INFO

entryPoints:
  https:
    address: ":443"

providers:
  file:
    filename: /dynamic/tcp.yml
    watch: true
EOF

    # traefik/dynamic/tcp.yml (будет заполнен с подстановкой маскирующего домена)
    cat > traefik/dynamic/tcp.yml << 'EOF'
tcp:
  routers:
    mtproto:
      entryPoints:
        - "https"
      rule: "HostSNI(`__MASK_DOMAIN__`)"
      service: telemt
      tls:
        passthrough: true

  services:
    telemt:
      loadBalancer:
        servers:
          - address: "127.0.0.1:1234"
EOF
    sed -i "s/__MASK_DOMAIN__/${MASK_DOMAIN}/g" traefik/dynamic/tcp.yml

    # telemt.toml (шаблон)
    cat > telemt.toml << 'EOF'
secret = "__SECRET__"
[telemetry]
  prometheus = "0.0.0.0:9090"
[censorship]
  tls_domain = "__MASK_DOMAIN__"
  pad_interval = [10, 20]
EOF
    sed -i "s/__SECRET__/${SECRET}/g" telemt.toml
    sed -i "s/__MASK_DOMAIN__/${MASK_DOMAIN}/g" telemt.toml

    success "Конфигурационные файлы созданы в $INSTALL_DIR"
}

run_containers() {
    step "Запускаем контейнеры через docker-compose..."
    cd /opt/mtproto-proxy
    docker-compose up -d
    success "Контейнеры запущены"
}

get_public_ip() {
    if [[ -n "${SERVER_ADDR:-}" ]]; then
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
        step "Открываем порт 443 в UFW..."
        ufw allow 443/tcp > /dev/null 2>&1
        success "Порт 443 открыт (UFW)"
    elif command -v firewall-cmd &> /dev/null; then
        step "Открываем порт 443 в firewalld..."
        firewall-cmd --permanent --add-port=443/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        success "Порт 443 открыт (firewalld)"
    else
        warn "Firewall не обнаружен. Убедитесь, что порт 443 открыт вручную."
    fi
}

get_proxy_link() {
    # Формируем полный Fake TLS секрет для ссылки: ee + 32-символьный секрет + hex(домен маскировки)
    DOMAIN_HEX=$(echo -n "$MASK_DOMAIN" | xxd -ps)
    FULL_SECRET="ee${SECRET}${DOMAIN_HEX}"
    PROXY_LINK="tg://proxy?server=${SERVER}&port=443&secret=${FULL_SECRET}"
    success "Ссылка для подключения готова"
}

create_global_command() {
    cat > /usr/local/bin/yurich << 'EOF'
#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[0;31mПожалуйста, запустите с sudo: sudo yurich\033[0m"
    exit 1
fi
SCRIPT_PATH="/opt/mtproto-proxy/mtp.sh"
if [[ -f "$SCRIPT_PATH" ]]; then
    exec bash "$SCRIPT_PATH" --menu
else
    echo -e "\033[0;31mСкрипт управления не найден. Переустановите прокси.\033[0m"
    exit 1
fi
EOF
    chmod +x /usr/local/bin/yurich
    success "Глобальная команда 'yurich' создана (запускайте: sudo yurich)"
}

# Функции меню (управление)
show_stats() {
    clear
    banner
    echo -e "${GREEN}📊 СТАТИСТИКА ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cd /opt/mtproto-proxy
    if ! docker ps | grep -q "traefik\|telemt"; then
        echo -e "${RED}❌ Контейнеры не запущены!${NC}"
        echo -e "Запустите: ${YELLOW}docker-compose up -d${NC} в /opt/mtproto-proxy"
        echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
        read
        return
    fi
    echo -e "${YELLOW}📈 Использование ресурсов (CPU / RAM):${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "traefik|telemt|CONTAINER" | sed 's/^/   /'
    echo ""
    echo -e "${YELLOW}🌐 Логи Telemt (последние строки):${NC}"
    docker logs --tail=10 mtproxy-telemt 2>&1 | tail -10 | sed 's/^/   /'
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

show_info() {
    clear
    banner
    echo -e "${GREEN}ℹ️  ИНФОРМАЦИЯ О ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cd /opt/mtproto-proxy
    if [[ -f telemt.toml ]]; then
        SECRET=$(grep '^secret' telemt.toml | cut -d'"' -f2)
        MASK_DOMAIN=$(grep 'tls_domain' telemt.toml | cut -d'"' -f2)
        DOMAIN_HEX=$(echo -n "$MASK_DOMAIN" | xxd -ps)
        FULL_SECRET="ee${SECRET}${DOMAIN_HEX}"
        echo -e "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}${SERVER}${NC}"
        echo -e "   ${BOLD}Порт:${NC}                 ${YELLOW}443${NC}"
        echo -e "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}${MASK_DOMAIN}${NC}"
        echo -e "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}"
        echo -e "   ${WHITE}${FULL_SECRET}${NC}"
        echo ""
        echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
        echo -e "   Telegram-ссылка: ${GREEN}tg://proxy?server=${SERVER}&port=443&secret=${FULL_SECRET}${NC}"
    else
        echo -e "${RED}Файл конфигурации не найден${NC}"
    fi
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

update_script() {
    clear
    banner
    echo -e "${GREEN}🔄 ОБНОВЛЕНИЕ СКРИПТА${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    if [[ -d ".git" ]]; then
        git pull origin main
        echo -e "${GREEN}✅ Скрипт обновлён.${NC}"
    else
        cd /tmp
        rm -rf yurichdelaetMTPoto-proxy 2>/dev/null || true
        git clone https://github.com/Pykucyka/yurichdelaetMTPoto-proxy.git || error "Не удалось клонировать репозиторий"
        cp yurichdelaetMTPoto-proxy/mtp.sh "$SCRIPT_DIR/mtp.sh"
        chmod +x "$SCRIPT_DIR/mtp.sh"
        rm -rf yurichdelaetMTPoto-proxy
        echo -e "${GREEN}✅ Скрипт обновлён.${NC}"
    fi
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

reinstall_proxy() {
    clear
    banner
    echo -e "${GREEN}🔄 ПЕРЕУСТАНОВКА ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cd /opt/mtproto-proxy
    docker-compose down
    rm -rf /opt/mtproto-proxy
    echo -e "Старые данные удалены. Запустите установку заново: ${YELLOW}./mtp.sh${NC}"
    echo -e "\n${BOLD}Нажмите Enter, чтобы выйти...${NC}"
    read
    exit 0
}

view_logs() {
    clear
    banner
    echo -e "${GREEN}📜 ПОСЛЕДНИЕ ЛОГИ КОНТЕЙНЕРОВ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cd /opt/mtproto-proxy
    docker-compose logs --tail=50
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

restart_proxy() {
    clear
    banner
    echo -e "${GREEN}🔄 ПЕРЕЗАПУСК ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cd /opt/mtproto-proxy
    docker-compose restart
    success "Контейнеры перезапущены"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

change_domain() {
    clear
    banner
    echo -e "${GREEN}🌐 ИЗМЕНЕНИЕ ДОМЕНА/IP${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "Текущий адрес: ${YELLOW}${SERVER}${NC}"
    read -p "Введите новый домен или IP (оставьте пустым для автоопределения IP): " NEW_ADDR
    if [[ -n "$NEW_ADDR" ]]; then
        SERVER="$NEW_ADDR"
        success "Адрес изменён на: $SERVER"
        # Обновляем ссылку (пересоздаём её при следующем запросе информации)
    else
        NEW_IP=$(curl -s -4 ifconfig.me || echo "")
        if [[ -n "$NEW_IP" ]]; then
            SERVER="$NEW_IP"
            success "IP обновлён автоматически: $SERVER"
        else
            warn "Не удалось определить IP автоматически, оставлен старый: $SERVER"
        fi
    fi
    # Сохраняем новый адрес
    echo "$SERVER" > /opt/mtproto-proxy/current_addr
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

show_menu() {
    SERVER=$(cat /opt/mtproto-proxy/current_addr 2>/dev/null || curl -s -4 ifconfig.me || echo "unknown")
    while true; do
        clear
        banner
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    📋 МЕНЮ УПРАВЛЕНИЯ                      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "   ${CYAN}1${NC} ─ ${YELLOW}📊 Статистика прокси${NC}"
        echo -e "   ${CYAN}2${NC} ─ ${YELLOW}ℹ️  Информация о прокси (секрет, ссылка)${NC}"
        echo -e "   ${CYAN}3${NC} ─ ${YELLOW}🌐 Изменить домен/IP для подключения${NC}"
        echo -e "   ${CYAN}4${NC} ─ ${YELLOW}🔄 Обновить скрипт до актуальной версии${NC}"
        echo -e "   ${CYAN}5${NC} ─ ${YELLOW}🔁 Полная переустановка прокси (удалить всё)${NC}"
        echo -e "   ${CYAN}6${NC} ─ ${YELLOW}📜 Просмотр последних логов${NC}"
        echo -e "   ${CYAN}7${NC} ─ ${YELLOW}♻️  Перезапустить прокси-контейнеры${NC}"
        echo -e "   ${CYAN}0${NC} ─ ${RED}🚪 Выход (вернуться в командную строку)${NC}"
        echo ""
        echo -ne "${BOLD}Выберите пункт меню (0-7): ${NC}"
        read choice
        case $choice in
            1) show_stats ;;
            2) show_info ;;
            3) change_domain ;;
            4) update_script ;;
            5) reinstall_proxy ;;
            6) view_logs ;;
            7) restart_proxy ;;
            0)
                clear
                echo -e "${GREEN}До свидания! Для повторного входа выполните: sudo yurich${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Неверный выбор. Нажмите Enter...${NC}"
                read
                ;;
        esac
    done
}

install_proxy() {
    banner
    check_root
    install_docker
    install_docker_compose
    get_params
    generate_secret
    setup_files
    run_containers
    get_public_ip
    open_firewall
    get_proxy_link
    echo "$SERVER" > /opt/mtproto-proxy/current_addr
    # Сохраняем скрипт в папку установки для глобальной команды
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
    if [[ "$SCRIPT_SOURCE" == "/dev/fd/"* ]] || [[ ! -f "$SCRIPT_SOURCE" ]]; then
        curl -s --fail -o /opt/mtproto-proxy/mtp.sh "https://raw.githubusercontent.com/Pykucyka/yurichdelaetMTPoto-proxy/main/mtp.sh" || error "Не удалось сохранить скрипт"
        chmod +x /opt/mtproto-proxy/mtp.sh
    else
        cp "$SCRIPT_SOURCE" /opt/mtproto-proxy/mtp.sh
        chmod +x /opt/mtproto-proxy/mtp.sh
    fi
    create_global_command
    print_result
}

print_result() {
    clear
    banner
    echo -e "${GREEN}✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА${NC}"
    echo ""
    echo -e "${CYAN}📡 ПАРАМЕТРЫ ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    printf "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}%s${NC}\n" "$SERVER"
    printf "   ${BOLD}Порт:${NC}                 ${YELLOW}%s${NC}\n" "443"
    printf "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}%s${NC}\n" "$MASK_DOMAIN"
    printf "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}\n"
    FULL_SECRET="ee$(echo -n "$SECRET")$(echo -n "$MASK_DOMAIN" | xxd -ps)"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────${NC}"
    echo -e "   ${BOLD}Telegram-ссылка:${NC} ${GREEN}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}📊 СТАТИСТИКА И ТЕЛЕМЕТРИЯ${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "   Для просмотра статистики используйте меню прокси: ${YELLOW}sudo yurich${NC}"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${SERVER}${NC} и порт ${CYAN}443${NC}"
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

main() {
    if [[ "${1:-}" == "--menu" ]]; then
        if ! docker ps -a &>/dev/null || ! docker ps | grep -q "traefik\|telemt"; then
            echo -e "${RED}❌ Прокси не установлен или контейнеры не запущены.${NC}"
            echo -e "Сначала установите: ${YELLOW}./mtp.sh${NC}"
            exit 1
        fi
        show_menu
    else
        install_proxy
    fi
}

main "$@"
