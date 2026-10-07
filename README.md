# LocalProxyForClaude

Прокси-туннель через свой Linux-сервер для обхода региональных блокировок.
Работает **только для нужных приложений** — остальной интернет идёт напрямую,
никаких TUN-адаптеров, WFP-хуков и конфликтов с loopback.

---

## Установка с нуля (для нового пользователя)

### Что понадобится

- **Windows 10/11** с PowerShell
- **VPS-сервер** (Ubuntu) с установленным tinyproxy — [инструкция по настройке сервера](./VPS-SERVER-FULL-SETUP.md)
- **SSH-ключ** для подключения к серверу
- **Google Chrome** (опционально, для браузерного доступа к AI-сервисам)

### Шаг 1. Скачать проект

```powershell
git clone https://github.com/Lelbry/bratanClaudeAccessRu.git
cd bratanClaudeAccessRu
```

### Шаг 2. Настроить сервер (если ещё не настроен)

Если у тебя уже есть VPS с tinyproxy — пропусти этот шаг.

Если нет — купи VPS (Ubuntu 22.04) и настрой по инструкции:
[`VPS-SERVER-FULL-SETUP.md`](./VPS-SERVER-FULL-SETUP.md) — там всё по шагам, копипастой.

### Шаг 3. SSH-ключ

Создай папку `keys/` и сгенерируй ключ:

```powershell
mkdir keys
ssh-keygen -t ed25519 -f keys\id_ed25519_claude -N "" -C "claude-tunnel"
```

Добавь публичный ключ на сервер:

```powershell
type keys\id_ed25519_claude.pub | ssh root@ТВОЙ_IP_СЕРВЕРА "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Проверь что работает:
```powershell
ssh -i keys\id_ed25519_claude root@ТВОЙ_IP_СЕРВЕРА "echo OK"
```

### Шаг 4. Вписать данные сервера

Открой `config.ps1` и замени `YOUR_SERVER_IP` на IP своего сервера:

```powershell
$Global:LPFC_SshHost    = "1.2.3.4"     # <-- твой IP
$Global:LPFC_SshUser    = "root"
$Global:LPFC_SshPort    = 22
```

Остальные настройки (порты 8888, 8899) менять не нужно — они стандартные.

### Шаг 5. Проверить что туннель работает

```powershell
.\start-tunnel.ps1
.\status.ps1
```

Ожидаемый вывод:
```
[tunnel]  UP    port 127.0.0.1:8888
[proxy]   OK    api.anthropic.com отвечает HTTP ...
[ip]      via proxy: 1.2.3.4
```

### Шаг 6. Включить PAC + автозагрузку

```powershell
.\enable-system-pac.ps1       # PAC для Claude Desktop (Store-приложение)
.\install-autostart.ps1       # автозапуск туннеля и PAC при логоне Windows
```

> ⚠️ **Автозагрузка через Windows Scheduled Tasks работает не у всех.**
> Используется `wscript.exe` + VBS-обёртка для скрытого запуска PowerShell
> (обычный `-WindowStyle Hidden` в Task Scheduler ненадёжен). Если после
> ребута туннель не поднялся — запусти вручную:
> ```powershell
> .\restart-proxy.ps1
> ```
> Или создай ярлык на `restart-proxy.ps1` в папке автозагрузки Windows:
> `Win+R` → `shell:startup` → положить туда ярлык.

### Шаг 7. Настроить Chrome (опционально)

Если хочешь через браузер заходить на claude.ai, chatgpt.com, gemini и другие:

```powershell
cd "google chrome extention"
.\install-browser-extension.cmd       # установит SwitchyOmega из Web Store
.\configure-browser-extension.cmd     # импортирует правила auto switch
```

В тулбаре Chrome выбрать режим **auto switch** — AI-сайты пойдут через прокси, остальное напрямую.

### Шаг 8. Готово!

Проверь:
- **Claude Desktop** — должен открыться без «region blocked»
- **Claude Code** — запускай через `.\claude-vpn.cmd`
- **Chrome** — claude.ai и chatgpt.com работают в режиме auto switch

Диагностика в любой момент:
```powershell
.\status.ps1
```

---

## Что через что работает

| Приложение | Как получает прокси | Почему именно так |
|---|---|---|
| **Claude Desktop** (Store) | Системный PAC (`http://127.0.0.1:8899/proxy.pac`) — Windows раздаёт его всем приложениям | Electron/Chromium читает системный PAC, но НЕ читает `HTTPS_PROXY`. Обычный `file://` PAC тоже не работает — Chromium блокирует file-доступ из песочницы, поэтому PAC раздаётся HTTP-сервером |
| **Claude Code** (CLI) | Переменная `HTTPS_PROXY` — выставляется батником `claude-vpn.cmd` только для процесса claude | Node.js НЕ читает системный PAC, зато читает `HTTPS_PROXY` из окружения |
| **Chrome** (профиль ваш профиль) | Расширение SwitchyOmega — список сайтов в правилах `auto switch` | Расширение перехватывает запросы ДО системного прокси, позволяет гибко рулить десятками доменов из GUI |

