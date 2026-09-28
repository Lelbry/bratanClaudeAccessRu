# SwitchyOmega 3 (ZeroOmega) — гайд по настройке

Ручная инструкция как настроить и обслуживать расширение SwitchyOmega
в браузере Chrome (профиль «ваш профиль»). Пригодится если наш готовый
`browser-extension-config.json` не подошёл, если сменил сервер, или если
надо добавить/убрать сайты в правилах.

---

## 0. Что это вообще такое

**SwitchyOmega** — Chrome-расширение, которое позволяет переключать
прокси-серверы (HTTP/HTTPS/SOCKS) прямо из тулбара браузера, а также
задавать правила «для этих сайтов используй прокси A, для остальных —
без прокси».

Работает per-profile — установленный в профиле «ваш профиль» не действует
на другие профили Chrome (LELBRY, Work и т.д.).

**ZeroOmega** — активно поддерживаемый форк оригинального SwitchyOmega
(тот заброшен в 2024). Настройки полностью совместимы.

- **ID расширения:** `pfnededegaaopdmhkdmcofjmoldfiped`
- **Web Store:** https://chromewebstore.google.com/detail/proxy-switchyomega-3-zero/pfnededegaaopdmhkdmcofjmoldfiped
- **GitHub:** https://github.com/zero-peak/ZeroOmega

---

## 1. Установка

### Способ A — Chrome Web Store (обычный)
1. Открыть страницу расширения в Chrome (профиль ваш профиль!): ссылка выше
2. **Add to Chrome** → **Add extension**
3. В тулбаре появится тёмная иконка «O»

Если Web Store не грузится (домен `chromewebstore.google.com` может резаться
у российского провайдера — показывает `0.0.0.3` в адресе) — способ B.

### Способ B — из GitHub-релиза (без Web Store)
1. Скачать `.crx` файл с https://github.com/zero-peak/ZeroOmega/releases
   (последний релиз → asset `ZeroOmega-*.crx` или `zeroomega-chromium.zip`)
2. Открыть `chrome://extensions/` в профиле ваш профиль
3. Включить **Developer mode** (переключатель справа сверху)
4. Перетащить `.crx` файл на страницу
5. Подтвердить установку

### Способ C — из исходников (запасной)
1. Скачать `zeroomega-chromium.zip` из GitHub-релиза, распаковать
2. `chrome://extensions/` → Developer mode ON → **Load unpacked**
3. Указать распакованную папку

---

## 2. Быстрый импорт готового конфига

В нашей папке лежит `browser-extension-config.json` с профилями
`LelbryVPN` и `auto switch` уже настроенными на наш сервер.

1. Клик по иконке SwitchyOmega в тулбаре → шестерёнка **Options**
2. В боковом меню слева: **Import/Export**
3. Раздел **Restore from file** → **Select file** → выбрать
   `<ROOT>\google chrome extention\browser-extension-config.json`
4. Подтвердить **OK** (перезапишет текущие настройки)
5. Все настройки применятся моментально

Или из PowerShell:
```powershell
cd "<ROOT>\google chrome extention"
.\configure-browser-extension.cmd
```

---

## 3. Ручное создание профилей с нуля

Если не хочешь импортировать — можно создать за 2 минуты руками.

### 3.1 Профиль `LelbryVPN` (фиксированный прокси на наш сервер)

1. Открыть Options SwitchyOmega
2. В боковом меню слева → **+ New profile...**
3. Заполнить:
   - **Profile name:** `LelbryVPN`
   - **Profile type:** ◉ **Proxy Profile** (Fixed proxy servers)
4. **Create** → откроется страница профиля

5. В таблице **Proxy servers**, строка `(default)`:
   - **Protocol:** `HTTP`
   - **Server:** `127.0.0.1`
   - **Port:** `8888`

6. В **Bypass List** внизу написать (по строке):
   ```
   127.0.0.1
   localhost
   [::1]
   <local>
   ```

7. Нажать **Apply changes** (зелёная кнопка слева внизу)

### 3.2 Профиль `auto switch` (умное переключение по правилам)

1. **+ New profile...**
2. Заполнить:
   - **Profile name:** `auto switch`
   - **Profile type:** ◉ **Switch Profile** (rule-based)
3. **Create**

4. На странице профиля — таблица **Switch rules**. Каждая строка = одно правило.
   Для каждого сайта, который должен идти через сервер:
   - **Condition type:** `Host wildcard`
   - **Condition details:** `*.claude.ai` (например)
   - **Profile:** выбрать `LelbryVPN`
5. Внизу таблицы **Default:** установить в `[Direct]` (весь остальной
   трафик — напрямую)
6. **Apply changes**

