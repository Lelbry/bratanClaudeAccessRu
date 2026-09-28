# Полная настройка VPS-сервера с нуля

**Сервер:** `YOUR_SERVER_IP` · **ОС:** Ubuntu 22.04 · **Hostname:** `your-hostname.example.com`

Этот сервер выполняет **две функции**:

| Сервис | Порт | Зачем |
|---|---|---|
| **tinyproxy** | `127.0.0.1:8888` | HTTP-прокси для AI-сервисов (Claude, ChatGPT, Gemini). Доступен только через SSH-туннель, снаружи закрыт |
| **XRay (VLESS)** | `0.0.0.0:8080` | VPN для телефонов и ПК. Доступен снаружи, клиенты подключаются напрямую |

---

## Часть 1. Базовая подготовка сервера

### 1.1. Подключение по SSH

Через PuTTY, терминал или PowerShell:
```bash
ssh root@YOUR_SERVER_IP
```

### 1.2. Добавить SSH-ключ (для автоматических скриптов)

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
```

Вставить публичный ключ клиента (содержимое файла `id_ed25519_claude.pub` — одна строка `ssh-ed25519 AAAA...`):

```bash
cat > ~/.ssh/authorized_keys << 'EOF'
ВСТАВИТЬ_СЮДА_СОДЕРЖИМОЕ_ПУБЛИЧНОГО_КЛЮЧА
EOF
chmod 600 ~/.ssh/authorized_keys
```

> **Важно:** ключ — одна длинная строка без переносов. Если копируешь из мессенджера — убедись, что строка не разбилась.

### Проверка с Windows-клиента

```powershell
ssh -i "D:\...\keys\id_ed25519_claude" root@YOUR_SERVER_IP "echo OK"
```

Должен ответить `OK` без запроса пароля.

---

## Часть 2. Tinyproxy (прокси для AI-сервисов)

### 2.1. Установка

```bash
apt update && apt install -y tinyproxy
```

При вопросе «Which services should be restarted?» ввести `15` (none of the above).

### 2.2. Создать директории

Tinyproxy не создаёт их сам — без них сервис зависает при старте:

```bash
mkdir -p /var/log/tinyproxy && chown tinyproxy:tinyproxy /var/log/tinyproxy
mkdir -p /run/tinyproxy && chown tinyproxy:tinyproxy /run/tinyproxy
```

### 2.3. Записать конфиг

```bash
cp /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf.orig
```

```bash
cat > /etc/tinyproxy/tinyproxy.conf << 'EOF'
User tinyproxy
Group tinyproxy

Port 8888
Listen 127.0.0.1
Timeout 300

MaxClients 200

LogFile "/var/log/tinyproxy/tinyproxy.log"
LogLevel Info

ConnectPort 443
ConnectPort 563
ConnectPort 8443
ConnectPort 80
EOF
```

> `Listen 127.0.0.1` — прокси слушает только локально. Снаружи не доступен, подключение только через SSH-туннель.

### 2.4. Запуск

```bash
pkill -9 tinyproxy
systemctl restart tinyproxy
systemctl enable tinyproxy
```

> `systemctl restart` может зависать на 1–2 минуты из-за бага с PID-файлом в некоторых версиях пакета. Если зависло — Ctrl+C и проверить вручную (шаг 2.5).

### 2.5. Проверка

```bash
ss -tlnp | grep 8888
```

Ожидаемый вывод:
```
LISTEN  0  1024  127.0.0.1:8888  0.0.0.0:*  users:(("tinyproxy",...))
```

Логи (если что-то не работает):
```bash
journalctl -u tinyproxy --no-pager -n 20
```

---

## Часть 3. XRay / VLESS (VPN для устройств)

### 3.1. Установка XRay

```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

Если директория не создалась автоматически:
```bash
mkdir -p /usr/local/etc/xray
```

### 3.2. Записать конфиг с 4 пользователями

```bash
cat > /usr/local/etc/xray/config.json << 'EOF'
{
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "5f2a9c1e-3b4d-4e6f-8a1b-2c3d4e5f6a7b" },
          { "id": "7e8f9a0b-1c2d-3e4f-5a6b-7c8d9e0f1a2b" },
          { "id": "9a0b1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d" },
          { "id": "1b2c3d4e-5f6a-7b8c-9d0e-1f2a3b4c5d6e" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ],
  "dns": {
    "servers": ["1.1.1.1", "8.8.8.8"]
  }
}
EOF
```

