# setup.ps1
# ============================================================================
# Первая настройка LocalProxyForClaude.
# Задаёт параметры сервера, генерирует конфиги, ставит автозагрузку.
# Запускать один раз при первой установке. Можно перезапустить для смены настроек.
#
# Использование:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
# ============================================================================

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ---------------------------------------------------------------------------
# Попробовать прочитать текущие значения (если уже настроено)
# ---------------------------------------------------------------------------
$defaults = @{
    SshHost       = ""
    SshUser       = "root"
    SshPort       = 22
    LocalPort     = 8888
    RemotePort    = 8888
    PacPort       = 8899
    ChromeProfile = ""
}

$configPath = Join-Path $root "config.ps1"
if (Test-Path $configPath) {
    . $configPath
    if ($LPFC_SshHost)       { $defaults.SshHost       = $LPFC_SshHost }
    if ($LPFC_SshUser)       { $defaults.SshUser       = $LPFC_SshUser }
    if ($LPFC_SshPort)       { $defaults.SshPort       = $LPFC_SshPort }
    if ($LPFC_LocalPort)     { $defaults.LocalPort     = $LPFC_LocalPort }
    if ($LPFC_RemotePort)    { $defaults.RemotePort    = $LPFC_RemotePort }
    if ($LPFC_PacPort)       { $defaults.PacPort       = $LPFC_PacPort }
    if ($LPFC_ChromeProfile) { $defaults.ChromeProfile = $LPFC_ChromeProfile }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Ask($prompt, $default) {
    $display = if ($default) { " [$default]" } else { "" }
    $val = Read-Host "$prompt$display"
    if ([string]::IsNullOrWhiteSpace($val)) { return $default }
    return $val.Trim()
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  LocalProxyForClaude — Настройка" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Система создаёт SSH-туннель до твоего сервера с tinyproxy" -ForegroundColor Gray
Write-Host "и маршрутизирует трафик AI-сервисов (Claude, ChatGPT, Gemini," -ForegroundColor Gray
Write-Host "Grok, Perplexity и др.) через него." -ForegroundColor Gray
Write-Host ""
Write-Host "Нажми Enter, чтобы оставить значение по умолчанию [в скобках]." -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Параметры сервера
# ---------------------------------------------------------------------------
Write-Host "--- Сервер ---" -ForegroundColor Yellow

$sshHost = Ask "IP-адрес сервера" $defaults.SshHost
while ([string]::IsNullOrWhiteSpace($sshHost)) {
    Write-Host "  IP-адрес обязателен!" -ForegroundColor Red
    $sshHost = Ask "IP-адрес сервера" ""
}

$sshUser    = Ask "SSH-пользователь" $defaults.SshUser
$sshPort    = [int](Ask "SSH-порт" $defaults.SshPort)
$localPort  = [int](Ask "Локальный порт туннеля" $defaults.LocalPort)
$remotePort = [int](Ask "Порт tinyproxy на сервере" $defaults.RemotePort)
$pacPort    = [int](Ask "Порт PAC-сервера (раздаёт прокси-конфиг)" $defaults.PacPort)

# ---------------------------------------------------------------------------
# 2. Chrome-профиль
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Chrome-профиль (для расширения SwitchyOmega) ---" -ForegroundColor Yellow

$localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
$profiles = @()
if (Test-Path $localState) {
    try {
        $json = Get-Content $localState -Raw | ConvertFrom-Json
        $infoCache = $json.profile.info_cache
        $infoCache.PSObject.Properties | ForEach-Object {
            $profiles += [PSCustomObject]@{
                Dir  = $_.Name
                Name = $_.Value.name
            }
        }
    } catch {}
}

$chromeProfile = ""
if ($profiles.Count -gt 0) {
    Write-Host "Обнаруженные профили Chrome:" -ForegroundColor Gray
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $marker = ""
        if ($defaults.ChromeProfile -and $profiles[$i].Dir -eq $defaults.ChromeProfile) {
            $marker = " (текущий)"
        }
        Write-Host "  $($i+1). $($profiles[$i].Name)  [$($profiles[$i].Dir)]$marker" -ForegroundColor White
    }
    Write-Host "  0. Пропустить (настрою потом)" -ForegroundColor DarkGray
    Write-Host ""
    $profileChoice = Ask "Номер профиля" ""
    if ($profileChoice -match '^\d+$' -and [int]$profileChoice -ge 1 -and [int]$profileChoice -le $profiles.Count) {
        $chromeProfile = $profiles[[int]$profileChoice - 1].Dir
        Write-Host "  -> $($profiles[[int]$profileChoice - 1].Name) ($chromeProfile)" -ForegroundColor Green
    } elseif ($defaults.ChromeProfile) {
        $chromeProfile = $defaults.ChromeProfile
        Write-Host "  -> оставлен: $chromeProfile" -ForegroundColor Green
    }
} else {
    Write-Host "Chrome не найден или профили не определены." -ForegroundColor DarkGray
    $chromeProfile = Ask "Папка профиля Chrome (напр. 'Default', 'Profile 1') или Enter — пропустить" $defaults.ChromeProfile
}

# ---------------------------------------------------------------------------
# 3. SSH-ключ
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- SSH-ключ ---" -ForegroundColor Yellow

$keyDir  = Join-Path $root "keys"
$keyPath = Join-Path $keyDir "id_ed25519_claude"

if (Test-Path $keyPath) {
    Write-Host "Ключ уже на месте: $keyPath" -ForegroundColor Green
} else {
    if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force | Out-Null }

    Write-Host "SSH-ключ не найден." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Сгенерировать новый ключ (рекомендуется)" -ForegroundColor White
    Write-Host "  2. Я сам положу ключ в $keyPath" -ForegroundColor White
    Write-Host ""
    $keyChoice = Ask "Выбор" "1"

    if ($keyChoice -eq "1") {
        Write-Host ""
        Write-Host "Генерирую ключ..." -ForegroundColor Cyan
        & ssh-keygen -t ed25519 -C "claude-tunnel" -f $keyPath -N ""
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  ВАЖНО: добавь публичный ключ на сервер!" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Публичный ключ:" -ForegroundColor Cyan
        Write-Host (Get-Content "$keyPath.pub") -ForegroundColor White
        Write-Host ""
        Write-Host "Команда для добавления (выполни на СВОЁМ ПК):" -ForegroundColor Cyan
        Write-Host "  type `"$keyPath.pub`" | ssh ${sshUser}@${sshHost} -p $sshPort `"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys`"" -ForegroundColor White
        Write-Host ""
        Read-Host "Нажми Enter когда ключ добавлен на сервер"
    } else {
        Write-Host ""
        Write-Host "Положи приватный ключ (id_ed25519_claude) в:" -ForegroundColor Yellow
        Write-Host "  $keyPath" -ForegroundColor White
        Write-Host ""
        Read-Host "Нажми Enter когда готово"
        if (-not (Test-Path $keyPath)) {
            Write-Host "  Ключ не найден. Туннель не заработает без него!" -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Записываем config.ps1
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Записываю конфиги ---" -ForegroundColor Cyan

$configContent = @"
# config.ps1
# ============================================================================
# Единая точка конфигурации LocalProxyForClaude.
# Все скрипты в этой папке дот-сорсят этот файл: ``. `$PSScriptRoot\config.ps1``
# Меняешь тут - меняется везде.
#
# Сгенерировано setup.ps1 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Можно редактировать вручную или перезапустить setup.ps1
# ============================================================================

# --- Сервер ---
`$Global:LPFC_SshHost    = "$sshHost"
`$Global:LPFC_SshUser    = "$sshUser"
`$Global:LPFC_SshPort    = $sshPort

# --- Туннель ---
`$Global:LPFC_LocalPort  = $localPort    # порт на этом ПК (127.0.0.1:LocalPort -> прокси на сервере)
`$Global:LPFC_RemotePort = $remotePort   # порт tinyproxy на сервере (слушает 127.0.0.1)

# --- PAC-сервер ---
`$Global:LPFC_PacPort    = $pacPort      # HTTP-сервер, раздающий PAC-файл (http://127.0.0.1:PacPort/proxy.pac)

# --- Chrome (для скриптов SwitchyOmega) ---
`$Global:LPFC_ChromeProfile = "$chromeProfile"   # папка профиля Chrome (напр. "Default", "Profile 1")

# --- Пути ---
`$Global:LPFC_Root       = Split-Path -Parent `$MyInvocation.MyCommand.Definition
`$Global:LPFC_KeyPath    = Join-Path `$Global:LPFC_Root "keys\id_ed25519_claude"
`$Global:LPFC_LogFile    = Join-Path `$Global:LPFC_Root "tunnel.log"

# --- Имена scheduled tasks для автозапуска ---
`$Global:LPFC_TaskName      = "LocalProxyForClaude-Tunnel"
`$Global:LPFC_PacTaskName   = "LocalProxyForClaude-PAC"

# --- Хелперы ---
function LPFC-IsTunnelUp {
    `$conn = Get-NetTCPConnection -LocalPort `$Global:LPFC_LocalPort -State Listen -ErrorAction SilentlyContinue |
        Where-Object { `$_.LocalAddress -eq "127.0.0.1" }
    return [bool]`$conn
}

function LPFC-GetTunnelPids {
    `$pids = @()
    Get-Process ssh -ErrorAction SilentlyContinue | ForEach-Object {
        `$cl = (Get-CimInstance Win32_Process -Filter "ProcessId=`$(`$_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if (`$cl -and `$cl -like "*`$(`$Global:LPFC_KeyPath)*") { `$pids += `$_.Id }
    }
    return `$pids
}
"@

Set-Content -Path $configPath -Value $configContent -Encoding UTF8
Write-Host "  config.ps1" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Перегенерируем claude-proxy.pac с актуальным портом
# ---------------------------------------------------------------------------
$pacPath = Join-Path $root "claude-proxy.pac"
$pacContent = @"
// claude-proxy.pac
// Системный PAC-скрипт: только домены Anthropic/Claude и другие AI-сервисы
// идут через наш туннель (127.0.0.1:$localPort), весь остальной интернет — напрямую.
//
// Домены можно добавлять/убирать. При раздаче через pac-server.ps1 порт
// подставляется из config.ps1 автоматически.

function FindProxyForURL(url, host) {
    var domains = [
        "claude.ai",
        "anthropic.com"
    ];

    for (var i = 0; i < domains.length; i++) {
        var d = domains[i];
        if (host == d || dnsDomainIs(host, "." + d)) {
            return "PROXY 127.0.0.1:$localPort";
        }
    }

    return "DIRECT";
}
"@

Set-Content -Path $pacPath -Value $pacContent -Encoding UTF8
Write-Host "  claude-proxy.pac" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Перегенерируем browser-extension-config.json с актуальным портом
# ---------------------------------------------------------------------------
$extConfigPath = Join-Path $root "google chrome extention\browser-extension-config.json"
$extConfigRaw = Get-Content $extConfigPath -Raw
$extConfigRaw = $extConfigRaw -replace '"port":\s*\d+', "`"port`": $localPort"
Set-Content -Path $extConfigPath -Value $extConfigRaw -Encoding UTF8
Write-Host "  browser-extension-config.json" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 7. Автозагрузка
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Автозагрузка ---" -ForegroundColor Yellow
$autostart = Ask "Установить автозагрузку (туннель + PAC при старте Windows)? [Y/n]" "Y"
if ($autostart -ne "n" -and $autostart -ne "N") {
    & "$root\install-autostart.ps1"
} else {
    Write-Host "  Пропущено. Запустить потом: .\install-autostart.ps1" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 8. Системный PAC (для Claude Desktop из Microsoft Store)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Системный PAC ---" -ForegroundColor Yellow
Write-Host "Нужно только если используешь Claude Desktop из Microsoft Store." -ForegroundColor Gray
Write-Host "(Если используешь только браузер с SwitchyOmega — не нужно)" -ForegroundColor Gray
$enablePac = Ask "Включить системный PAC? [y/N]" "N"
if ($enablePac -eq "y" -or $enablePac -eq "Y") {
    & "$root\enable-system-pac.ps1"
} else {
    Write-Host "  Пропущено. Включить потом: .\enable-system-pac.ps1" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 9. Итог
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Готово!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Что настроено:" -ForegroundColor Cyan
Write-Host "  Сервер:     $sshHost (SSH: ${sshUser}@${sshHost}:$sshPort)" -ForegroundColor White
Write-Host "  Туннель:    127.0.0.1:$localPort -> сервер:$remotePort" -ForegroundColor White
Write-Host "  PAC:        http://127.0.0.1:${pacPort}/proxy.pac" -ForegroundColor White
if ($chromeProfile) {
    Write-Host "  Chrome:     профиль '$chromeProfile'" -ForegroundColor White
}
Write-Host ""
Write-Host "Полезные команды:" -ForegroundColor Cyan
Write-Host "  .\status.ps1              — проверить что всё работает" -ForegroundColor White
Write-Host "  .\start-tunnel.ps1        — запустить туннель вручную" -ForegroundColor White
Write-Host "  .\stop-tunnel.ps1         — остановить туннель" -ForegroundColor White
Write-Host "  .\restart-proxy.ps1       — перезапустить всё" -ForegroundColor White
Write-Host ""

if ($chromeProfile) {
    Write-Host "Для Chrome (SwitchyOmega):" -ForegroundColor Cyan
    Write-Host "  cd '.\google chrome extention'" -ForegroundColor White
    Write-Host "  .\install-browser-extension.ps1    — установить расширение" -ForegroundColor White
    Write-Host "  .\configure-browser-extension.ps1  — импортировать конфиг" -ForegroundColor White
    Write-Host ""
}

Write-Host "Перенастроить? Запусти setup.ps1 ещё раз." -ForegroundColor DarkGray
Write-Host ""
