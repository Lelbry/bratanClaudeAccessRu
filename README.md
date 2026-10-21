# LocalProxyForClaude

SSH-туннель до твоего VPS с tinyproxy. AI-сервисы (Claude, ChatGPT,
Gemini, Grok, Perplexity и др.) идут через сервер, остальной
интернет — напрямую. Без TUN-адаптеров и глобальных VPN.

**Содержание:**
- [Что внутри](#что-внутри)
- [Быстрая установка](#быстрая-установка)
- [Повседневные команды](#повседневные-команды)
- [Как это работает](#как-это-работает)
- [Структура проекта](#структура-проекта)
- [Подключить Telegram через прокси](#подключить-telegram-через-прокси)
- [Chrome с SwitchyOmega](#chrome-с-switchyomega)
- [Частые проблемы](#частые-проблемы)
- [Автозапуск](#автозапуск)
- [Удаление](#удаление)

---

## Что внутри

- Windows: PowerShell-скрипты поднимают SSH-туннель `127.0.0.1:8888 → VPS`
- Linux VPS: `tinyproxy` слушает `127.0.0.1:8888`, трафик идёт через SSH
- Для Claude Desktop (Microsoft Store) — локальный PAC-сервер на `127.0.0.1:8899`
- Для Claude Code — переменная `HTTPS_PROXY` в батнике `claude-vpn.cmd`
- Для Chrome — конфиг расширения SwitchyOmega

**Требования:** Windows 10/11 с OpenSSH, VPS с Ubuntu, [Node.js](https://nodejs.org) для Claude Code.

---

## Быстрая установка

```powershell
# 1. Склонировать
git clone https://github.com/Lelbry/bratanClaudeAccessRu.git
cd bratanClaudeAccessRu

# 2. Настроить сервер (если ещё нет VPS с tinyproxy)
#    Минимум: загрузить server/install-tinyproxy.sh на свежую Ubuntu и запустить sudo bash

# 3. Запустить мастер (создаст private\server.ps1, SSH-ключ, настроит PAC)
.\setup.ps1

# 4. Проверить
.\start-tunnel.ps1
.\status.ps1
```

Ожидаемый вывод `status.ps1`:
```
[tunnel]  UP    port 127.0.0.1:8888
[proxy]   OK    api.anthropic.com отвечает HTTP 404
[ip]      via proxy: <IP сервера>
[ip]      direct:    <твой IP>
[pac]     UP    http://127.0.0.1:8899/proxy.pac
```

**Личные данные** (IP сервера, SSH-порт, Chrome-профиль) — в
`private/server.ps1` (вся папка `private/` в `.gitignore`). Шаблон:
`private/server.ps1.example`.

---

## Повседневные команды

### Короткий способ: `install-shell-shortcuts.ps1` (один раз)

```powershell
.\install-shell-shortcuts.ps1
```
Это добавит функции-алиасы в твой PowerShell профиль. После открытия
нового PS окна команды работают **из любой папки, без `&` и путей**:

| Команда | Что делает |
|---|---|
| `tunnel-up` | поднять SSH-туннель |
| `tunnel-down` | убить туннель |
| `tunnel-status` | диагностика |
| `tunnel-restart` | жёсткий перезапуск |
| `pac-on` / `pac-off` | PAC для Claude Desktop |
| `whitelist-ip 1.2.3.4` | внести IP в whitelist fail2ban на сервере |
| `claude-vpn` | Claude Code через прокси |
| `cd-vpn` | перейти в папку проекта |

Удалить алиасы: `.\install-shell-shortcuts.ps1 -Uninstall`.

### Прямой запуск скриптов

Если не хочешь ставить алиасы — запускай скрипты напрямую:

| Задача | Команда |
|---|---|
| Запустить Claude Code через прокси | `.\claude-vpn.cmd` |
| Проверить что всё работает | `.\status.ps1` |
| Поднять туннель | `.\start-tunnel.ps1` |
| Убить туннель | `.\stop-tunnel.ps1` |
| Жёсткий перезапуск | `.\restart-proxy.ps1` |
| Включить PAC для Claude Desktop | `.\enable-system-pac.ps1` |
| Выключить PAC | `.\disable-system-pac.ps1` |
| Добавить IP в whitelist fail2ban | `.\whitelist-ip.ps1 1.2.3.4` |

Эти команды предполагают что ты **внутри папки проекта** (`cd <ROOT>`).
Из любой другой папки — через call operator и полный путь в кавычках:
```powershell
& "E:\Top Programs\VPN\LocalProxyForClaude\start-tunnel.ps1"
```
Без `&` PowerShell воспримет строку как литерал и просто её напечатает.

---

## Как это работает

```
Claude Desktop ──► системный PAC   (127.0.0.1:8899) ─┐
Claude Code    ──► env HTTPS_PROXY (127.0.0.1:8888) ─┤
Chrome         ──► SwitchyOmega                     ─┤
                                                     │
                                                     ▼
                                        127.0.0.1:8888 (SSH-туннель)
                                                     │
                                                     ▼
                                        tinyproxy на VPS → claude.ai, api.anthropic.com, …
```

Три клиента читают прокси по-разному, поэтому — три механизма:

| Клиент | Как узнаёт о прокси |
|---|---|
| Claude Desktop (Store) | Системный PAC. Electron читает его, но игнорирует `HTTPS_PROXY` |
| Claude Code (Node CLI) | `HTTPS_PROXY=http://127.0.0.1:8888` (ставит `claude-vpn.cmd`) |
| Chrome | Расширение SwitchyOmega — свои правила |

---

## Структура проекта

```
<ROOT>/
├── config.ps1                       # общий конфиг (порты, пути, хелперы)
├── setup.ps1                        # интерактивный мастер первой установки
├── claude-vpn.cmd / claude-tunnel.ps1   # запуск Claude Code через прокси
├── start-tunnel.ps1 / stop-tunnel.ps1   # поднять / убить SSH-туннель
├── restart-proxy.ps1                # жёсткий перезапуск туннеля + PAC
├── status.ps1                       # диагностика
├── enable-system-pac.ps1 / disable-system-pac.ps1   # вкл/выкл PAC
├── pac-server.ps1                   # HTTP-сервер, раздающий PAC
├── claude-proxy.pac                 # сам PAC-файл (список доменов)
├── whitelist-ip.ps1                 # добавить IP в whitelist fail2ban на сервере
├── uninstall-all.ps1                # полный откат
│
├── private/                         # ⚠️ ЦЕЛИКОМ в .gitignore
│   ├── server.ps1                   # твои: IP, SSH-порт, Chrome-профиль
│   └── server.ps1.example           # шаблон (в репе)
│
├── keys/                            # SSH-ключи (в .gitignore)
│
├── server/                          # для VPS
│   ├── install-tinyproxy.sh
│   ├── tinyproxy.conf
│   └── uninstall-tinyproxy.sh
│
├── google chrome extention/         # SwitchyOmega
│   ├── browser-extension-config.json
│   ├── install-browser-extension.{ps1,cmd}
│   ├── configure-browser-extension.{ps1,cmd}
│   └── SWITCHYOMEGA-GUIDE.md
│
└── VPS-SERVER-FULL-SETUP.md         # как развернуть VPS с нуля
```

**В разработке (не трогай):** `install-autostart.ps1`,
`uninstall-autostart.ps1`, `tunnel-daemon.ps1`, `run-hidden.vbs` —
автозапуск через Windows Scheduled Tasks работает нестабильно,
см. [Автозапуск](#автозапуск).

---

## Подключить Telegram через прокси

**Работает:** сообщения, файлы, медиа, боты, каналы, секретные чаты.
**НЕ работает:** голосовые/видеозвонки (UDP, а HTTP CONNECT = TCP).

```
Telegram → ☰ → Settings → Advanced → Connection type → Use custom proxy → Add proxy
  Тип:       HTTP
  Hostname:  127.0.0.1
  Port:      8888
  User/Pwd:  пусто
Save → поставить галочку.
```
Внизу зелёное **Connected** = ок.

---

## Chrome с SwitchyOmega

```powershell
cd "google chrome extention"
.\install-browser-extension.cmd       # откроет Chrome Web Store
.\configure-browser-extension.cmd     # откроет Import, конфиг в буфере
```
В тулбаре иконка SwitchyOmega → **auto switch** = AI-сайты через прокси,
остальное напрямую.

**Добавить сайт:** SwitchyOmega → Options → auto switch → `+ Add condition`
→ Host wildcard → `example.com` → Profile: `LocalProxy` → Apply.
Подробнее — [SWITCHYOMEGA-GUIDE.md](./google%20chrome%20extention/SWITCHYOMEGA-GUIDE.md).

**Сейчас в auto switch:** Anthropic, OpenAI, Google AI (Gemini, AI Studio),
Perplexity, xAI/Grok, Meta AI, Mistral, Character.AI, Poe, Cohere, You.com, Cursor.

---

## Частые проблемы

**`status.ps1` → `[tunnel] DOWN`**
```powershell
.\start-tunnel.ps1
```

**`[tunnel] UP` но `[proxy] FAIL`** — tinyproxy на сервере упал:
```powershell
ssh -i keys\id_ed25519_claude root@<IP> "systemctl restart tinyproxy"
```

**Claude Desktop пишет «region blocked»** — PAC не подхватился:
```powershell
.\enable-system-pac.ps1
# Перезапустить Claude Desktop (он кеширует PAC)
```

**Chrome идёт мимо прокси** — SwitchyOmega в режиме `[Direct]`.
Переключи на **auto switch** в тулбаре.

**Порт 8888 занят** — поменяй `$LPFC_LocalPort` в `config.ps1`
И ту же цифру в `claude-proxy.pac` (строка `PROXY 127.0.0.1:XXXX`).

**fail2ban забанил меня** — зайди через KVM-консоль провайдера:
```bash
fail2ban-client set sshd unbanip <ТВОЙ_IP>
```
Чтобы впредь не банил — внести в whitelist:
```powershell
.\whitelist-ip.ps1 <ТВОЙ_IP>
```

**Голый `claude` без лаунчера виснет** — Windows System Proxy указан
на мёртвый порт (обычно от Invisible Man XRay):
```powershell
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
```

**После вкл/выкл Warp всё залипло:**
```powershell
.\restart-proxy.ps1
```
Чтобы впредь не рвалось — добавь IP сервера в Warp split-tunnel:
```powershell
warp-cli tunnel ip add <IP сервера>
```

**UDP (звонки Telegram, Discord)** — через HTTP-прокси не пройдёт.
Нужен полноценный VPN (WireGuard или XRay VLESS).

---

## Автозапуск

⚠️ **В разработке.** Scheduled Tasks + PowerShell работают
нестабильно — процессы падают с `0xC000013A`, после ребута часто
не стартуют вообще. Файлы `install-autostart.ps1`,
`tunnel-daemon.ps1`, `run-hidden.vbs` помечены как в разработке.

**Пока** — запускать туннель руками после перезагрузки:
```powershell
.\start-tunnel.ps1
```

**Альтернатива через startup-ярлык** (надёжнее scheduled tasks):
`Win+R` → `shell:startup` → перетащить ярлык на `restart-proxy.ps1`.

---

## Удаление

**Снести всё** (туннель, PAC в Windows, tinyproxy с сервера,
опционально SSH-ключ из `authorized_keys`):
```powershell
.\uninstall-all.ps1
```

**Только локально** (сервер оставить):
```powershell
.\stop-tunnel.ps1
.\disable-system-pac.ps1
```

Папку проекта удалить руками.

---

## Безопасность

- SSH-ключи и личные данные (IP, UUID VLESS, пароли панели) — только в `private/` и `keys/`, обе папки в `.gitignore`
- На сервере отключён вход по паролю (`PasswordAuthentication no`), root — только по ключу
- `fail2ban` банит IP после 5 неудачных попыток за 10 минут на 1 час
- **Бэкап SSH-ключа обязателен** — потеря = доступ только через KVM-консоль провайдера
