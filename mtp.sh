#!/usr/bin/env bash

# ============================================================
# MTProto Proxy Installer with Fake TLS
# Author: yurichdelaet
# GitHub: https://github.com/Pykucyka/yurichdelaetMTPoto-proxy
# License: MIT
# Version: 4.5 (optimized, bug-free)
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
    echo -e "${CYAN}║${NC}                         ${GREEN}v4.5${CYAN}                                ║${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Global command: yurich | TUI Menu${CYAN}              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ---------- Утилиты вывода ----------
step() { echo -e "${BLUE}[➜]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# ---------- Проверка root ----------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Запустите скрипт с правами root: sudo ./mtp.sh"
    fi
}

# ---------- Установка Docker (с отловом ошибок) ----------
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

# ---------- Оптимизация ядра для прокси ----------
optimize_kernel() {
    step "Настройка параметров ядра для лучшей производительности..."
    cat > /etc/sysctl.d/99-mtproxy.conf << EOF
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF
    sysctl -p /etc/sysctl.d/99-mtproxy.conf > /dev/null 2>&1 || warn "Не удалось применить настройки sysctl (можно игнорировать)"
    success "Параметры ядра оптимизированы (увеличены буферы, включён TCP Fast Open)"
}

# ---------- Загрузка образа ----------
pull_docker_image() {
    step "Загружаем Docker-образ ellermister/mtproxy (Fake TLS)..."
    docker pull ellermister/mtproxy || error "Не удалось загрузить образ. Проверьте интернет."
    success "Образ загружен"
}

# ---------- Ввод параметров ----------
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

    read -p "Домен маскировки (Fake TLS) [cloudflare.com]: " DOMAIN
    DOMAIN=${DOMAIN:-cloudflare.com}
    success "Порт: $PROXY_PORT, домен маскировки: $DOMAIN"
}

# ---------- Генерация секрета ----------
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
    FULL_SECRET=$(cat /tmp/mtproxy_full_secret 2>/dev/null || echo "")
    rm -f /tmp/mtproxy_full_secret
    if [[ -z "$FULL_SECRET" ]]; then
        error "Не удалось сгенерировать секрет"
    fi
    success "Секрет создан"
}

# ---------- Запуск контейнера ----------
run_container() {
    step "Запускаем контейнер ellermister/mtproxy..."
    docker rm -f mtproxy 2>/dev/null || true
    docker run -d \
        --name mtproxy \
        --restart=always \
        -p ${PROXY_PORT}:443 \
        -p 8080:80 \
        -e SECRET="${FULL_SECRET}" \
        ellermister/mtproxy > /dev/null || error "Не удалось запустить контейнер"
    sleep 3
    success "Контейнер запущен"
}

# ---------- Получение публичного адреса ----------
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

# ---------- Открытие портов в firewall ----------
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

# ---------- Формирование ссылки ----------
get_proxy_link() {
    step "Ожидаем генерации ссылки..."
    sleep 3
    PROXY_LINK=$(docker logs mtproxy 2>&1 | grep -oE 'tg://proxy\?[^ ]+' | head -1)
    if [[ -z "$PROXY_LINK" ]]; then
        PROXY_LINK="tg://proxy?server=${SERVER}&port=${PROXY_PORT}&secret=${FULL_SECRET}"
    fi
}

# ---------- Глобальная команда yurich ----------
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

