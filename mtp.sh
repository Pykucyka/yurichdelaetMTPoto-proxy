#!/usr/bin/env bash

# =============================================
# MTProto Proxy Installer with Fake TLS
# Author: yurichdelaet
# GitHub: https://github.com/yurichdelaet/mtproto-proxy
# License: MIT
# =============================================

set -euo pipefail

# Цвета и стили
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
    echo -e "${CYAN}║${NC}                         ${GREEN}v2.1${CYAN}                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Функции вывода
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

# Установка Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        step "Docker не найден. Скачиваем установщик..."
        curl -# -o get-docker.sh https://get.docker.com
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

# Загрузка Docker-образа
pull_docker_image() {
    step "Загружаем Docker-образ ellermister/mtproxy (может занять некоторое время)..."
    docker pull ellermister/mtproxy
    success "Docker-образ загружен"
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

# Генерация секретов (короткий 32 символа и полный Fake TLS)
generate_secret() {
    step "Генерация секрета Fake TLS..."
    (
        sleep 0.5
        SECRET_PREFIX="ee"
        RANDOM_KEY=$(openssl rand -hex 16)          # 32 символа для бота
        DOMAIN_HEX=$(echo -n "$DOMAIN" | xxd -ps)
        FULL_SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
        echo "$RANDOM_KEY" > /tmp/mtproxy_short_secret
        echo "$FULL_SECRET" > /tmp/mtproxy_full_secret
    ) &
    spinner $!
    SHORT_SECRET=$(cat /tmp/mtproxy_short_secret)
    FULL_SECRET=$(cat /tmp/mtproxy_full_secret)
    rm -f /tmp/mtproxy_short_secret /tmp/mtproxy_full_secret
    success "Секрет создан (короткий: 32 символа)"
}

# Запуск контейнера
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
    sleep 1
    success "Контейнер запущен"
}

# Получение IP
get_public_ip() {
    step "Определяем внешний IP..."
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [[ -z "$IP" ]]; then
        warn "Не удалось определить IP автоматически"
        read -p "Введите IP сервера вручную: " IP
        [[ -z "$IP" ]] && error "IP не введён"
    else
        success "IP: $IP"
    fi
}

# Открытие порта в firewall
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

# Получение ссылки
get_proxy_link() {
    step "Ожидаем генерации ссылки прокси..."
    (
        sleep 3
        for i in {1..10}; do
            PROXY_LINK=$(docker logs mtproxy 2>&1 | grep -oE 'tg://proxy\?[^ ]+' | head -1)
            if [[ -n "$PROXY_LINK" ]]; then
                echo "$PROXY_LINK" > /tmp/mtproxy_link
                break
            fi
            sleep 1
        done
    ) &
    spinner $!
    if [[ -f /tmp/mtproxy_link ]]; then
        PROXY_LINK=$(cat /tmp/mtproxy_link)
        rm -f /tmp/mtproxy_link
    else
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
    banner
    success "Установка успешно завершена!"
    echo ""
    echo -e "${BOLD}📦 Данные прокси:${NC}"
    echo -e "   • IP:      ${CYAN}${IP}${NC}"
    echo -e "   • Порт:    ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   • Домен:   ${CYAN}${DOMAIN}${NC}"
    echo -e "   • Секрет для @MTProxybot (32 символа): ${YELLOW}${SHORT_SECRET}${NC}"
    echo -e "   • Полный секрет (для опытных): ${CYAN}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${BOLD}🔗 Готовая ссылка (нажми на неё в Telegram):${NC}"
    echo -e "   ${MAGENTA}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${BOLD}🤖 Регистрация в @MTProxybot:${NC}"
    echo -e "   1. Открой ${CYAN}@MTProxybot${NC}"
    echo -e "   2. Отправь /newproxy"
    echo -e "   3. Введи ${CYAN}${IP}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   4. Вставь короткий секрет (32 символа): ${YELLOW}${SHORT_SECRET}${NC}"
    echo -e "   5. Бот выдаст TAG — сохрани его (необязательно)."
    echo ""
    echo -e "${BOLD}🛠 Управление прокси:${NC}"
    echo -e "   • Логи:       ${YELLOW}docker logs -f mtproxy${NC}"
    echo -e "   • Перезапуск: ${YELLOW}docker restart mtproxy${NC}"
    echo -e "   • Удаление:   ${YELLOW}docker rm -f mtproxy${NC}"
    echo ""
    show_github_link
}

# Главная функция
main() {
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
    print_result
}

main "$@"
