# 🚀 Быстрый старт

## Установка одной командой

```bash
# Скачайте репозиторий
git clone https://github.com/kipeloi2/leposaq.git
cd leposaq

# Запустите быстрое развертывание
sudo ./quick-deploy.sh
```

## Или напрямую:

### 1. Установка VPN сервера
```bash
sudo ./install-vpn.sh
```

### 2. Получение конфигурации для телефона
```bash
./generate-client-config.sh show
```

### 3. Создание QR-кода
```bash
./generate-client-config.sh qr my-phone
```

## Управление сервером

```bash
# Статус сервера
./vpn-manager.sh status

# Перезапуск
./vpn-manager.sh restart

# Мониторинг
./monitor.sh dashboard
```

## Настройка на телефоне

### Android (v2rayNG)
1. Установите v2rayNG из Google Play
2. Нажмите "+" → "Import config from QR code"
3. Отсканируйте QR-код
4. Подключитесь

### iOS (Shadowrocket)
1. Купите Shadowrocket в App Store ($2.99)
2. Нажмите "+" → "QR Code"
3. Отсканируйте QR-код
4. Подключитесь

## Поддержка

- 📖 Полная документация: `README.md`
- 🤖 Настройка Android: `examples/android-setup.md`
- 🍎 Настройка iOS: `examples/ios-setup.md`
- 🔧 Устранение неполадок: `examples/troubleshooting.md`

---

**Время установки: ~5 минут | Поддерживаемые ОС: Ubuntu 24.04.02**
