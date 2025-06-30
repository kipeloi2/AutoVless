# 🔧 Устранение неполадок VPN

Полное руководство по диагностике и решению проблем с VPN сервером.

## 🚨 Быстрая диагностика

### Автоматическая проверка
```bash
# Запустите комплексную диагностику
./monitor.sh health

# Проверьте статус всех компонентов
./vpn-manager.sh status

# Посмотрите последние логи
./vpn-manager.sh logs 50
```

## 🔍 Частые проблемы и решения

### 1. Сервис не запускается

#### Симптомы:
- `systemctl status xray` показывает "failed"
- Клиенты не могут подключиться
- Порт не слушается

#### Диагностика:
```bash
# Проверьте статус сервиса
systemctl status xray -l

# Проверьте конфигурацию
/usr/local/bin/xray -test -config /usr/local/etc/xray/config.json

# Проверьте логи
journalctl -u xray -n 50
```

#### Решения:
1. **Исправьте конфигурацию:**
   ```bash
   sudo nano /usr/local/etc/xray/config.json
   ./vpn-manager.sh reload
   ```

2. **Проверьте права доступа:**
   ```bash
   sudo chown -R nobody:nogroup /usr/local/etc/xray/
   sudo chmod 644 /usr/local/etc/xray/config.json
   ```

3. **Переустановите сервис:**
   ```bash
   sudo systemctl stop xray
   sudo systemctl disable xray
   sudo ./install-vpn.sh
   ```

### 2. Порт заблокирован или занят

#### Симптомы:
- "Address already in use"
- Клиенты получают "Connection refused"

#### Диагностика:
```bash
# Проверьте, что слушает порт 443
sudo netstat -tlnp | grep :443

# Проверьте firewall
sudo ufw status

# Проверьте iptables
sudo iptables -L -n
```

#### Решения:
1. **Освободите порт:**
   ```bash
   # Найдите процесс, использующий порт
   sudo lsof -i :443
   
   # Остановите конфликтующий сервис (например, Apache/Nginx)
   sudo systemctl stop apache2
   sudo systemctl stop nginx
   ```

2. **Измените порт VPN:**
   ```bash
   sudo nano /usr/local/etc/xray/config.json
   # Измените "port": 443 на другой порт, например 8443
   
   # Обновите firewall
   sudo ufw allow 8443
   sudo ufw delete allow 443
   
   ./vpn-manager.sh restart
   ```

### 3. Проблемы с Reality маскировкой

#### Симптомы:
- Подключение устанавливается, но сразу обрывается
- Высокий ping или таймауты
- Блокировка провайдером

#### Диагностика:
```bash
# Проверьте доступность сайта маскировки
curl -I https://www.microsoft.com

# Проверьте TLS handshake
openssl s_client -connect www.microsoft.com:443 -servername www.microsoft.com
```

#### Решения:
1. **Смените сайт маскировки:**
   ```bash
   sudo nano /usr/local/etc/xray/config.json
   ```
   
   Замените в конфигурации:
   ```json
   "dest": "www.cloudflare.com:443",
   "serverNames": ["www.cloudflare.com"]
   ```
   
   Альтернативные сайты:
   - `www.cloudflare.com:443`
   - `www.bing.com:443`
   - `www.yahoo.com:443`
   - `discord.com:443`

2. **Обновите ключи Reality:**
   ```bash
   # Сгенерируйте новые ключи
   ./install-vpn.sh
   # Или вручную:
   openssl genpkey -algorithm X25519 | openssl pkey -text -noout
   ```

### 4. Медленная скорость подключения

#### Симптомы:
- Низкая скорость загрузки/выгрузки
- Высокий ping
- Таймауты при загрузке страниц

#### Диагностика:
```bash
# Проверьте загрузку сервера
./monitor.sh dashboard

# Проверьте сетевую статистику
iftop -i $(ip route | grep default | awk '{print $5}' | head -1)

# Проверьте дисковое пространство
df -h
```

#### Решения:
1. **Оптимизируйте конфигурацию:**
   ```json
   {
     "mux": {
       "enabled": true,
       "concurrency": 8
     }
   }
   ```

2. **Измените настройки TCP:**
   ```bash
   # Добавьте в /etc/sysctl.conf
   echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
   echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
   sysctl -p
   ```