### 3.3. Запуск

```bash
systemctl restart xray
systemctl enable xray
systemctl status xray
```

Должно быть `active (running)`.

### 3.4. Проверка

```bash
ss -tlnp | grep 8080
```

Ожидаемый вывод:
```
LISTEN  0  4096  *:8080  *:*  users:(("xray",...))
```

### 3.5. Готовые VLESS-ссылки

| Название | UUID | Назначение |
|---|---|---|
| USA PC | `5f2a9c1e-3b4d-4e6f-8a1b-2c3d4e5f6a7b` | Компьютер |
| USA Phone | `7e8f9a0b-1c2d-3e4f-5a6b-7c8d9e0f1a2b` | Телефон |
| Spartak | `9a0b1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d` | — |
| USA Anna | `1b2c3d4e-5f6a-7b8c-9d0e-1f2a3b4c5d6e` | — |

**Ссылки (копировать целиком):**

```
vless://5f2a9c1e-3b4d-4e6f-8a1b-2c3d4e5f6a7b@YOUR_SERVER_IP:8080?encryption=none&security=none&type=tcp#USA%20PC
```

```
vless://7e8f9a0b-1c2d-3e4f-5a6b-7c8d9e0f1a2b@YOUR_SERVER_IP:8080?encryption=none&security=none&type=tcp#USA%20Phone
```

```
vless://9a0b1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d@YOUR_SERVER_IP:8080?encryption=none&security=none&type=tcp#Spartak
```

```
vless://1b2c3d4e-5f6a-7b8c-9d0e-1f2a3b4c5d6e@YOUR_SERVER_IP:8080?encryption=none&security=none&type=tcp#USA%20Anna
```

### 3.6. Как подключить в NekoBox / Invisible Man / v2rayN

1. Скопировать нужную VLESS-ссылку
2. В приложении: **+** → **Импорт из буфера обмена**
3. Сохранить, выбрать сервер, включить VPN

---

## Часть 4. Настройка Windows-клиента (LocalProxyForClaude)

Эта часть выполняется на **компьютере пользователя**, а не на сервере.

### 4.1. config.ps1

Убедиться, что IP и порты верные:

```powershell
$Global:LPFC_SshHost    = "YOUR_SERVER_IP"
$Global:LPFC_SshUser    = "root"
$Global:LPFC_SshPort    = 22
$Global:LPFC_LocalPort  = 8888
$Global:LPFC_RemotePort = 8888
```

### 4.2. Запуск туннеля и PAC

```powershell
cd <ROOT>
.\start-tunnel.ps1
.\status.ps1                    # должен показать UP
.\enable-system-pac.ps1         # PAC для Claude Desktop
.\install-autostart.ps1         # автозапуск при логоне
```

### 4.3. Проверка

`status.ps1` должен показать:
- `[tunnel] UP`
- `[proxy] OK`
- `[ip] via proxy: YOUR_SERVER_IP`

---

## Часть 5. Chrome — расширение SwitchyOmega

### 5.1. Установить расширение

Открыть в Chrome:
```
https://chromewebstore.google.com/detail/proxy-switchyomega/padekgcemlokbadohgkifijomclgjgif
```

### 5.2. Создать профиль прокси

1. Иконка SwitchyOmega → **Options**
2. Слева → **New profile**
3. Имя: `LocalProxy`, тип: **Proxy Profile** → Create
4. Protocol: **HTTP**, Server: `127.0.0.1`, Port: `8888`
5. **Apply changes**

### 5.3. Настроить auto switch

1. Слева → **auto switch**
2. Для каждого домена: **Add a condition** → Host wildcard → домен → Profile: **LocalProxy**

Домены (добавлять парами — сам домен и `*.домен`):

| Категория | Домены |
|---|---|
| Anthropic | `claude.ai`, `anthropic.com` |
| OpenAI | `chatgpt.com`, `openai.com`, `oaistatic.com`, `oaiusercontent.com` |
| Google AI | `gemini.google.com`, `aistudio.google.com` |
| Другие AI | `perplexity.ai`, `x.ai`, `grok.com`, `meta.ai`, `mistral.ai` |
| Cursor | `cursor.com`, `cursor.sh` |

3. Default внизу → **Direct**
4. **Apply changes**

### 5.4. Включить

