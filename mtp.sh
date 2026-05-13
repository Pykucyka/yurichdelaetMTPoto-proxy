#!/usr/bin/env bash

# =============================================
# MTProto Proxy Installer with Fake TLS
# Author: yurichdelaet
# GitHub: https://github.com/yurichdelaet/mtproto-proxy
# License: MIT
# Version: 3.3 (fixed global command)
# =============================================

set -euo pipefail

# Цвета
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

# Спиннер
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" &>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Баннер
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
    echo -e "${CYAN}║${NC}                         ${GREEN}v3.3${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Global command: yurich | TUI Menu${CYAN}              ║${NC}"
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
        curl -s -o get-docker.sh https://get.docker.com &
        spinner $!
        echo -e "${GREEN}✓ Установщик загружен${NC}"
        step "Устанавливаем Docker (это может занять минуту)..."
        bash get-docker.sh > docker_install.log 2>&1 &
        spinner $!
        if [ $? -eq 0 ]; then
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

pull_docker_image() {
    step "Загружаем Docker-образ ellermister/mtproxy (Fake TLS)..."
    docker pull ellermister/mtproxy
    success "Образ загружен"
}

get_params() {
    echo ""
    step "Настройка прокси (Enter = значения по умолчанию)"
    read -p "Введите порт [8443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-8443}
    read -p "Домен маскировки [cloudflare.com]: " DOMAIN
    DOMAIN=${DOMAIN:-cloudflare.com}
    if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
        error "Неверный порт"
    fi
    success "Порт: $PROXY_PORT, домен: $DOMAIN"
}

generate_secret() {
    step "Генерация Fake TLS секрета..."
    (
        sleep 0.5
        SECRET_PREFIX="ee"
        RANDOM_KEY=$(openssl rand -hex 16)
        DOMAIN_HEX=$(echo -n "$DOMAIN" | xxd -ps)
        FULL_SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
        echo "$FULL_SECRET" > /tmp/mtproxy_full_secret
    ) &
    spinner $!
    FULL_SECRET=$(cat /tmp/mtproxy_full_secret)
    rm -f /tmp/mtproxy_full_secret
    success "Секрет создан"
}

run_container() {
    step "Запускаем контейнер ellermister/mtproxy..."
    docker rm -f mtproxy 2>/dev/null || true
    docker run -d \
        --name mtproxy \
        --restart=always \
        -p ${PROXY_PORT}:443 \
        -p 8080:80 \
        -e SECRET="${FULL_SECRET}" \
        ellermister/mtproxy > /dev/null
    sleep 2
    success "Контейнер запущен"
}

get_public_ip() {
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [[ -z "$IP" ]]; then
        warn "Не удалось определить IP автоматически"
        read -p "Введите IP сервера вручную: " IP
        [[ -z "$IP" ]] && error "IP не введён"
    fi
}

open_firewall() {
    if command -v ufw &> /dev/null; then
        step "Открываем порт $PROXY_PORT в UFW..."
        ufw allow ${PROXY_PORT}/tcp > /dev/null 2>&1
        ufw allow 8080/tcp > /dev/null 2>&1
        success "Порты открыты (UFW)"
    elif command -v firewall-cmd &> /dev/null; then
        step "Открываем порт $PROXY_PORT в firewalld..."
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=8080/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        success "Порты открыты (firewalld)"
    else
        warn "Firewall не обнаружен. Убедитесь, что порты $PROXY_PORT и 8080 открыты вручную."
    fi
}

