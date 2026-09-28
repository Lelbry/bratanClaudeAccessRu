# TESTING — проверка что наша схема работает без старых VPN

Инструкция как убедиться что LocalProxyForClaude полностью заменяет
Invisible Man XRay / Cloudflare WARP, и всё работает без них.

---

## Проблема которую решаем

Invisible Man XRay при запуске включает **Windows System Proxy**
(Internet Options → LAN settings → Use a proxy server) с адресом
`127.0.0.1:10801`. В одной из более старых версий при закрытии он
не сбрасывал эту настройку обратно — по последней проверке (5 сент.)
свежая версия сбрасывает `ProxyEnable` сама. Так что это может
зависеть от версии/сборки — просто проверяй, а не считай проблему
гарантированной.

Если всё же не сбросится:
- Порт 10801 больше не слушается (клиент закрыт)
- Windows System Proxy всё ещё говорит всем приложениям «шли через 10801»
- Node.js / claude CLI / Chrome без прокси-расширения читают эту
  настройку и **виснут** на попытке подключиться к мёртвому порту

Наш `claude-vpn.cmd` явно перекрывает `HTTPS_PROXY=127.0.0.1:8888` для
своего процесса, но это не всегда помогает если приложение читает
не env-var, а WinINet (Windows-специфичный API системного прокси).

## Что уже сделано автоматически

```powershell
# Отключён Windows System Proxy:
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value ""
```

⚠️ **Пока не снесён Invisible Man — эта настройка вернётся каждый раз
когда ты его запустишь.** Пока просто держи в голове: включил Invisible
Man → выключил → сразу запусти команду сброса (см. раздел «Быстрый фикс»).

---

## Пошаговая проверка

### Шаг 1 — Выключить старые VPN

В системном трее (правый нижний угол Windows):
- **Invisible Man XRay** → правый клик → **Exit** / **Выход**
- **Cloudflare WARP** → правый клик → **Disconnect** (или Exit)
- **Radmin VPN** — не влияет на claude, можно оставить

### Шаг 2 — Убедиться что порт 10801 мёртв

Открой **новый** PowerShell (Win+X → Terminal):
```powershell
Get-NetTCPConnection -LocalPort 10801 -State Listen -ErrorAction SilentlyContinue
```
Должно быть **пусто** (ни одной строки).

### Шаг 3 — Проверить прямой интернет

```powershell
curl.exe -s https://api.ipify.org
```
Должно показать **твой реальный российский IP** (не `YOUR_SERVER_IP`).

Если висит или ошибка — значит system proxy ещё где-то указан. Сбросить:
```powershell
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
```

### Шаг 4 — Проверить наш туннель

```powershell
cd <ROOT>
.\status.ps1
```

Ожидаемый вывод:
```
[tunnel]  UP    port 127.0.0.1:8888  (ssh PID: XXXX)
[proxy]   OK    api.anthropic.com отвечает HTTP 404
[ip]      via proxy: YOUR_SERVER_IP
[ip]      direct:    <твой российский IP>
          Прокси корректно отправляет трафик через YOUR_SERVER_IP
[autostart] enabled (Running)
```

**Ключевой момент:** `direct` и `via proxy` теперь **разные** — значит
наш туннель реально шлёт claude-трафик через сервер, а не через
чужой VPN.

### Шаг 5 — Запустить claude через наш лаунчер

```powershell
.\claude-vpn.cmd
```

Ожидаемое поведение в терминале:
```
[tunnel] already up on 127.0.0.1:8888
[proxy] testing...
[proxy] OK (HTTP 200)     ← или 301, 404 - всё в диапазоне 2xx/3xx/4xx ок
[claude] launching (traffic via YOUR_SERVER_IP)
```
Затем стартует claude, показывает свой промпт.

Внутри claude:
```
> сделай curl https://api.ipify.org и покажи IP
```
Должно вернуть `YOUR_SERVER_IP` (IP сервера).

### Шаг 6 — Проверить что и голый `claude` работает

В том же терминале (system proxy уже выключен):
```powershell
claude
```
Тоже должен нормально стартовать — но идти **напрямую** с российского IP
(без прокси, потому что переменная не задана).

Это нужно чтобы убедиться: пропавший `HTTPS_PROXY=10801` больше не
портит claude при обычном запуске.