# ---------- Статистика (разовая) ----------
show_stats() {
    clear
    banner
    echo -e "${GREEN}📊 СТАТИСТИКА ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    
    if ! docker ps | grep -q mtproxy; then
        echo -e "${RED}❌ Контейнер mtproxy не запущен!${NC}"
        echo -e "Запустите: ${YELLOW}docker start mtproxy${NC}"
        echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
        read
        return
    fi
    
    # Uptime
    STARTED=$(docker inspect --format='{{.State.StartedAt}}' mtproxy)
    START_SEC=$(date -d "$STARTED" +%s 2>/dev/null || echo 0)
    NOW_SEC=$(date +%s)
    DIFF=$((NOW_SEC - START_SEC))
    [[ $DIFF -lt 0 ]] && DIFF=0
    DAYS=$((DIFF / 86400))
    HOURS=$(( (DIFF % 86400) / 3600 ))
    MINS=$(( (DIFF % 3600) / 60 ))
    
    echo -e "${YELLOW}⏱️  Uptime контейнера:${NC}"
    echo -e "   ➤ ${DAYS} дн, ${HOURS} ч, ${MINS} мин"
    echo ""
    
    echo -e "${YELLOW}📈 Использование ресурсов (CPU / RAM / NET):${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -E "mtproxy|CONTAINER" | sed 's/^/   /'
    echo ""
    
    echo -e "${YELLOW}🌐 Сетевые подключения:${NC}"
    CONNS=$(docker exec mtproxy ss -tun 2>/dev/null | tail -n +2 | wc -l || echo "0")
    echo -e "   ➤ Активных TCP-соединений: ${GREEN}${CONNS}${NC}"
    echo ""
    
    echo -e "${YELLOW}📡 Веб-интерфейс (для браузера):${NC}"
    echo -e "   ➤ http://${SERVER}:8080"
    
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

# ---------- Информация о прокси ----------
show_info() {
    clear
    banner
    echo -e "${GREEN}ℹ️  ИНФОРМАЦИЯ О ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    
    if ! docker ps | grep -q mtproxy; then
        echo -e "${RED}❌ Контейнер mtproxy не запущен!${NC}"
        echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
        read
        return
    fi
    
    PROXY_PORT=$(docker inspect mtproxy 2>/dev/null | grep -oP '"HostPort":\s*"\K[^"]+' | head -1 || echo "8443")
    FULL_SECRET=$(docker exec mtproxy env 2>/dev/null | grep '^SECRET=' | cut -d= -f2)
    [[ -z "$FULL_SECRET" ]] && FULL_SECRET="(не удалось получить)"
    
    # Извлечение домена маскировки из секрета
    if [[ ${#FULL_SECRET} -gt 6 ]]; then
        DOMAIN_HEX=$(echo "$FULL_SECRET" | sed 's/^ee[0-9a-f]\{32\}//')
        DOMAIN=$(echo -n "$DOMAIN_HEX" | xxd -p -r 2>/dev/null || echo "cloudflare.com")
    else
        DOMAIN="cloudflare.com"
    fi
    
    echo -e "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}${SERVER}${NC}"
    echo -e "   ${BOLD}Порт:${NC}                 ${YELLOW}${PROXY_PORT}${NC}"
    echo -e "   ${BOLD}Домен маскировки:${NC}     ${YELLOW}${DOMAIN}${NC}"
    echo -e "   ${BOLD}Fake TLS секрет (ПОЛНЫЙ):${NC}"
    echo -e "   ${WHITE}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${MAGENTA}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "   Telegram-ссылка: ${GREEN}tg://proxy?server=${SERVER}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
    echo -e "   Альтернативная: ${WHITE}https://t.me/proxy?server=${SERVER}&port=${PROXY_PORT}&secret=${FULL_SECRET}${NC}"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

# ---------- Обновление скрипта ----------
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
        echo -e "Скачиваем свежую версию из репозитория..."
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

# ---------- Переустановка прокси ----------
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
        DOMAIN=$(echo -n "$FULL_SECRET" | sed 's/^ee[0-9a-f]\{32\}//' | xxd -p -r 2>/dev/null || echo "cloudflare.com")
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
        ellermister/mtproxy > /dev/null || error "Не удалось переустановить контейнер"
    sleep 2
    success "Прокси переустановлен"
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

# ---------- Логи ----------
view_logs() {
    clear
    banner
    echo -e "${GREEN}📜 ПОСЛЕДНИЕ ЛОГИ ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    docker logs --tail=50 mtproxy 2>&1 | tail -50
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

# ---------- Перезапуск ----------
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

# ---------- Изменение домена/IP ----------
change_domain() {
    clear
    banner
    echo -e "${GREEN}🌐 ИЗМЕНЕНИЕ ДОМЕНА/IP${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "Текущий адрес: ${YELLOW}${SERVER}${NC}"
    read -p "Введите новый домен или IP (оставьте пустым для автоопределения IP): " NEW_ADDR
    if [[ -n "$NEW_ADDR" ]]; then
        if [[ "$NEW_ADDR" =~ [a-zA-Z] ]]; then
            CURRENT_IP=$(curl -s -4 ifconfig.me || echo "")
            DOMAIN_IP=$(dig +short "$NEW_ADDR" | head -1 || echo "")
            if [[ -n "$DOMAIN_IP" && -n "$CURRENT_IP" && "$DOMAIN_IP" != "$CURRENT_IP" ]]; then
                warn "Домен $NEW_ADDR не указывает на текущий IP ($CURRENT_IP). Подключение может не работать!"
            elif [[ -z "$DOMAIN_IP" ]]; then
                warn "Не удалось определить IP домена $NEW_ADDR. Убедитесь, что DNS запись существует."
            else
                success "Домен $NEW_ADDR -> $DOMAIN_IP (OK)"
            fi
        fi
        SERVER="$NEW_ADDR"
        success "Адрес изменён на: $SERVER"
    else
        NEW_IP=$(curl -s -4 ifconfig.me || echo "")
        if [[ -n "$NEW_IP" ]]; then
            SERVER="$NEW_IP"
            success "IP обновлён автоматически: $SERVER"
        else
            warn "Не удалось определить IP автоматически, оставлен старый: $SERVER"
        fi
    fi
    echo "$SERVER" > /opt/mtproto-proxy/current_addr
    echo -e "\n${BOLD}Нажмите Enter, чтобы вернуться...${NC}"
    read
}

# ---------- Проверка обновлений при входе в меню ----------
auto_update_check() {
    SCRIPT_VERSION="4.5"
    REMOTE_VERSION=$(curl -s --max-time 3 https://raw.githubusercontent.com/Pykucyka/yurichdelaetMTPoto-proxy/main/mtp.sh | grep -E '^# Version: ' | head -1 | awk '{print $3}' || echo "")
    if [[ -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "$SCRIPT_VERSION" ]]; then
        echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
        echo -e "${YELLOW}📢 Доступна новая версия скрипта: ${REMOTE_VERSION} (текущая: ${SCRIPT_VERSION})${NC}"
        echo -e "${YELLOW}   Рекомендуется обновить скрипт через пункт меню 'Обновить скрипт'${NC}"
        echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${BOLD}Нажмите Enter, чтобы продолжить...${NC}"
        read
    fi
}

# ---------- Главное меню ----------
show_menu() {
    SERVER=$(cat /opt/mtproto-proxy/current_addr 2>/dev/null || echo "")
    if [[ -z "$SERVER" ]]; then
        SERVER=$(curl -s -4 ifconfig.me || echo "unknown")
    fi
    auto_update_check
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
        echo -e "   ${CYAN}5${NC} ─ ${YELLOW}🔁 Переустановить прокси (сохраняя секрет)${NC}"
        echo -e "   ${CYAN}6${NC} ─ ${YELLOW}📜 Просмотр последних логов${NC}"
        echo -e "   ${CYAN}7${NC} ─ ${YELLOW}♻️  Перезапустить прокси-контейнер${NC}"
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

# ---------- Установка прокси ----------
install_proxy() {
    banner
    check_root
    install_docker
    optimize_kernel
    pull_docker_image
    get_params
    generate_secret
    run_container
    get_public_ip
    open_firewall
    get_proxy_link
    mkdir -p /opt/mtproto-proxy
    echo "$SERVER" > /opt/mtproto-proxy/current_addr
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

# ---------- Финальный вывод ----------
print_result() {
    clear
    banner
    echo -e "${GREEN}✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА${NC}"
    echo ""
    echo -e "${CYAN}📡 ПАРАМЕТРЫ ПРОКСИ${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    printf "   ${BOLD}Адрес сервера:${NC}         ${YELLOW}%s${NC}\n" "$SERVER"
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
    echo -e "   Статистика в веб-интерфейсе: ${WHITE}http://${SERVER}:8080${NC}"
    echo ""
    echo -e "${BLUE}🤖 РЕГИСТРАЦИЯ В @MTProxybot${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "   Отправь боту /newproxy → введи ${CYAN}${SERVER}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
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
    echo -e "${YELLOW}${BLINK}   👉 https://github.com/Pykucyka/yurichdelaetMTPoto-proxy${NC}"
    echo -e "${YELLOW}${BLINK}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ---------- Точка входа ----------
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