get_proxy_link() {
    step "Ожидаем генерации ссылки..."
    sleep 3
    PROXY_LINK=$(docker logs mtproxy 2>&1 | grep -oE 'tg://proxy\?[^ ]+' | head -1)
    if [[ -z "$PROXY_LINK" ]]; then
        PROXY_LINK="tg://proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}"
    fi
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

# TUI-меню
show_stats() {
    clear
    banner
    echo -e "${GREEN}📊 СТАТИСТИКА ПРОКСИ В РЕАЛЬНОМ ВРЕМЕНИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    if ! docker ps | grep -q mtproxy; then
        echo -e "${RED}❌ Контейнер mtproxy не запущен!${NC}"
        echo -e "Запустите: ${YELLOW}docker start mtproxy${NC}"
        echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
        read
        return
    fi
    echo -e "${YELLOW}📈 Использование ресурсов (CPU / RAM / NET):${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -E "mtproxy|CONTAINER" | sed 's/^/   /'
    echo ""
    echo -e "${YELLOW}🌐 Сетевые подключения:${NC}"
    CONNS=$(docker exec mtproxy ss -tun 2>/dev/null | tail -n +2 | wc -l || echo "0")
    echo -e "   ➤ Активных TCP-соединений: ${GREEN}${CONNS}${NC}"
    echo ""
    echo -e "${YELLOW}📡 Веб-интерфейс статистики:${NC}"
    echo -e "   ➤ http://${IP}:8080 (статистика подключений)"
    echo -e "   ➤ Для просмотра логов используйте пункт меню 'Логи'"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

show_info() {
    clear
    banner
    echo -e "${GREEN}ℹ️  ИНФОРМАЦИЯ О ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    PROXY_PORT=$(docker inspect mtproxy 2>/dev/null | grep -oP '"HostPort":\s*"\K[^"]+' | head -1 || echo "8443")
    FULL_SECRET=$(docker exec mtproxy env 2>/dev/null | grep '^SECRET=' | cut -d= -f2)
    if [[ -z "$FULL_SECRET" ]]; then
        FULL_SECRET="(не удалось получить)"
    fi
    if [[ ${#FULL_SECRET} -gt 6 ]]; then
        DOMAIN_HEX=$(echo "$FULL_SECRET" | sed 's/^ee[0-9a-f]\{32\}//')
        DOMAIN=$(echo -n "$DOMAIN_HEX" | xxd -p -r 2>/dev/null || echo "cloudflare.com")
    else
        DOMAIN="cloudflare.com"
    fi
    echo -e "   ${BOLD}IP-адрес сервера:${NC}     ${YELLOW}${IP}${NC}"
    echo -e "   ${BOLD}Порт:${NC}                 ${YELLOW}${PROXY_PORT}${NC}"
    echo -e "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}${DOMAIN}${NC}"
    echo -e "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "   Telegram-ссылка: ${GREEN}tg://proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
    echo -e "   Альтернативная: ${WHITE}https://t.me/proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
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
        echo -e "${RED}❌ Репозиторий не найден. Скачиваем заново...${NC}"
        cd /tmp
        git clone https://github.com/yurichdelaet/mtproto-proxy.git
        cp mtproto-proxy/mtp.sh "$SCRIPT_DIR/mtp.sh"
        chmod +x "$SCRIPT_DIR/mtp.sh"
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
    OLD_SECRET=$(docker inspect mtproxy 2>/dev/null | grep -oP '"SECRET":\s*"\K[^"]+' || echo "")
    if [[ -n "$OLD_SECRET" ]]; then
        echo -e "Используем существующий секрет."
        FULL_SECRET="$OLD_SECRET"
        PROXY_PORT=$(docker inspect mtproxy | grep -oP '"HostPort":\s*"\K[^"]+' | head -1)
    else
        echo -e "Генерация нового секрета..."
        read -p "Введите порт [8443]: " PROXY_PORT
        PROXY_PORT=${PROXY_PORT:-8443}
        read -p "Домен маскировки [cloudflare.com]: " DOMAIN
        DOMAIN=${DOMAIN:-cloudflare.com}
        generate_secret
    fi
    docker rm -f mtproxy 2>/dev/null || true
    docker run -d \
        --name mtproxy \
        --restart=always \
        -p ${PROXY_PORT:-8443}:443 \
        -p 8080:80 \
        -e SECRET="${FULL_SECRET}" \
        ellermister/mtproxy > /dev/null
    sleep 2
    success "Прокси переустановлен"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

view_logs() {
    clear
    banner
    echo -e "${GREEN}📜 ПОСЛЕДНИЕ ЛОГИ ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    docker logs --tail=50 mtproxy 2>&1 | tail -50
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

restart_proxy() {
    clear
    banner
    echo -e "${GREEN}🔄 ПЕРЕЗАПУСК ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    docker restart mtproxy
    success "Прокси перезапущен"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

show_menu() {
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "unknown")
    while true; do
        clear
        banner
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    📋 МЕНЮ УПРАВЛЕНИЯ                      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "   ${CYAN}1${NC} ─ ${YELLOW}📊 Статистика прокси (нагрузка, подключения)${NC}"
        echo -e "   ${CYAN}2${NC} ─ ${YELLOW}ℹ️  Информация о прокси (секрет, ссылка)${NC}"
        echo -e "   ${CYAN}3${NC} ─ ${YELLOW}🔄 Обновить скрипт до актуального коммита${NC}"
        echo -e "   ${CYAN}4${NC} ─ ${YELLOW}🔁 Переустановить прокси (сохраняя секрет)${NC}"
        echo -e "   ${CYAN}5${NC} ─ ${YELLOW}📜 Просмотр последних логов${NC}"
        echo -e "   ${CYAN}6${NC} ─ ${YELLOW}♻️  Перезапустить прокси-контейнер${NC}"
        echo -e "   ${CYAN}0${NC} ─ ${RED}🚪 Выход (вернуться в командную строку)${NC}"
        echo ""
        echo -ne "${BOLD}Выберите пункт меню (0-6): ${NC}"
        read choice
        case $choice in
            1) show_stats ;;
            2) show_info ;;
            3) update_script ;;
            4) reinstall_proxy ;;
            5) view_logs ;;
            6) restart_proxy ;;
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
    pull_docker_image
    get_params
    generate_secret
    run_container
    get_public_ip
    open_firewall
    get_proxy_link
    mkdir -p /opt/mtproto-proxy
    cp "$0" /opt/mtproto-proxy/mtp.sh
    chmod +x /opt/mtproto-proxy/mtp.sh
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
    printf "   ${BOLD}IP-адрес сервера:${NC}     ${YELLOW}%s${NC}\n" "$IP"
    printf "   ${BOLD}Порт:${NC}                 ${YELLOW}%s${NC}\n" "$PROXY_PORT"
    printf "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}%s${NC}\n" "$DOMAIN"
    printf "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}\n"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────${NC}"
    echo -e "   ${BOLD}Telegram-ссылка:${NC} ${GREEN}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}📊 СТАТИСТИКА И ТЕЛЕМЕТРИЯ${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "   Статистика в веб-интерфейсе: ${WHITE}http://${IP}:8080${NC}"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${IP}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   → вставь секрет: ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${GREEN}💡 Теперь вы можете управлять прокси командой:${NC}"
    echo -e "   ${YELLOW}sudo yurich${NC}"
    echo ""
    show_github_link
}

show_github_link() {
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BLINK}   ⭐ Если скрипт был полезен, поставь звезду на GitHub!   ${NC}"
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/yurichdelaet/mtproto-proxy       ${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

main() {
    if [[ "${1:-}" == "--menu" ]]; then
        if ! docker ps -a &>/dev/null || ! docker inspect mtproxy &>/dev/null; then
            echo -e "${RED}❌ Прокси не установлен или Docker не запущен.${NC}"
            echo -e "Сначала установите: ${YELLOW}./mtp.sh${NC}"
            exit 1
        fi
        show_menu
    else
        install_proxy
    fi
}

main "$@"