Правила из нашего готового конфига (для копипаста):
```
*.claude.ai              → LelbryVPN
claude.ai                → LelbryVPN
*.anthropic.com          → LelbryVPN
anthropic.com            → LelbryVPN
*.openai.com             → LelbryVPN
openai.com               → LelbryVPN
*.chatgpt.com            → LelbryVPN
chatgpt.com              → LelbryVPN
*.oaistatic.com          → LelbryVPN
*.oaiusercontent.com     → LelbryVPN
gemini.google.com        → LelbryVPN
aistudio.google.com      → LelbryVPN
makersuite.google.com    → LelbryVPN
notebooklm.google.com    → LelbryVPN
labs.google              → LelbryVPN
deepmind.google          → LelbryVPN
*.perplexity.ai          → LelbryVPN
perplexity.ai            → LelbryVPN
grok.com                 → LelbryVPN
*.grok.com               → LelbryVPN
x.ai                     → LelbryVPN
*.x.ai                   → LelbryVPN
meta.ai                  → LelbryVPN
*.meta.ai                → LelbryVPN
mistral.ai               → LelbryVPN
*.mistral.ai             → LelbryVPN
character.ai             → LelbryVPN
*.character.ai           → LelbryVPN
poe.com                  → LelbryVPN
*.poe.com                → LelbryVPN
cohere.com               → LelbryVPN
*.cohere.com             → LelbryVPN
you.com                  → LelbryVPN
*.you.com                → LelbryVPN
cursor.com               → LelbryVPN
*.cursor.com             → LelbryVPN
cursor.sh                → LelbryVPN
Default                  → [Direct]
```

---

## 4. Использование (тулбар)

Клик по иконке SwitchyOmega в правом верхнем углу Chrome → выпадает
меню с профилями:

| Пункт        | Что делает                                                  |
| ------------ | ----------------------------------------------------------- |
| `[Direct]`   | Прокси отключён — всё напрямую (заводской)                  |
| `[System]`   | Использовать системный прокси Windows (обычно = Direct)     |
| `LelbryVPN`  | Весь трафик Chrome в этом окне через `127.0.0.1:8888`       |
| `auto switch`| Только сайты из правил → LelbryVPN, остальное → [Direct]    |

**Рекомендую держать `auto switch`.** Поставил один раз — и работает
автоматически: клод/чатгпт/гемини идут через сервер, всё остальное
(российские сайты, банки, ютуб если он у тебя работает и т.д.) —
напрямую с полной скоростью.

Индикатор в тулбаре меняет цвет в зависимости от активного профиля.

---

## 5. Где что менять в будущем

### 5.1 Поменять IP/порт сервера
Если сменил VPS или переехал tinyproxy на другой порт:

1. Options → в меню слева выбрать **LelbryVPN**
2. Изменить **Server** и/или **Port**
3. **Apply changes**

Автоматически применится, все правила auto switch будут пользоваться
новым адресом (они ссылаются на профиль `LelbryVPN` по имени, не по IP).

Не забудь параллельно обновить и наш локальный `config.ps1`:
```powershell
# <ROOT>\config.ps1
$Global:LPFC_SshHost   = "новый-ip"
$Global:LPFC_LocalPort = 8888   # если сменил
```

### 5.2 Добавить новый сайт в auto switch
1. Options → в меню слева выбрать **auto switch**
2. **+ Add condition** (снизу таблицы)
3. Condition type: `Host wildcard`, details: `example.com` или `*.example.com`
4. Profile: `LelbryVPN`
5. **Apply changes**

Домены типа `*.example.com` матчат `sub.example.com`, `a.b.example.com`,
но **НЕ** голый `example.com` — поэтому обычно добавляют парой:
`example.com` + `*.example.com`.

### 5.3 Убрать сайт
Options → auto switch → красная кнопка «-» напротив правила → Apply.

### 5.4 Bypass List — исключения для LelbryVPN
Если хочешь чтобы какой-то домен ВСЕГДА шёл напрямую даже когда
активен профиль LelbryVPN — добавь в Bypass List этого профиля.

Уже там (не трогать):
- `127.0.0.1`, `localhost`, `[::1]`, `<local>` — локальный трафик и
  RFC1918 (192.168.x.x, 10.x.x.x)

Пример добавления `mysite.ru`:
```
127.0.0.1
localhost
[::1]
<local>
mysite.ru
*.mysite.ru
```

### 5.5 Импорт/экспорт всех настроек
- **Экспорт:** Options → Import/Export → **Download backup**
  (сохраняется .bak файл — это тот же JSON)
- **Импорт:** Import/Export → **Restore from file**

Сохранённый `.bak` можно положить в нашу папку рядом с
`browser-extension-config.json` — бэкап всей твоей текущей конфигурации.

