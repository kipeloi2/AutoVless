# 🚀 VPN Auto-Setup Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04.02-orange.svg)](https://ubuntu.com/)
[![Protocol](https://img.shields.io/badge/Protocol-VLESS%20%2B%20Reality-blue.svg)](https://github.com/XTLS/Xray-core)
[![Language](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)

Автоматическая установка и настройка VPN-сервера с протоколом **VLESS + Reality** на Ubuntu 24.04.02. Максимальная скрытность и производительность для обхода блокировок.

> **⚡ Быстрый старт:** `sudo ./quick-deploy.sh` - и ваш VPN готов за 5 минут!

## ✨ Особенности

- 🔒 **VLESS + Reality** - современный протокол, имитирующий обычный HTTPS трафик
- 🎭 **Маскировка трафика** - сервер притворяется обычным веб-сайтом (Microsoft, Cloudflare)
- 🚀 **Автоматическая установка** - один скрипт для полной настройки
- 📱 **Поддержка мобильных устройств** - готовые конфигурации и QR-коды
- 🛡️ **Встроенная безопасность** - автоматическая настройка firewall
- 📊 **Мониторинг** - инструменты для отслеживания работы сервера
- 👥 **Многопользовательский режим** - поддержка нескольких клиентов

## 📱 Поддерживаемые приложения

| Платформа | Рекомендуемое приложение | Альтернативы |
|-----------|-------------------------|--------------|
| 🤖 **Android** | [v2rayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang) | Clash for Android, SagerNet |
| 🍎 **iOS** | [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118) ($2.99) | Quantumult X, Stash |
| 🪟 **Windows** | [v2rayN](https://github.com/2dust/v2rayN) | Clash for Windows, Qv2ray |
| 🍎 **macOS** | [ClashX](https://github.com/yichengchen/clashX) | Qv2ray |
| 🐧 **Linux** | [Qv2ray](https://github.com/Qv2ray/Qv2ray) | Clash |

> 💡 **Совет:** Для мобильных устройств рекомендуем v2rayNG (Android) и Shadowrocket (iOS) - они лучше всего поддерживают протокол VLESS + Reality.

## 🚀 Быстрый старт

### 1. Скачивание и установка

```bash
# Клонируйте репозиторий
git clone https://github.com/kipeloi2/AutoVless.git
cd AutoVless

# Быстрое развертывание одной командой
sudo ./quick-deploy.sh
```

### 2. Альтернативный способ

```bash
# Запустите основной скрипт установки напрямую
sudo ./install-vpn.sh
```

### 3. Получение конфигурации для телефона

```bash
# Показать все конфигурации
./generate-client-config.sh show

# Создать пакет с QR-кодом для телефона
./generate-client-config.sh package my-phone

# Сгенерировать только QR-код
./generate-client-config.sh qr mobile
```

### 4. Настройка на телефоне

1. **Установите приложение:**
   - Android: v2rayNG из Google Play
   - iOS: Shadowrocket из App Store

2. **Импортируйте конфигурацию:**
   - Отсканируйте QR-код из файла `qr-code.png`
   - Или скопируйте VLESS URL из вывода скрипта

3. **Подключитесь:**
   - Нажмите на созданное подключение
   - Активируйте VPN

## 🎬 Демонстрация

После установки вы получите:

```
╔══════════════════════════════════════════════════════════════╗
║                    Информация для подключения               ║
╚══════════════════════════════════════════════════════════════╝

Сервер: 192.168.1.100:443
Протокол: VLESS + Reality
Маскировка: www.microsoft.com
UUID: 12345678-1234-1234-1234-123456789abc

VLESS URL для мобильных приложений:
vless://12345678-1234-1234-1234-123456789abc@192.168.1.100:443?...

╔══════════════════════════════════════════════════════════════╗
║                      Полезные команды                       ║
╚══════════════════════════════════════════════════════════════╝

vpn-status    - Проверить статус
vpn-restart   - Перезапустить сервис
vpn-config    - Показать конфигурации
vpn-qr        - Создать QR-код
vpn-monitor   - Дашборд мониторинга
```

> 📖 Полная демонстрация доступна в файле [DEMO.md](DEMO.md)

## 📋 Управление сервером

### Основные команды

```bash
# Проверить статус сервера
./vpn-manager.sh status

# Перезапустить сервис
./vpn-manager.sh restart

# Посмотреть логи
./vpn-manager.sh logs

# Показать информацию для клиентов
./vpn-manager.sh client

# Мониторинг трафика
./vpn-manager.sh monitor
```

### Мониторинг и диагностика

```bash
# Показать дашборд
./monitor.sh dashboard

# Проверить здоровье системы
./monitor.sh health

# Запустить мониторинг в реальном времени
./monitor.sh monitor

# Сгенерировать отчет
./monitor.sh report
```

## 🔧 Структура проекта

```
vpn-auto-setup/
├── install-vpn.sh              # Основной скрипт установки
├── vpn-manager.sh              # Управление сервисом
├── generate-client-config.sh   # Генерация клиентских конфигураций
├── monitor.sh                  # Мониторинг и диагностика
├── README.md                   # Документация
└── examples/                   # Примеры конфигураций
    ├── android-setup.md
    ├── ios-setup.md
    └── troubleshooting.md
```

## ⚙️ Конфигурация

### Основные настройки

Скрипт автоматически настраивает:
- **Порт:** 443 (стандартный HTTPS)
- **Протокол:** VLESS + Reality
- **Маскировка:** Microsoft.com
- **Шифрование:** TLS с Reality

### Изменение настроек

Для изменения конфигурации отредактируйте файл:
```bash
sudo nano /usr/local/etc/xray/config.json
```

После изменений перезагрузите конфигурацию:
```bash
./vpn-manager.sh reload
```

## 🛡️ Безопасность

### Автоматические настройки безопасности

- ✅ Настройка UFW firewall
- ✅ Блокировка торрент-трафика
- ✅ Ограничение доступа только к VPN порту
- ✅ Автоматическая генерация криптографических ключей
- ✅ Маскировка под легитимный HTTPS трафик

### Рекомендации

1. **Регулярно обновляйте сервер:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

2. **Меняйте SSH порт:**
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Измените Port 22 на другой порт
   sudo systemctl restart ssh
   ```

3. **Используйте ключи SSH вместо паролей**

## 🔍 Устранение неполадок

### Проблемы с подключением

1. **Проверьте статус сервиса:**
   ```bash
   ./vpn-manager.sh status
   ```

2. **Проверьте логи:**
   ```bash
   ./vpn-manager.sh logs
   ```

3. **Проверьте firewall:**
   ```bash
   sudo ufw status
   ```

### Частые проблемы

**Не удается подключиться:**
- Проверьте правильность конфигурации
- Убедитесь, что порт 443 открыт
- Попробуйте другой сервер маскировки

**Медленная скорость:**
- Проверьте загрузку сервера: `./monitor.sh dashboard`
- Попробуйте изменить протокол в клиенте

**Блокировка провайдером:**
- Измените порт на нестандартный
- Поменяйте сервер маскировки
- Используйте CDN (Cloudflare)

## 📱 Настройка клиентов

### Android (v2rayNG)

1. Установите v2rayNG
2. Нажмите "+" → "Import config from QR code"
3. Отсканируйте QR-код
4. Нажмите на подключение для активации

### iOS (Shadowrocket)

1. Установите Shadowrocket
2. Нажмите "+" в правом верхнем углу
3. Выберите "Type" → "Subscribe"
4. Вставьте VLESS URL или отсканируйте QR-код

### Windows (v2rayN)

1. Скачайте v2rayN с GitHub
2. Запустите программу
3. Нажмите "Servers" → "Add [VLESS] server"
4. Введите данные из конфигурации

## 🤝 Поддержка

### Получение помощи

1. **Проверьте документацию** в папке `examples/`
2. **Запустите диагностику:** `./monitor.sh health`
3. **Создайте отчет:** `./monitor.sh report`

### Полезные ссылки

- [Официальная документация Xray](https://xtls.github.io/)
- [v2rayNG для Android](https://github.com/2dust/v2rayNG)
- [Shadowrocket для iOS](https://apps.apple.com/app/shadowrocket/id932747118)

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для подробностей.

## ⚠️ Отказ от ответственности

Этот инструмент предназначен для обеспечения приватности и безопасности в интернете. Пользователи несут ответственность за соблюдение местного законодательства при использовании VPN-технологий.

---

**Создано с ❤️ для свободного интернета**