Иконка SwitchyOmega → выбрать **auto switch**.

---

## Итоговая проверка

| Что проверить | Как | Ожидаемый результат |
|---|---|---|
| tinyproxy на сервере | `ss -tlnp \| grep 8888` | `LISTEN ... 127.0.0.1:8888 ... tinyproxy` |
| XRay на сервере | `ss -tlnp \| grep 8080` | `LISTEN ... *:8080 ... xray` |
| SSH-туннель с клиента | `.\status.ps1` | `[tunnel] UP`, `[proxy] OK` |
| Claude Desktop | Открыть приложение | Работает |
| Chrome → claude.ai | Открыть в браузере | Работает (SwitchyOmega в auto switch) |
| VLESS на телефоне | NekoBox с ссылкой | VPN работает, IP = `YOUR_SERVER_IP` |

---

## Частые проблемы

| Симптом | Причина | Решение |
|---|---|---|
| SSH просит пароль | Ключ не добавлен или битый | Перезаписать `authorized_keys` через `cat >`, убедиться что одна строка |
| `nano: command not found` | Минимальная Ubuntu без nano | Использовать `cat >` или `apt install -y nano` |
| `systemctl restart tinyproxy` зависает | Нет `/run/tinyproxy/` или старый процесс | `pkill -9 tinyproxy`, создать директории (2.2), рестартнуть |
| `start-tunnel.ps1` FAILED | SSH-ключ не принят | Проверить: `ssh -i ... root@IP "echo OK"` |
| PAC не работает, Claude Desktop не подключается | Порт в `claude-proxy.pac` не совпадает с `config.ps1` | Оба должны быть `8888` |
| VLESS не подключается | Порт 8080 заблокирован провайдером | Сменить порт на 443 (см. ниже) |
| VPN друга ломается после включения PAC | PAC — системная настройка Windows | Это нормально для VPN-клиентов, читающих системный прокси. PAC роутит только AI-домены, остальное DIRECT |

### Смена порта VLESS (если 8080 заблокирован)

На сервере:
```bash
sed -i 's/8080/443/g' /usr/local/etc/xray/config.json
systemctl restart xray
```
В VLESS-ссылках заменить `:8080` на `:443`.

Если и 443 не работает — попробовать порт `53`.

---

## Промпт для нового чата: перенастройка VLESS на новом IP

Скопировать в новый диалог с ИИ (Claude, DeepSeek, ChatGPT), подставив свои данные:

```
На моём Ubuntu-сервере уже установлен XRay.
Нужно обновить конфиг и получить 4 новых VLESS-ключа.

Данные сервера:
  IP:   <НОВЫЙ_IP>
  Порт: 8080

Имена ключей:
  1. USA PC
  2. USA Phone
  3. Spartak
  4. USA Anna

Сгенерируй 4 новых UUID, запиши конфиг в /usr/local/etc/xray/config.json
(протокол VLESS, TCP, без шифрования), перезапусти XRay и выдай
готовые vless:// ссылки для каждого пользователя.
```

## Промпт для нового чата: полная настройка сервера с нуля

```
Разверни на Ubuntu-сервере два сервиса:

1. tinyproxy — HTTP-прокси на 127.0.0.1:8888 (только локально,
   доступ через SSH-туннель). Для проксирования AI-сервисов.

2. XRay (VLESS) — VPN на порту 8080 (TCP, без шифрования).
   4 пользователя: USA PC, USA Phone, Spartak, USA Anna.

Данные сервера:
  IP:       <IP>
  SSH-юзер: root
  SSH-порт: 22

Действия:
  - Установить tinyproxy, записать конфиг, создать директории,
    запустить и включить автозагрузку
  - Установить XRay, сгенерировать 4 UUID, записать конфиг,
    запустить и включить автозагрузку
  - Выдать готовые vless:// ссылки
  - Добавить SSH-ключ (публичный ключ пришлю отдельно)

Все команды — копипастой, без nano (его нет на сервере).
```

---

## История

- **2026-09-04:** первоначальная настройка (старый IP YOUR_SERVER_IP) — tinyproxy, SSH-туннель, SwitchyOmega
- **2026-09-05:** PAC для Claude Desktop, автозапуск, оптимизация MaxClients/Timeout
- **2026-09-26:** смена IP на YOUR_SERVER_IP, повторная настройка tinyproxy и XRay/VLESS с нуля