```
                         Откуда берут настройки
                         ──────────────────────
Claude Desktop ──► системный PAC (127.0.0.1:8899) ──► claude.ai → PROXY
Claude Code    ──► env HTTPS_PROXY=127.0.0.1:8888 ──► всё через прокси
Chrome         ──► расширение SwitchyOmega ──────────► по правилам

                         Куда всё сходится
                         ─────────────────
                    ┌─────────────────────────┐
Все три ──────────► │ 127.0.0.1:8888 (туннель)│
                    └────────────┬────────────┘
                                 │ SSH -L
                    ┌────────────▼────────────┐
                    │ tinyproxy на сервере     │
                    │ 127.0.0.1:8888           │
                    └────────────┬────────────┘
                                 │ CONNECT
                                 ▼
                         api.anthropic.com
                         claude.ai
                         chatgpt.com
                         ...
```

---

## Скрипты — что для чего

### Повседневные

| Скрипт | Когда использовать |
|---|---|
| `claude-vpn.cmd` | Запуск Claude Code через прокси. Двойной клик или из терминала. Сам поднимет туннель если нужно, проверит прокси, запустит claude |
| `status.ps1` | Диагностика: туннель жив? прокси отвечает? какой IP видит сервер? |
| `start-tunnel.ps1` | Поднять туннель вручную (без запуска claude). Если уже поднят — скажет и выйдет |
| `stop-tunnel.ps1` | Убить туннель |
| `restart-proxy.ps1` | Жёсткий перезапуск туннеля + PAC-сервера. Использовать если после вкл/выкл Warp (или другого VPN) Claude Desktop завис — значит scheduled tasks были убиты и не поднялись сами |

### PAC (для Claude Desktop)

| Скрипт | Когда использовать |
|---|---|
| `enable-system-pac.ps1` | Включить PAC в Windows: прописывает `AutoConfigURL` в реестр, запускает PAC-сервер. **Запустить один раз** — настройка переживает перезагрузки |
| `disable-system-pac.ps1` | Выключить PAC: убирает `AutoConfigURL` из реестра. Claude Desktop перестанет ходить через прокси |
| `pac-server.ps1` | HTTP-сервер, раздающий `claude-proxy.pac`. Работает в фоне, автозапуск через scheduled task |
| `claude-proxy.pac` | PAC-файл: `claude.ai` и `anthropic.com` → через прокси, всё остальное → напрямую |

### Автозапуск (⚠️ может не работать)

> **Известная проблема:** Windows Scheduled Tasks + PowerShell ненадёжно
> работают в скрытом режиме. Процессы могут получать `CTRL+C` при закрытии
> консольного окна (`0xC000013A`). Используется VBS-обёртка (`run-hidden.vbs`)
> как workaround, но это не гарантирует работу на всех системах.
>
> **Надёжная альтернатива:** создать ярлык на `restart-proxy.ps1` в папке
> автозагрузки (`Win+R` → `shell:startup`).