### Шаг 7 — Chrome с расширением SwitchyOmega

Открой Chrome (профиль **ваш профиль**). Проверь что в тулбаре SwitchyOmega
стоит в режиме **auto switch**.

Проверить:
- `https://api.ipify.org` в этой вкладке — покажет **твой реальный IP**
  (сайт не в правилах — идёт напрямую)
- `https://claude.ai` — открывается без «region blocked»
- `https://gemini.google.com` — открывается
- `https://youtube.com` — видео стримит

Если хочешь глазами убедиться что claude.ai идёт через сервер:
переключи SwitchyOmega с `auto switch` на `LelbryVPN` → открой
`https://api.ipify.org` → должно быть `YOUR_SERVER_IP`. Потом обратно
на `auto switch`.

---

## Если что-то не работает

### `claude-vpn.cmd` пишет `[proxy] FAIL`
Туннель не поднят или tinyproxy на сервере упал.
```powershell
cd <ROOT>
.\stop-tunnel.ps1
.\start-tunnel.ps1
.\status.ps1
```
Если после этого туннель UP но proxy FAIL — проблема на сервере:
```powershell
ssh -i .\keys\id_ed25519_claude root@YOUR_SERVER_IP "systemctl restart tinyproxy; systemctl is-active tinyproxy"
```

### Голый `claude` (без лаунчера) виснет
System proxy опять включён. Проверить и сбросить:
```powershell
(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
# если 1 - сбросить:
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
```

### Chrome в профиле ваш профиль грузит претормаживает
Открой SwitchyOmega → должно быть **auto switch** а не LelbryVPN
(при LelbryVPN весь трафик — включая яндекс, госуслуги — идёт через
Германию, что медленно).

### Claude.ai всё равно `region blocked`
Проверить IP: в этом же Chrome-окне открыть `https://api.ipify.org`.
Должно быть `YOUR_SERVER_IP`. Если твой российский — правило SwitchyOmega
не сработало, добавь `claude.ai` вручную (см. `google chrome extention/SWITCHYOMEGA-GUIDE.md`).

Иногда Anthropic блокирует по геолокации **аккаунта** (не IP) — если ты
регистрировался из России, аккаунт помечен. Создать новый уже под VPN.

---

## Быстрый фикс если Invisible Man опять поставил system proxy

Одна команда — сбрасывает всё:
```powershell
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value ""
```

Скопируй себе куда-нибудь, если пока держишь Invisible Man на всякий случай.

---

## Долгосрочное решение

Проблема с system proxy возвращается каждый раз при запуске Invisible
Man XRay. Три пути:

1. **Снести Invisible Man / Cloudflare WARP** ⭐ рекомендую — наша схема
   их полностью заменяет. См. `uninstall-all.ps1` для отдельного сноса
   tinyproxy с сервера если понадобится начать с нуля; и раздел
   «План миграции» в README.md для сноса старых клиентов Windows.

2. **Найти в настройках Invisible Man галочку «не менять system proxy»**
   — если есть в конкретной версии. Тогда клиент будет работать только
   через свой TUN, не трогая WinINet.

3. **Каждый раз после закрытия Invisible Man руками отключать system
   proxy** одной командой выше. Через месяц надоест — сам снесёшь.

---

## Как проверить что старые VPN точно не мешают (после сноса)

```powershell
# 1. Ни один из этих процессов не запущен:
Get-Process | Where-Object { $_.Name -match 'invisible|xray|v2ray|warp|clash' }
# Должно быть пусто.

# 2. System proxy выключен:
(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
# Должно быть 0.

# 3. Порты старых VPN мертвы:
Get-NetTCPConnection -LocalPort 10801,10809,1080,7890 -State Listen -EA 0
# Должно быть пусто.

# 4. Наш туннель жив:
<ROOT>\status.ps1
# Должно быть [tunnel] UP + [proxy] OK.

# 5. Прямой IP - твой российский, через прокси - серверный:
curl.exe -s https://api.ipify.org
curl.exe -s -x http://127.0.0.1:8888 https://api.ipify.org
# Первая команда - российский IP, вторая - YOUR_SERVER_IP.
```

Если все пункты OK — миграция завершена, старые VPN больше не нужны.
