# setup.ps1
# ============================================================================
# Первая настройка LocalProxyForClaude.
# Создаёт private/server.ps1 с личными данными сервера, кладёт SSH-ключ,
# ставит автозагрузку. Запускать один раз при первой установке.
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
    ChromeProfile = ""
}

$privateDir  = Join-Path $root "private"
$privateCfg  = Join-Path $privateDir "server.ps1"
if (Test-Path $privateCfg) {
    . $privateCfg
    if ($LPFC_SshHost)       { $defaults.SshHost       = $LPFC_SshHost }
    if ($LPFC_SshUser)       { $defaults.SshUser       = $LPFC_SshUser }
    if ($LPFC_SshPort)       { $defaults.SshPort       = $LPFC_SshPort }
    if ($LPFC_ChromeProfile) { $defaults.ChromeProfile = $LPFC_ChromeProfile }
}

# Порты туннеля — общие значения из config.ps1 (нужны для PAC-файла и browser-config).
$configPath = Join-Path $root "config.ps1"
$LocalPort = 8888   # fallback если config.ps1 ещё не считан
if (Test-Path $configPath) {
    # Читаем только LocalPort, напрямую (не дот-сорсим — иначе упадёт из-за отсутствия server.ps1)
    $raw = Get-Content $configPath -Raw
    if ($raw -match 'LPFC_LocalPort\s*=\s*(\d+)') { $LocalPort = [int]$matches[1] }
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
Write-Host "Личные данные (IP, SSH-порт, Chrome-профиль) сохранятся в" -ForegroundColor Gray
Write-Host "  private\server.ps1" -ForegroundColor Gray
Write-Host "— эта папка в .gitignore, ничего из неё в репу не попадает." -ForegroundColor Gray
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

$sshUser = Ask "SSH-пользователь" $defaults.SshUser
$sshPort = [int](Ask "SSH-порт" $defaults.SshPort)

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
# 4. Записываем private\server.ps1
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Записываю конфиги ---" -ForegroundColor Cyan

if (-not (Test-Path $privateDir)) {
    New-Item -ItemType Directory -Path $privateDir -Force | Out-Null
}

$privateContent = @"
# private/server.ps1
# ============================================================================
# ТВОИ ЛИЧНЫЕ ДАННЫЕ СЕРВЕРА.
# Этот файл в .gitignore (вместе со всей папкой private/) — не пушится.
# Общий config.ps1 из корня дот-сорсит этот файл.
#
# Сгенерировано setup.ps1 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Можно редактировать вручную или перезапустить setup.ps1.
# ============================================================================

# --- Сервер ---
`$Global:LPFC_SshHost    = "$sshHost"
`$Global:LPFC_SshUser    = "$sshUser"
`$Global:LPFC_SshPort    = $sshPort

# --- Chrome-профиль (для скриптов SwitchyOmega) ---
`$Global:LPFC_ChromeProfile = "$chromeProfile"
"@

Set-Content -Path $privateCfg -Value $privateContent -Encoding UTF8
Write-Host "  private\server.ps1" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Обновляем claude-proxy.pac — на случай если менялся LocalPort
# ---------------------------------------------------------------------------
$pacPath = Join-Path $root "claude-proxy.pac"
if (Test-Path $pacPath) {
    $pacRaw = Get-Content $pacPath -Raw
    $pacRaw = $pacRaw -replace 'PROXY 127\.0\.0\.1:\d+', "PROXY 127.0.0.1:$LocalPort"
    Set-Content -Path $pacPath -Value $pacRaw -Encoding UTF8
    Write-Host "  claude-proxy.pac (порт $LocalPort)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 6. Обновляем browser-extension-config.json с актуальным портом
# ---------------------------------------------------------------------------
$extConfigPath = Join-Path $root "google chrome extention\browser-extension-config.json"
if (Test-Path $extConfigPath) {
    $extConfigRaw = Get-Content $extConfigPath -Raw
    $extConfigRaw = $extConfigRaw -replace '"port":\s*\d+', "`"port`": $LocalPort"
    Set-Content -Path $extConfigPath -Value $extConfigRaw -Encoding UTF8
    Write-Host "  browser-extension-config.json" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 7. Системный PAC (для Claude Desktop из Microsoft Store)
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
# 8. Итог
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Готово!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Что настроено:" -ForegroundColor Cyan
Write-Host "  Сервер:     $sshHost (SSH: ${sshUser}@${sshHost}:$sshPort)" -ForegroundColor White
Write-Host "  Туннель:    127.0.0.1:$LocalPort -> сервер (из config.ps1)" -ForegroundColor White
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