| Скрипт | Когда использовать |
|---|---|
| `install-autostart.ps1` | Регистрирует 2 scheduled tasks: `LocalProxyForClaude-Tunnel` (SSH-демон) и `LocalProxyForClaude-PAC` (PAC-сервер). Стартуют при логоне, перезапускаются при сбое. **Может не работать — см. выше** |
| `uninstall-autostart.ps1` | Убирает оба task-а, убивает туннель и PAC-сервер |
| `tunnel-daemon.ps1` | Бесконечный цикл: держит SSH-туннель, реконнект при обрыве. Запускается scheduled task-ом, не вручную |
| `restart-proxy.ps1` | Перезапуск туннеля + PAC. Использовать после ребута если автозапуск не сработал |

### Полный откат

| Скрипт | Когда использовать |
|---|---|
| `uninstall-all.ps1` | Снести всё: scheduled tasks, туннель, tinyproxy с сервера, опционально SSH-ключ |

### Конфигурация

| Файл | Что в нём |
|---|---|
| `config.ps1` | **Единая точка конфигурации:** IP сервера, порты, пути к ключу. Все скрипты его подключают |
| `SERVER-INFO.md` | Данные сервера (IP, ключ, что установлено) — **секретный файл** |
| `VPS-SERVER-FULL-SETUP.md` | Полная инструкция настройки сервера с нуля (tinyproxy + XRay/VLESS) |

---

## Как добавить/убрать сайт

### В расширении SwitchyOmega (для Chrome)

Влияет на: какие сайты в Chrome идут через прокси.

**Через GUI (рекомендуется):**
1. Клик по иконке SwitchyOmega → Options
2. В меню слева → **auto switch**
3. **Добавить:** кнопка `+ Add condition` → Host wildcard → `example.com` → Profile: `LocalProxy` → Apply changes. Обычно добавляй парой: `example.com` + `*.example.com`
4. **Убрать:** красная кнопка «−» напротив правила → Apply changes

**Через файл (массовое изменение):**
1. Отредактировать `google chrome extention\browser-extension-config.json` — добавить/убрать правила в массив `rules`
2. В SwitchyOmega: Options → Import/Export → Restore from file → выбрать этот JSON

Подробный гайд: [`google chrome extention/SWITCHYOMEGA-GUIDE.md`](./google%20chrome%20extention/SWITCHYOMEGA-GUIDE.md)

**Сейчас в auto switch:**

| Категория     | Домены |
| ------------- | ------ |
| Anthropic     | `claude.ai`, `anthropic.com` |
| OpenAI        | `chatgpt.com`, `openai.com`, `oaistatic.com`, `oaiusercontent.com` |
| Google AI     | `gemini.google.com`, `aistudio.google.com`, `makersuite.google.com`, `notebooklm.google.com`, `labs.google`, `deepmind.google` |
| Perplexity    | `perplexity.ai` |
| xAI / Grok    | `x.ai`, `grok.com` |
| Meta AI       | `meta.ai` |
| Mistral       | `mistral.ai` |
| Character.AI  | `character.ai` |
| Poe           | `poe.com` |
| Cohere        | `cohere.com` |
| You.com       | `you.com` |
| Cursor        | `cursor.com`, `cursor.sh` |

### В PAC-файле (для Claude Desktop и других системных приложений)

Влияет на: какие сайты из любого приложения Windows (кроме Chrome с SwitchyOmega) идут через прокси.

Редактировать `claude-proxy.pac` — массив `domains`:
```javascript
var domains = [
    "claude.ai",
    "anthropic.com"
    // добавить сюда новый домен
];
```
PAC-сервер читает файл при каждом запросе — изменения подхватываются мгновенно, перезапуск не нужен. Но Claude Desktop надо перезапустить — он кеширует PAC.

