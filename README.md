# 🚀 MTProto Proxy Installer with Fake TLS

**Автоматический скрипт для развертывания MTProto прокси с маскировкой Fake TLS (под HTTPS).**  
Подходит для обхода блокировок в Telegram. Работает на любом VPS с Linux (Ubuntu/Debian/CentOS).

![Banner](https://raw.githubusercontent.com/yurichdelaet/mtproto-proxy/main/banner.png)  
*(опционально - можешь добавить картинку позже)*

## ✨ Возможности

- ✔️ Полностью автоматическая установка Docker и контейнера
- ✔️ Генерация корректного секрета **Fake TLS** (префикс `ee` + ключ + домен)
- ✔️ Поддержка любых доменов маскировки (по умолчанию `cloudflare.com`)
- ✔️ Автоматическое открытие порта в UFW/firewalld
- ✔️ Красивый цветной вывод с пошаговой инструкцией
- ✔️ Вывод готовой ссылки `tg://proxy?` для мгновенного подключения

## 📦 Требования

- VPS с **Ubuntu 20.04 / 22.04 / Debian 11+** (или CentOS 7+)
- **1 ядро CPU, 512 MB RAM** (достаточно даже для самого слабого VPS)
- Открытый порт (по умолчанию `8443`) в настройках облачного провайдера (AWS, DigitalOcean, Hetzner, Vultr и т.д.)

## 🚀 Быстрая установка

Выполните на сервере от **root** (или через `sudo`):

```bash
bash <(curl -s https://raw.githubusercontent.com/yurichdelaet/mtproto-proxy/main/mtp.sh)
