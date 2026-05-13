#!/usr/bin/env bash

# =============================================
# MTProto Proxy Installer with Fake TLS
# Author: yurichdelaet
# GitHub: https://github.com/yurichdelaet/mtproto-proxy
# License: MIT
# =============================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
BLINK='\033[5m'
NC='\033[0m'

# Прогресс-бар
progress_bar() {
    local duration=$1
    local steps=20
    local sleep_interval=$(echo "$duration / $steps" | bc -l)
    echo -ne "${CYAN}["
    for ((i=0; i<=steps; i++)); do
        echo -ne "█"
        sleep "$sleep_interval"
    done
    echo -e "]${NC}"
}

# Баннер (короткий, без ascii-арта, но красивый)
banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🚀 MTProto Proxy Installer by yurichdelaet  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
}

# Функции
step() { echo -e "${BLUE}[➜]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Запустите скрипт с правами root: sudo ./mtp.sh"
    fi
}

# Установка Docker с прогресс-баром
install_docker() {
    if ! command -v docker &> /dev/null; then
        step "Docker не найден. Устанавливаем..."
        curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
        progress_bar 2
        sh get-docker.sh > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
        systemctl start docker > /dev/null 2>&1
        rm -f get-docker.sh
        success "Docker установлен"
    else
        success "Docker уже установлен"
    fi
}

# Ввод параметров
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

# Генерация секрета
generate_secret() {
    step "Генерация секрета Fake TLS..."
    SECRET_PREFIX="ee"
    RANDOM_KEY=$(openssl rand -hex 16)
    DOMAIN_HEX=$(echo -n "$DOMAIN" | xxd -ps)
    FULL_SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
    success "Секрет создан"
}

# Запуск контейнера с прогресс-баром
run_container() {
    step "Запускаем контейнер..."
    docker rm -f mtproxy 2>/dev/null || true
    docker run -d \
        --name mtproxy \
        --restart=always \
        -p ${PROXY_PORT}:443 \
        -p 8080:80 \
        -e SECRET="${FULL_SECRET}" \
        ellermister/mtproxy > /dev/null
    progress_bar 2
    success "Контейнер запущен"
}

# Получение IP
get_public_ip() {
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [[ -z "$IP" ]]; then
        warn "Не удалось определить IP автоматически"
        read -p "Введите IP сервера вручную: " IP
        [[ -z "$IP" ]] && error "IP не введён"
    fi
}

# Открытие порта
open_firewall() {
    if command -v ufw &> /dev/null; then
        step "Открываем порт $PROXY_PORT в UFW..."
        ufw allow ${PROXY_PORT}/tcp > /dev/null 2>&1
        success "Порт открыт"
    elif command -v firewall-cmd &> /dev/null; then
        step "Открываем порт $PROXY_PORT в firewalld..."
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        success "Порт открыт"
    else
        warn "Firewall не обнаружен. Убедитесь, что порт $PROXY_PORT открыт вручную."
    fi
}

# Получение ссылки с прогресс-баром
get_proxy_link() {
    step "Ожидаем генерации ссылки..."
    progress_bar 3
    for i in {1..10}; do
        PROXY_LINK=$(docker logs mtproxy 2>&1 | grep -oE 'tg://proxy\?[^ ]+' | head -1)
        if [[ -n "$PROXY_LINK" ]]; then
            break
        fi
        sleep 1
    done
    if [[ -z "$PROXY_LINK" ]]; then
        warn "Не удалось получить ссылку из логов. Используем сгенерированную вручную."
        PROXY_LINK="tg://proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}"
    fi
}

# Яркая ссылка на GitHub
show_github_link() {
    echo ""
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BLINK}   ⭐ Если скрипт был полезен, поставь звезду на GitHub!   ${NC}"
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/yurichdelaet/mtproto-proxy       ${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Итоговый вывод
print_result() {
    clear
    banner
    echo ""
    success "Установка завершена!"
    echo ""
    echo -e "${BOLD}📦 Данные прокси:${NC}"
    echo -e "   • IP:      ${CYAN}${IP}${NC}"
    echo -e "   • Порт:    ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   • Домен:   ${CYAN}${DOMAIN}${NC}"
    echo -e "   • Секрет:  ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${BOLD}🔗 Готовая ссылка (нажми на неё в Telegram):${NC}"
    echo -e "   ${MAGENTA}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${BOLD}🤖 Регистрация в @MTProxybot:${NC}"
    echo -e "   1. Открой ${CYAN}@MTProxybot${NC}"
    echo -e "   2. Отправь /newproxy"
    echo -e "   3. Введи ${CYAN}${IP}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   4. Вставь секрет: ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${BOLD}🛠 Управление:${NC}"
    echo -e "   • Логи:       ${YELLOW}docker logs -f mtproxy${NC}"
    echo -e "   • Перезапуск: ${YELLOW}docker restart mtproxy${NC}"
    echo -e "   • Удаление:   ${YELLOW}docker rm -f mtproxy${NC}"
    echo ""
    show_github_link
}

# Главная функция
main() {
    clear
    banner
    check_root
    install_docker
    get_params
    generate_secret
    run_container
    get_public_ip
    open_firewall
    get_proxy_link
    print_result
}

main "$@"