**Важно:** порт в PAC-файле (`return "PROXY 127.0.0.1:8888"`) должен совпадать с `LPFC_LocalPort` в `config.ps1`. Если меняешь порт — менять в обоих местах.

### На сервере tinyproxy (обычно не нужно)

Tinyproxy пропускает CONNECT на порты из списка `ConnectPort` в конфиге. Сейчас разрешены: `443, 563, 8443, 80`. Этого хватает для всех HTTPS-сайтов. Менять нужно только если сайт работает на нестандартном порту.

---

## Повседневное использование

| Задача | Команда |
|---|---|
| Запустить Claude Code через прокси | `.\claude-vpn.cmd` |
| Проверить что всё работает | `.\status.ps1` |
| Перезапустить если сломалось | `.\restart-proxy.ps1` |
| Поднять туннель вручную | `.\start-tunnel.ps1` |
| Убить туннель | `.\stop-tunnel.ps1` |

---

## Структура папки

```
<ROOT>\
├── README.md                        # этот файл
├── VPS-SERVER-FULL-SETUP.md         # настройка сервера с нуля (tinyproxy + XRay)
├── config.ps1                       # ЕДИНАЯ конфигурация (IP, порты, пути)
│
├── claude-vpn.cmd                   # запуск Claude Code через прокси
├── claude-tunnel.ps1                # реализация claude-vpn.cmd
│
├── claude-proxy.pac                 # PAC-файл (список доменов для системного прокси)
├── pac-server.ps1                   # HTTP-сервер, раздающий PAC на :8899
├── enable-system-pac.ps1            # включить PAC в Windows
├── disable-system-pac.ps1           # выключить PAC
│
├── start-tunnel.ps1                 # поднять SSH-туннель
├── stop-tunnel.ps1                  # убить туннель
├── status.ps1                       # диагностика
├── tunnel-daemon.ps1                # SSH-демон с реконнектом (для autostart)
│
├── install-autostart.ps1            # scheduled tasks (туннель + PAC)
├── uninstall-autostart.ps1          # убрать scheduled tasks
├── uninstall-all.ps1                # полный откат (Windows + сервер)
│
├── TESTING.md                       # проверка что всё работает
├── SERVER-INFO.md                   # данные сервера (СЕКРЕТНО)
│
├── google chrome extention\         # расширение SwitchyOmega для Chrome
│   ├── browser-extension-config.json   # конфиг с правилами auto switch
│   ├── SWITCHYOMEGA-GUIDE.md           # подробный гайд
│   ├── install-browser-extension.*     # установка расширения
│   └── configure-browser-extension.*   # импорт конфига
│
├── keys\
│   ├── id_ed25519_claude            # приватный SSH-ключ
│   └── id_ed25519_claude.pub        # публичный ключ
│
└── server\
    ├── tinyproxy.conf               # конфиг для сервера
    ├── install-tinyproxy.sh         # установка tinyproxy
    └── uninstall-tinyproxy.sh       # удаление tinyproxy
```

**Смена сервера / переезд:** поменять `config.ps1` + настроить новый сервер по [`VPS-SERVER-FULL-SETUP.md`](./VPS-SERVER-FULL-SETUP.md).

---

## Сервер

- **IP:** `YOUR_SERVER_IP` | **OS:** Ubuntu 22.04 | **Hostname:** `158154.ip-ptr.tech`
- **tinyproxy 1.11.0** на `127.0.0.1:8888` (доступен только через SSH-туннель)
- **XRay (VLESS)** на `0.0.0.0:8080` (VPN для устройств, 4 пользователя)
- **MaxClients:** 200 | **Timeout:** 300 сек
- Подробнее: [`SERVER-INFO.md`](./SERVER-INFO.md) | Настройка: [`VPS-SERVER-FULL-SETUP.md`](./VPS-SERVER-FULL-SETUP.md)

### Безопасность сервера