---

## 6. Проверки

### Работает ли LelbryVPN
1. Убедиться что туннель поднят: `.\status.ps1` в нашей папке
2. Переключить SwitchyOmega на `LelbryVPN`
3. Открыть `https://api.ipify.org`
4. Должно показать `YOUR_SERVER_IP` (IP сервера)

Переключить обратно на `[Direct]` — должен быть твой реальный IP.

### Работает ли auto switch
1. Переключить SwitchyOmega на `auto switch`
2. Открыть `https://api.ipify.org` — должно показать **твой** IP
   (потому что `api.ipify.org` не в правилах — идёт напрямую)
3. Открыть `https://claude.ai` — должно показать
   IP сервера **в консоли разработчика** (F12 → Network → любой запрос
   → Remote address). Или просто должно открыться без «недоступно
   в вашей стране».

### Индикатор какое правило сработало
На странице любого сайта — правый клик по иконке SwitchyOmega →
**Show conditions for URL: ...** → покажет какое правило матчнуло
и какой профиль применился. Полезно при отладке.

---

## 7. Частые проблемы

### `ERR_PROXY_CONNECTION_FAILED` на всех LelbryVPN-сайтах
Туннель не поднят или tinyproxy на сервере упал.
```powershell
cd <ROOT>
.\status.ps1
# Если DOWN:
.\start-tunnel.ps1
```

### Сайт открывается, но всё равно `region blocked`
Проверить IP из-под этой вкладки: открой в этом же окне `https://api.ipify.org`
— должно показать IP сервера (`YOUR_SERVER_IP`). Если показывает твой реальный IP —
правило auto switch не сработало, надо добавить домен в Options → auto switch.
Если показывает `→ [Direct]` — правила не хватает, добавить.

Также некоторые сайты (Anthropic, OpenAI) блокируют по
геолокации аккаунта а не только IP. Если ты когда-то регистрировался
из России, аккаунт может быть помечен — иногда помогает создать
новый аккаунт уже под VPN.

### DNS-утечка (сайт грузит но всё равно не работает)
SwitchyOmega в режиме HTTP-прокси отправляет CONNECT-запросы с
именем домена — DNS резолвится на сервере (в tinyproxy → системный
DNS сервера). Утечек по идее не должно.

Проверить: включить `LelbryVPN`, открыть https://dnsleaktest.com
→ Standard test → все DNS-сервера должны быть на IP сервера или
близких к нему, НЕ твой российский провайдер.

### Расширение пропало после обновления Chrome
Иногда Chrome отключает расширения после мажорных обновлений.
`chrome://extensions/` → найти ZeroOmega → включить переключатель.

### Ошибка «Manifest V2» или «Not supported»
Оригинальный SwitchyOmega перестал работать из-за MV3. Мы
используем именно **Zero Omega** (форк на MV3). Если поставил
не тот форк — удали (`chrome://extensions/`) и поставь по ссылке
в разделе 1.

---

## 8. Полное удаление (если что-то пошло совсем не так)

1. `chrome://extensions/` в профиле ваш профиль
2. Найти **Proxy SwitchyOmega 3 (ZeroOmega)** → **Remove**
3. Подтвердить

Настройки при этом удалятся с этого профиля. На других профилях
Chrome (если ставил куда-то ещё) — отдельно.

Данные расширения физически хранятся в:
```
%LOCALAPPDATA%\Google\Chrome\User Data\YOUR_PROFILE\Local Extension Settings\pfnededegaaopdmhkdmcofjmoldfiped\
```
После удаления через Chrome эта папка тоже уйдёт.

---

## 9. Технические детали (для любопытных)

**Как проксирование HTTPS работает через HTTP-прокси:**
Chrome шлёт tinyproxy'ю запрос `CONNECT api.anthropic.com:443 HTTP/1.1`.
Tinyproxy открывает TCP-соединение с целевым хостом и после этого
работает как байтовый туннель — весь TLS-трафик идёт end-to-end
между Chrome и целевым сайтом, tinyproxy его не расшифровывает
и не может подслушать.

Из-за этого:
- Cертификаты сайтов валидны (никакого MITM)
- Прокси видит только имя хоста (SNI/CONNECT header) и не видит URL/куки
- Работает с любым HTTPS-сайтом без сертификатных костылей

**Почему `direct` для российских сайтов важно:**
Если пустить российские сайты через VPN — они видят зарубежный IP,
могут блокировать (по факту многие блокируют иностранный трафик,
например госуслуги, банки). Плюс скорость до российских серверов
через зарубежный VPS будет 200-500ms вместо нативных 5-20ms.
Поэтому auto switch — единственный правильный режим для повседневки.