3. **Проверьте MTU:**
   ```bash
   # Найдите оптимальный MTU
   ping -M do -s 1472 google.com
   
   # Установите MTU
   sudo ip link set dev eth0 mtu 1400
   ```

### 5. Клиенты не могут подключиться

#### Симптомы:
- "Connection timeout"
- "Handshake failed"
- "Invalid configuration"

#### Диагностика на сервере:
```bash
# Проверьте подключения
./monitor.sh monitor

# Проверьте логи доступа
tail -f /var/log/xray/access.log

# Проверьте внешний IP
curl ifconfig.me
```

#### Диагностика на клиенте:
1. **Проверьте конфигурацию:**
   - UUID правильный
   - IP адрес актуальный
   - Порт соответствует серверу
   - Ключи Reality корректные

2. **Тест подключения:**
   ```bash
   # На клиенте (Linux/Mac)
   telnet YOUR_SERVER_IP 443
   
   # Или
   nc -zv YOUR_SERVER_IP 443
   ```

#### Решения:
1. **Пересоздайте конфигурацию:**
   ```bash
   ./generate-client-config.sh package new-client
   ```

2. **Проверьте время на сервере:**
   ```bash
   # Синхронизируйте время
   sudo timedatectl set-ntp true
   sudo systemctl restart systemd-timesyncd
   ```

### 6. Блокировка провайдером

#### Симптомы:
- Работает с одного провайдера, не работает с другого
- Периодические отключения
- Медленная скорость в определенное время

#### Решения:
1. **Смените порт на нестандартный:**
   ```bash
   # Используйте порты: 8080, 8443, 2053, 2083, 2087, 2096
   sudo nano /usr/local/etc/xray/config.json
   # Измените порт и перезапустите
   ```

2. **Используйте CDN (Cloudflare):**
   - Настройте домен через Cloudflare
   - Включите проксирование
   - Используйте Cloudflare IP

3. **Измените fingerprint:**
   ```json
   "realitySettings": {
     "fingerprint": "safari"
   }
   ```
   
   Доступные варианты: `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, `qq`

## 🔧 Продвинутая диагностика

### Анализ трафика
```bash
# Мониторинг сетевого трафика
sudo tcpdump -i any port 443

# Анализ подключений
ss -tuln | grep :443

# Проверка маршрутизации
traceroute google.com
```

### Проверка производительности
```bash
# Тест скорости сервера
wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test100.zip

# Проверка I/O диска
sudo iotop

# Мониторинг памяти
free -h && sync && echo 3 > /proc/sys/vm/drop_caches && free -h
```

### Логирование и мониторинг
```bash
# Включите подробное логирование
sudo nano /usr/local/etc/xray/config.json
# Измените "loglevel": "warning" на "debug"

# Мониторинг в реальном времени
tail -f /var/log/xray/access.log /var/log/xray/error.log

# Анализ логов
grep "ERROR\|WARN" /var/log/xray/error.log | tail -20
```

## 🛡️ Безопасность и обслуживание

### Регулярное обслуживание
```bash
# Еженедельно
sudo apt update && sudo apt upgrade
./vpn-manager.sh backup

# Ежемесячно
./monitor.sh report
# Анализируйте отчет на предмет проблем

# При необходимости
# Обновите Xray до последней версии
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
```

### Мониторинг безопасности
```bash
# Проверьте подозрительные подключения
netstat -an | grep :443 | grep ESTABLISHED

# Проверьте логи на атаки
grep -i "attack\|hack\|exploit" /var/log/auth.log

# Мониторинг использования ресурсов
./monitor.sh dashboard
```

## 📞 Получение помощи

### Сбор информации для поддержки
```bash
# Создайте полный отчет
./monitor.sh report

# Соберите системную информацию
uname -a > system-info.txt
lsb_release -a >> system-info.txt
./vpn-manager.sh status >> system-info.txt
```

### Полезные команды для диагностики
```bash
# Проверка DNS
nslookup google.com
dig google.com

# Проверка маршрутизации
ip route show
ip addr show

# Проверка firewall
sudo ufw status verbose
sudo iptables -L -n -v
```

---

**💡 Совет:** Всегда делайте резервные копии конфигурации перед внесением изменений и тестируйте изменения на тестовом сервере, если это возможно.