| Защита | Что делает |
|---|---|
| `PasswordAuthentication no` | Вход по паролю отключён — только SSH-ключ |
| `PermitRootLogin prohibit-password` | Root по паролю невозможен |
| `ClientAliveInterval 30` | Сервер убивает зомби-SSH-сессии через 90 сек — решает проблему «порт 8888 занят после обрыва» |
| `fail2ban` (sshd) | Автобан IP после 5 неудачных попыток на 1 час |

⚠️ **Бэкап SSH-ключа обязателен!** Без ключа из `keys/` на сервер не попасть (только через KVM-консоль провайдера).

### Ограничения сервера

Сервер слабый — **только для текстовых API и лёгких веб-страниц**. Не пускать через него:
- Видео-стриминг (YouTube, Twitch) — один ролик 1080p = 5-8 Мбит/с, убьёт канал
- Скачивание файлов / торренты
- Большое количество одновременных вкладок

AI-чаты (Claude, ChatGPT, Gemini) — лёгкие текстовые запросы, 10-15 одновременных сессий сервер тянет спокойно.

---

## Грабли и заметки

1. **Порт 8888 занят.** Поменяй `LPFC_LocalPort` в `config.ps1` **и** порт в `claude-proxy.pac`. Они должны совпадать. Порт на сервере не трогать.

2. **`curl` в PowerShell — alias.** Использовать `curl.exe` (с расширением), иначе вызовется `Invoke-WebRequest`.

3. **ACL на SSH-ключ.** Windows OpenSSH ругается «Permissions too open» если ключ читаем не только владельцем. Раздел «Ручная установка» описывает правильный ACL.

4. **NO_PROXY.** В `claude-tunnel.ps1` выставлено `NO_PROXY=localhost,127.0.0.1` — иначе локальные MCP-запросы claude пойдут в прокси и сломаются.

5. **Claude Desktop кеширует PAC.** После изменения `claude-proxy.pac` нужно перезапустить Claude Desktop.

6. **UDP через прокси не пойдёт.** HTTP CONNECT = только TCP. Для голосовых звонков (Telegram, Discord) нужен полноценный VPN или VLESS.

7. **Один туннель на всех.** `start-tunnel.ps1` идемпотентный — второй раз не поднимет. Для перезапуска: `stop-tunnel.ps1` → `start-tunnel.ps1`.

8. **`claude login` работает без прокси.** OAuth callback у claude локальный (127.0.0.1), не зависит от прокси.

9. **Warp / другой VPN можно включать когда нужно.** IP сервера (`YOUR_SERVER_IP`) добавлен в split-tunnel исключения Warp (`warp-cli tunnel ip add YOUR_SERVER_IP`) — SSH-туннель идёт напрямую и не рвётся при вкл/выкл Warp. Если после переключения Warp Claude Desktop всё же завис — значит scheduled tasks (`LocalProxyForClaude-Tunnel` / `-PAC`) были убиты вручную (например, через Task Manager) и не восстановились сами: запусти `.\restart-proxy.ps1`. При смене компьютера/переустановке Warp exclude нужно прописать заново.

10. **nano нет на минимальной Ubuntu.** Для записи файлов на сервере использовать `cat > файл << 'EOF'` вместо `nano`.

11. **Зомби-туннели.** Если ПК уснул или потерял сеть — старая SSH-сессия на сервере может повиснуть и держать порт 8888 занятым. `ClientAliveInterval 30` на сервере убивает такие сессии за 90 сек. На клиенте `ServerAliveInterval=30` делает то же со стороны ПК. Двойная защита.

12. **fail2ban может забанить тебя.** Если 5 раз неудачно подключился — IP забанят на 1 час. Разбанить: через KVM-консоль провайдера → `fail2ban-client set sshd unbanip ТВОЙ_IP`. Или подождать час.

13. **SSH-ключ — единственный способ входа.** Пароли на сервере отключены. Потерял ключ → доступ только через KVM/rescue в панели провайдера. Держи бэкап ключа на флешке.

---

## Ручная установка с нуля

<details>
<summary>Развернуть полную инструкцию</summary>

