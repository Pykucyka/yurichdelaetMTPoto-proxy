#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer with Fake TLS & Auto-Updater
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 4.0
# ============================================================

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

# Версия скрипта (локальная)
SCRIPT_VERSION="4.0"
REPO_OWNER="Pykucyka"
REPO_NAME="yurichdelaetMTPoto-proxy"
REPO_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/mtp.sh"

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
    echo -e "${CYAN}║${NC}                         ${GREEN}v${SCRIPT_VERSION}${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Auto-update | TUI Menu | Domain support${CYAN}       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Вспомогательные функции
step() { echo -e "${BLUE}[➜]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

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

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Запустите скрипт с правами root: sudo ./mtp.sh"
    fi
}

# Автообновление скрипта
auto_update() {
    # Получаем удалённую версию
    local remote_version=$(curl -s -m 5 "$REPO_URL" | grep -m1 'SCRIPT_VERSION="' | sed 's/.*SCRIPT_VERSION="\([^"]*\)".*/\1/')
    if [[ -n "$remote_version" && "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "${YELLOW}Доступна новая версия $remote_version (текущая $SCRIPT_VERSION)${NC}"
        echo -n "Обновить? [Y/n]: "
        read -r answer
        if [[ "$answer" != "n" && "$answer" != "N" ]]; then
            echo -e "${BLUE}Обновляем скрипт...${NC}"
            local temp_script=$(mktemp)
            curl -s -o "$temp_script" "$REPO_URL"
            if [[ -s "$temp_script" ]]; then
                cp "$temp_script" "$0"
                chmod +x "$0"
                rm "$temp_script"
                echo -e "${GREEN}Обновлено! Перезапустите команду.${NC}"
                exit 0
            else
                warn "Не удалось загрузить обновление"
            fi
        fi
    fi
}

# Установка Docker
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

# Проверка DNS для домена
check_dns() {
    local domain=$1
    local server_ip=$2
    local resolved_ip=$(dig +short "$domain" | head -1)
    if [[ -z "$resolved_ip" ]]; then
        warn "Домен $domain не резолвится в IP. Убедитесь, что DNS запись настроена."
        read -p "Продолжить всё равно? [y/N]: " cont
        [[ "$cont" != "y" && "$cont" != "Y" ]] && error "Установка отменена."
    elif [[ "$resolved_ip" != "$server_ip" ]]; then
        warn "Домен $domain резолвится в $resolved_ip, но IP сервера $server_ip. Убедитесь, что A-запись указывает на этот сервер."
        read -p "Продолжить? [y/N]: " cont
        [[ "$cont" != "y" && "$cont" != "Y" ]] && error "Установка отменена."
    else
        success "DNS проверка пройдена: домен -> $resolved_ip"
    fi
}

# Получение параметров установки
get_params() {
    echo ""
    step "Настройка прокси"
    read -p "Введите порт [8443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-8443}
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
        success "Будет использован домен: $CUSTOM_DOMAIN"
    else
        SERVER_ADDR=""
        success "Будет использован IP-адрес сервера"
    fi

    read -p "Домен маскировки (Fake TLS) [cloudflare.com]: " DOMAIN
    DOMAIN=${DOMAIN:-cloudflare.com}
    success "Порт: $PROXY_PORT, маскировка: $DOMAIN"
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
    if [[ -n "$SERVER_ADDR" ]]; then
        IP="$SERVER_ADDR"
        success "Используем домен: $IP"
        # Проверим DNS
        local real_ip=$(curl -s -4 ifconfig.me)
        if [[ -n "$real_ip" ]]; then
            check_dns "$IP" "$real_ip"
        else
            warn "Не удалось определить внешний IP для проверки DNS"
        fi
    else
        step "Определяем внешний IP..."
        IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
        if [[ -z "$IP" ]]; then
            warn "Не удалось определить IP автоматически"
            read -p "Введите IP сервера вручную: " IP
            [[ -z "$IP" ]] && error "IP не введён"
        else
            success "IP: $IP"
        fi
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
    success "Глобальная команда 'yurich' создана"
}

# ========================== МЕНЮ И СТАТИСТИКА ==========================

show_stats() {
    clear
    banner
    echo -e "${GREEN}📊 СТАТИСТИКА ПРОКСИ (один раз)${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    if ! docker ps | grep -q mtproxy; then
        echo -e "${RED}❌ Контейнер mtproxy не запущен!${NC}"
        echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
        read
        return
    fi
    echo -e "${YELLOW}📈 Использование ресурсов:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -E "mtproxy|CONTAINER" | sed 's/^/   /'
    echo ""
    echo -e "${YELLOW}🌐 Сетевые подключения:${NC}"
    CONNS=$(docker exec mtproxy ss -tun 2>/dev/null | tail -n +2 | wc -l || echo "0")
    echo -e "   ➤ Активных TCP-соединений: ${GREEN}${CONNS}${NC}"
    echo ""
    echo -e "${YELLOW}📡 Веб-интерфейс:${NC}"
    echo -e "   ➤ http://${IP}:8080 (статистика)"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

show_realtime_stats() {
    clear
    banner
    echo -e "${GREEN}📊 СТАТИСТИКА В РЕАЛЬНОМ ВРЕМЕНИ (обновление каждые 2 сек)${NC}"
    echo -e "${CYAN}Нажмите 'q' для выхода${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    while true; do
        if ! docker ps | grep -q mtproxy; then
            echo -e "${RED}❌ Контейнер mtproxy остановлен!${NC}"
            break
        fi
        clear
        banner
        echo -e "${GREEN}📊 СТАТИСТИКА В РЕАЛЬНОМ ВРЕМЕНИ (обновление каждые 2 сек)${NC}"
        echo -e "${CYAN}Нажмите 'q' для выхода${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}📈 Загрузка контейнера:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -E "mtproxy|CONTAINER" | sed 's/^/   /'
        echo ""
        echo -e "${YELLOW}🌐 Активные соединения:${NC}"
        CONNS=$(docker exec mtproxy ss -tun 2>/dev/null | tail -n +2 | wc -l || echo "0")
        echo -e "   ➤ TCP-соединений: ${GREEN}${CONNS}${NC}"
        echo ""
        echo -e "${YELLOW}⏱️  Время работы контейнера:${NC}"
        UPTIME=$(docker inspect -f '{{.State.StartedAt}}' mtproxy 2>/dev/null)
        if [[ -n "$UPTIME" ]]; then
            echo -e "   ➤ Запущен: ${WHITE}${UPTIME}${NC}"
        fi
        echo -e "\n${BLUE}Обновление... (q - выход)${NC}"
        read -t 2 -n 1 key
        if [[ "$key" == "q" ]]; then
            break
        fi
    done
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
    echo -e "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}${IP}${NC}"
    echo -e "   ${BOLD}Порт:${NC}                 ${YELLOW}${PROXY_PORT}${NC}"
    echo -e "   ${BOLD}Маскировка:${NC}           ${YELLOW}${DOMAIN}${NC}"
    echo -e "   ${BOLD}Fake TLS секрет:${NC}"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "   Telegram: ${GREEN}tg://proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
    echo -e "   Альт:     ${WHITE}https://t.me/proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

change_domain() {
    clear
    banner
    echo -e "${GREEN}🌐 ИЗМЕНЕНИЕ ДОМЕНА/IP${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "Текущий адрес: ${YELLOW}${IP}${NC}"
    read -p "Введите новый домен или IP (Enter для автоопределения IP): " NEW_ADDR
    if [[ -n "$NEW_ADDR" ]]; then
        # Проверка DNS, если это домен (содержит буквы)
        if [[ "$NEW_ADDR" =~ [a-zA-Z] ]]; then
            real_ip=$(curl -s -4 ifconfig.me)
            if [[ -n "$real_ip" ]]; then
                check_dns "$NEW_ADDR" "$real_ip"
            fi
        fi
        IP="$NEW_ADDR"
        success "Адрес изменён на: $IP"
        # Перезаписываем ссылку в информации (не в контейнере)
    else
        NEW_IP=$(curl -s -4 ifconfig.me)
        if [[ -n "$NEW_IP" ]]; then
            IP="$NEW_IP"
            success "IP обновлён автоматически: $IP"
        else
            warn "Не удалось определить IP"
        fi
    fi
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

update_script() {
    clear
    banner
    echo -e "${GREEN}🔄 ОБНОВЛЕНИЕ СКРИПТА${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    local temp_script=$(mktemp)
    if curl -s -o "$temp_script" "$REPO_URL"; then
        cp "$temp_script" /opt/mtproto-proxy/mtp.sh
        chmod +x /opt/mtproto-proxy/mtp.sh
        rm "$temp_script"
        success "Скрипт обновлён. Перезапустите меню."
    else
        error "Не удалось загрузить обновление"
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
        echo -e "Сохраняем существующий секрет."
        FULL_SECRET="$OLD_SECRET"
        PROXY_PORT=$(docker inspect mtproxy | grep -oP '"HostPort":\s*"\K[^"]+' | head -1)
    else
        echo -e "Генерация нового секрета..."
        get_params
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

# Главное меню
show_menu() {
    # Обновляем IP/домен при входе
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "unknown")
    # Если в контейнере используется домен, подхватываем его (можно из переменной окружения)
    local container_addr=$(docker inspect mtproxy 2>/dev/null | grep -oP '"SERVER_ADDR":\s*"\K[^"]+' || echo "")
    if [[ -n "$container_addr" ]]; then
        IP="$container_addr"
    fi
    while true; do
        clear
        banner
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    📋 МЕНЮ УПРАВЛЕНИЯ                      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "   ${CYAN}1${NC} ─ ${YELLOW}📊 Статистика (один раз)${NC}"
        echo -e "   ${CYAN}2${NC} ─ ${YELLOW}🔄 Статистика в реальном времени (обновление)${NC}"
        echo -e "   ${CYAN}3${NC} ─ ${YELLOW}ℹ️  Информация о прокси${NC}"
        echo -e "   ${CYAN}4${NC} ─ ${YELLOW}🌐 Изменить домен/IP${NC}"
        echo -e "   ${CYAN}5${NC} ─ ${YELLOW}🔄 Обновить скрипт${NC}"
        echo -e "   ${CYAN}6${NC} ─ ${YELLOW}🔁 Переустановить прокси${NC}"
        echo -e "   ${CYAN}7${NC} ─ ${YELLOW}📜 Логи (последние 50 строк)${NC}"
        echo -e "   ${CYAN}8${NC} ─ ${YELLOW}♻️  Перезапустить прокси${NC}"
        echo -e "   ${CYAN}0${NC} ─ ${RED}🚪 Выход${NC}"
        echo ""
        echo -ne "${BOLD}Выберите пункт (0-8): ${NC}"
        read choice
        case $choice in
            1) show_stats ;;
            2) show_realtime_stats ;;
            3) show_info ;;
            4) change_domain ;;
            5) update_script ;;
            6) reinstall_proxy ;;
            7) view_logs ;;
            8) restart_proxy ;;
            0) clear; echo -e "${GREEN}До свидания! Для входа: sudo yurich${NC}"; exit 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}"; sleep 1 ;;
        esac
    done
}

