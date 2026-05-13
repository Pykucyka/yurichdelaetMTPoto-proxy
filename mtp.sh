#!/usr/bin/env bash

# =============================================
# MTProto Proxy Installer with Fake TLS
# Author: yurichdelaet
# GitHub: https://github.com/yurichdelaet/mtproto-proxy
# License: MIT
# =============================================

set -e

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Функция для отображения баннера
banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                                                      ║"
    echo "  ║   ██╗   ██╗██╗   ██╗██████╗ ██╗ ██████╗██╗  ██╗    ║"
    echo "  ║   ╚██╗ ██╔╝██║   ██║██╔══██╗██║██╔════╝██║  ██║    ║"
    echo "  ║    ╚████╔╝ ██║   ██║██████╔╝██║██║     ███████║    ║"
    echo "  ║     ╚██╔╝  ██║   ██║██╔══██╗██║██║     ██╔══██║    ║"
    echo "  ║      ██║   ╚██████╔╝██║  ██║██║╚██████╗██║  ██║    ║"
    echo "  ║      ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝    ║"
    echo "  ║                                                      ║"
    echo "  ║           MTProto Proxy Installer v1.0              ║"
    echo "  ║               by yurichdelaet                       ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Функция для вывода шага
step() {
    echo -e "${BLUE}[➜]${NC} $1"
}

# Функция успеха
success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Функция ошибки и выхода
error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

# Функция предупреждения
warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Проверка на root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен выполняться от root (sudo ./mtp.sh)"
    fi
}

# Установка Docker, если отсутствует
install_docker() {
    if ! command -v docker &> /dev/null; then
        step "Docker не найден. Устанавливаем Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
        systemctl start docker > /dev/null 2>&1
        rm -f get-docker.sh
        success "Docker установлен"
    else
        success "Docker уже установлен"
    fi
}

# Запрос параметров у пользователя
get_params() {
    echo ""
    step "Настройка прокси (можно оставить значения по умолчанию, нажав Enter)"

    read -p "Введите порт для прокси [8443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-8443}

    read -p "Введите домен для маскировки (Fake TLS) [cloudflare.com]: " DOMAIN
    DOMAIN=${DOMAIN:-cloudflare.com}

    # Простая проверка порта
    if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
        error "Некорректный номер порта"
    fi

    success "Порт: $PROXY_PORT, домен: $DOMAIN"
}

# Генерация полного секрета для Fake TLS
generate_secret() {
    step "Генерация секрета Fake TLS..."
    SECRET_PREFIX="ee"
    RANDOM_KEY=$(openssl rand -hex 16)
    DOMAIN_HEX=$(echo -n "$DOMAIN" | xxd -ps)
    FULL_SECRET="${SECRET_PREFIX}${RANDOM_KEY}${DOMAIN_HEX}"
    success "Секрет сгенерирован"
}

# Запуск контейнера
run_container() {
    step "Запускаем MTProto контейнер..."

    # Останавливаем и удаляем старый контейнер, если есть
    docker rm -f mtproxy 2>/dev/null || true

    docker run -d \
        --name mtproxy \
        --restart=always \
        -p ${PROXY_PORT}:443 \
        -p 8080:80 \
        -e SECRET="${FULL_SECRET}" \
        ellermister/mtproxy > /dev/null

    success "Контейнер запущен"
}

# Получение публичного IP
get_public_ip() {
    IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [[ -z "$IP" ]]; then
        warn "Не удалось определить внешний IP автоматически"
        read -p "Введите IP вашего сервера вручную: " IP
        if [[ -z "$IP" ]]; then
            error "IP не введён"
        fi
    fi
}

# Открытие порта в firewall (если установлен)
open_firewall() {
    if command -v ufw &> /dev/null; then
        step "Открываем порт $PROXY_PORT в UFW..."
        ufw allow ${PROXY_PORT}/tcp > /dev/null 2>&1
        success "Порт $PROXY_PORT открыт"
    elif command -v firewall-cmd &> /dev/null; then
        step "Открываем порт $PROXY_PORT в firewalld..."
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        success "Порт $PROXY_PORT открыт"
    else
        warn "Firewall не обнаружен (UFW/firewalld). Убедитесь, что порт $PROXY_PORT открыт вручную."
    fi
}

# Ожидание готовности контейнера и получение ссылки
get_proxy_link() {
    step "Ожидаем генерации ссылки прокси..."
    sleep 3
    for i in {1..10}; do
        PROXY_LINK=$(docker logs mtproxy 2>&1 | grep -oE 'tg://proxy\?[^ ]+' | head -1)
        if [[ -n "$PROXY_LINK" ]]; then
            break
        fi
        sleep 1
    done

    if [[ -z "$PROXY_LINK" ]]; then
        warn "Автоматическое получение ссылки не удалось. Проверьте логи: docker logs mtproxy"
        PROXY_LINK="tg://proxy?server=${IP}&port=${PROXY_PORT}&secret=${FULL_SECRET}"
    fi
}

# Итоговый вывод
print_result() {
    clear
    banner
    echo ""
    echo -e "${GREEN}✅ Установка успешно завершена!${NC}"
    echo ""
    echo -e "${BOLD}📦 Информация о прокси:${NC}"
    echo -e "   • IP сервера: ${CYAN}${IP}${NC}"
    echo -e "   • Порт: ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   • Домен маскировки: ${CYAN}${DOMAIN}${NC}"
    echo -e "   • Секрет (для бота): ${YELLOW}${FULL_SECRET}${NC}"
    echo ""
    echo -e "${BOLD}🔗 Готовая ссылка для Telegram:${NC}"
    echo -e "   ${MAGENTA}${PROXY_LINK}${NC}"
    echo ""
    echo -e "${BOLD}🤖 Регистрация в @MTProxybot:${NC}"
    echo -e "   1. Открой ${CYAN}@MTProxybot${NC} в Telegram"
    echo -e "   2. Отправь команду ${YELLOW}/newproxy${NC}"
    echo -e "   3. Введи ${CYAN}${IP}${NC} и порт ${CYAN}${PROXY_PORT}${NC}"
    echo -e "   4. Вставь секрет: ${YELLOW}${FULL_SECRET}${NC}"
    echo -e "   5. Бот выдаст TAG — сохрани его, но он не обязателен для работы."
    echo ""
    echo -e "${BOLD}🛠 Управление прокси:${NC}"
    echo -e "   • Просмотр логов: ${YELLOW}docker logs -f mtproxy${NC}"
    echo -e "   • Перезапуск: ${YELLOW}docker restart mtproxy${NC}"
    echo -e "   • Остановка: ${YELLOW}docker stop mtproxy${NC}"
    echo -e "   • Удаление: ${YELLOW}docker rm -f mtproxy${NC}"
    echo ""
    echo -e "${BOLD}💡 Важно:${NC} Убедись, что порт ${PROXY_PORT} открыт в настройках облачного провайдера (VPS)."
    echo -e "${GREEN}⭐ Если скрипт был полезен, поставь звезду на GitHub!${NC}"
    echo -e "${CYAN}👉 https://github.com/yurichdelaet/mtproto-proxy${NC}"
}

# Главная функция main
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
