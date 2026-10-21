# install-shell-shortcuts.ps1
# Регистрирует короткие функции в $PROFILE пользователя, чтобы скрипты
# LocalProxyForClaude можно было вызывать из ЛЮБОЙ папки PowerShell —
# без & и без полных путей в кавычках.
#
# После установки доступно (в любом новом PS окне):
#   tunnel-up        — поднять туннель
#   tunnel-down      — убить туннель
#   tunnel-status    — что происходит
#   tunnel-restart   — жёсткий перезапуск
#   pac-on / pac-off — включить/выключить PAC для Claude Desktop
#   whitelist-ip <ip> — добавить IP в whitelist fail2ban на сервере
#   claude-vpn       — запустить Claude Code через прокси (аналог claude-vpn.cmd)
#   cd-vpn           — перейти в папку проекта
#
# Переустановить (после переезда проекта или обновления списка):
#   .\install-shell-shortcuts.ps1
#
# Удалить:
#   .\install-shell-shortcuts.ps1 -Uninstall

param(
    [switch]$Uninstall
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$profilePath = $PROFILE.CurrentUserAllHosts   # ~/Documents/PowerShell/profile.ps1 — применяется и в консоли, и в ISE

$beginMarker = "# >>> LocalProxyForClaude shortcuts >>>"
$endMarker   = "# <<< LocalProxyForClaude shortcuts <<<"

# ---------------------------------------------------------------------------
# 1. Удалить старый блок из $PROFILE (если есть)
# ---------------------------------------------------------------------------
if (Test-Path $profilePath) {
    $current = Get-Content $profilePath -Raw
    # Регексп между маркерами (включая их самих и перевод строки после)
    $cleaned = [regex]::Replace(
        $current,
        [regex]::Escape($beginMarker) + '[\s\S]*?' + [regex]::Escape($endMarker) + '\r?\n?',
        ''
    )
    if ($cleaned -ne $current) {
        Set-Content -Path $profilePath -Value $cleaned.TrimEnd() -Encoding UTF8
        Write-Host "[profile] старый блок LocalProxyForClaude удалён" -ForegroundColor DarkGray
    }
}

if ($Uninstall) {
    Write-Host "[profile] удалено. Открой новое PS-окно (или . `$PROFILE), чтобы изменения вступили в силу." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# 2. Собрать новый блок
# ---------------------------------------------------------------------------
$block = @"
$beginMarker
# Автогенерация install-shell-shortcuts.ps1 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Папка проекта LocalProxyForClaude:
`$LPFC_ROOT = '$root'

function tunnel-up      { & "`$LPFC_ROOT\start-tunnel.ps1" @args }
function tunnel-down    { & "`$LPFC_ROOT\stop-tunnel.ps1" @args }
function tunnel-status  { & "`$LPFC_ROOT\status.ps1" @args }
function tunnel-restart { & "`$LPFC_ROOT\restart-proxy.ps1" @args }
function pac-on         { & "`$LPFC_ROOT\enable-system-pac.ps1" @args }
function pac-off        { & "`$LPFC_ROOT\disable-system-pac.ps1" @args }
function whitelist-ip   { & "`$LPFC_ROOT\whitelist-ip.ps1" @args }
function claude-vpn     { & "`$LPFC_ROOT\claude-vpn.cmd" @args }
function cd-vpn         { Set-Location -LiteralPath `$LPFC_ROOT }
$endMarker
"@

# ---------------------------------------------------------------------------
# 3. Создать $PROFILE если нет, дописать блок
# ---------------------------------------------------------------------------
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path $profilePath) {
    $existing = (Get-Content $profilePath -Raw).TrimEnd()
    $new = "$existing`r`n`r`n$block`r`n"
} else {
    $new = "$block`r`n"
}
Set-Content -Path $profilePath -Value $new -Encoding UTF8

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Shortcuts установлены в `$PROFILE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Файл: $profilePath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Доступные команды (после открытия нового PS окна):" -ForegroundColor Cyan
Write-Host "  tunnel-up         — поднять SSH-туннель" -ForegroundColor White
Write-Host "  tunnel-down       — убить туннель" -ForegroundColor White
Write-Host "  tunnel-status     — диагностика" -ForegroundColor White
Write-Host "  tunnel-restart    — жёсткий перезапуск" -ForegroundColor White
Write-Host "  pac-on / pac-off  — PAC для Claude Desktop" -ForegroundColor White
Write-Host "  whitelist-ip X    — IP в whitelist fail2ban" -ForegroundColor White
Write-Host "  claude-vpn        — Claude Code через прокси" -ForegroundColor White
Write-Host "  cd-vpn            — перейти в папку проекта" -ForegroundColor White
Write-Host ""
Write-Host "Чтобы применить в ТЕКУЩЕМ окне, не открывая новое:" -ForegroundColor Yellow
Write-Host "  . `$PROFILE" -ForegroundColor White
Write-Host ""
Write-Host "Если PowerShell откажется выполнять `$PROFILE из-за политики," -ForegroundColor DarkGray
Write-Host "один раз выполни (от обычного пользователя, не админа):" -ForegroundColor DarkGray
Write-Host "  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor White
Write-Host ""
Write-Host "Удалить shortcuts: .\install-shell-shortcuts.ps1 -Uninstall" -ForegroundColor DarkGray