# Установка прокси
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
    # Сохраняем текущий скрипт в /opt/mtproto-proxy/mtp.sh
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
    printf "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}%s${NC}\n" "$IP"
    printf "   ${BOLD}Порт:${NC}                 ${YELLOW}%s${NC}\n" "$PROXY_PORT"
    printf "   ${BOLD}Маскировка:${NC}           ${YELLOW}%s${NC}\n" "$DOMAIN"
    printf "   ${BOLD}Fake TLS секрет:${NC}\n"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────${NC}"
    echo -e "   ${BOLD}Telegram-ссылка:${NC} ${GREEN}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}📊 СТАТИСТИКА И ТЕЛЕМЕТРИЯ${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "   Веб-интерфейс: ${WHITE}http://${IP}:8080${NC}"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${IP}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   → вставь секрет: ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${GREEN}💡 Управление прокси: sudo yurich${NC}"
    echo ""
    show_github_link
}

show_github_link() {
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BLINK}   ⭐ Если скрипт был полезен, поставь звезду на GitHub!   ${NC}"
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/${REPO_OWNER}/${REPO_NAME}${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Точка входа
main() {
    if [[ "${1:-}" == "--menu" ]]; then
        # Проверяем, установлен ли прокси
        if ! docker ps -a &>/dev/null || ! docker inspect mtproxy &>/dev/null; then
            echo -e "${RED}❌ Прокси не установлен или Docker не запущен.${NC}"
            echo -e "Сначала установите: ${YELLOW}./mtp.sh${NC}"
            exit 1
        fi
        # Автообновление скрипта (если есть новая версия)
        auto_update
        show_menu
    else
        install_proxy
    fi
}

main "$@"