Плейсхолдеры:
- `<SERVER_IP>` — IP сервера
- `<SSH_USER>` — пользователь SSH (обычно `root`)
- `<SSH_PORT>` — порт SSH (обычно `22`)
- `<SSH_PASSWORD>` — пароль для первого захода
- `<ROOT>` — `<ROOT>`

### 1. Требования на Windows

```powershell
(Get-Command ssh -ErrorAction SilentlyContinue).Source     # OpenSSH
(Get-Command node -ErrorAction SilentlyContinue).Source    # Node.js
(Get-Command claude -ErrorAction SilentlyContinue).Source  # Claude Code
```

Если чего-то нет:
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
winget install OpenJS.NodeJS.LTS
npm install -g @anthropic-ai/claude-code
claude login
winget install --id PuTTY.PuTTY -e --silent   # для первого захода по паролю
```

### 2. SSH-ключ

```powershell
$root = "<ROOT>"
$key = "$root\keys\id_ed25519_claude"
ssh-keygen -t ed25519 -f $key -N '""' -C "claude-tunnel@$env:COMPUTERNAME" -q

# ACL — только текущий юзер
$acl = Get-Acl $key
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "$env:USERDOMAIN\$env:USERNAME", "FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $key -AclObject $acl
```

### 3. Установить ключ на сервер

```powershell
$pubkey = (Get-Content "$root\keys\id_ed25519_claude.pub").Trim()
& "C:\Program Files\PuTTY\plink.exe" -ssh -pw "<SSH_PASSWORD>" -P <SSH_PORT> -batch <SSH_USER>@<SERVER_IP> @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -qxF '$pubkey' ~/.ssh/authorized_keys || echo '$pubkey' >> ~/.ssh/authorized_keys
"@
```

### 4. Настроить сервер (tinyproxy + XRay)

См. [`VPS-SERVER-FULL-SETUP.md`](./VPS-SERVER-FULL-SETUP.md) — части 2 и 3.

### 5. Настроить Windows

```powershell
# Отредактировать config.ps1, затем:
cd <ROOT>
.\start-tunnel.ps1
.\status.ps1                    # должен показать UP
.\enable-system-pac.ps1         # PAC для Claude Desktop
.\install-autostart.ps1         # автозапуск при логоне
```

### 6. Настроить Chrome

```powershell
cd "<ROOT>\google chrome extention"
.\install-browser-extension.cmd
.\configure-browser-extension.cmd
```

</details>

---

## Промпты для нового чата

### Настройка Windows-клиента (LocalProxyForClaude)

```
Разверни LocalProxyForClaude — SSH-туннель до моего Linux-сервера с
tinyproxy. Все файлы в <ROOT> —
там уже готовая структура. Прочитай README.md и config.ps1, дальше
делай по инструкции.

Данные сервера:
  SERVER_IP  = <IP>
  SSH_USER   = root
  SSH_PORT   = 22
  SSH_PASS   = <пароль>

Действия: раздел «Ручная установка с нуля» в README.md.
```

### Перегенерация VLESS-ключей на новом IP

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

### Полная настройка сервера с нуля (tinyproxy + XRay)

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

- **2026-09-04:** начальная установка (Ubuntu 22.04, tinyproxy, SSH-туннель, SwitchyOmega) — IP `YOUR_SERVER_IP`
- **2026-09-05:** добавлен PAC для Claude Desktop (Store-приложение), pac-server.ps1, автозапуск PAC
- **2026-09-05:** убран YouTube из расширения (грузит сервер), убран Telegram из прокси
- **2026-09-05:** MaxClients 50→200, Timeout 600→300
- **2026-09-26:** смена IP на `YOUR_SERVER_IP`, повторная настройка tinyproxy и XRay/VLESS с нуля, настройка SwitchyOmega вручную
- **2026-10-07:** захардён SSH — отключены пароли (`PasswordAuthentication no`), включён keepalive (`ClientAliveInterval 30`), установлен fail2ban + rsyslog. Опубликован на GitHub
