# install-browser-extension.ps1
# Открывает Chrome Web Store в выбранном Chrome-профиле на странице SwitchyOmega 3 (ZeroOmega).
# Chrome-профиль берётся из config.ps1 ($LPFC_ChromeProfile).
# После установки настроить: .\configure-browser-extension.ps1

. "$PSScriptRoot\..\config.ps1"

$ChromeProfile = $LPFC_ChromeProfile   # из config.ps1
$ExtensionUrl  = "https://chromewebstore.google.com/detail/proxy-switchyomega-3-zero/pfnededegaaopdmhkdmcofjmoldfiped"

# Убедиться что туннель поднят - Web Store из РФ может быть недоступен напрямую.
# Но Chrome с ЭТИМ профилем сам через прокси не пойдёт (пока расширение не настроено).
# Так что открываем через уже настроенный browser-vpn (изолированный) - user установит
# оттуда, потом откроем нормальный Chrome для настройки.
#
# Проще: просто открыть в основном Chrome. Если Web Store откроется - хорошо.
# Если нет - откроем через browser-vpn.

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
    Write-Host "[browser] Chrome не найден" -ForegroundColor Red
    exit 1
}

Write-Host "[browser] открываю Chrome Web Store в профиле '$ChromeProfile'..." -ForegroundColor Cyan
Write-Host "         URL: $ExtensionUrl"
Write-Host ""
Write-Host "Дальше:" -ForegroundColor Yellow
Write-Host "  1. Нажми 'Установить' / 'Add to Chrome'"
Write-Host "  2. Подтверди установку расширения"
Write-Host "  3. Возвращайся сюда и запусти:  .\configure-browser-extension.ps1"
Write-Host ""

# ВАЖНО: PowerShell ArgumentList ломает пробел в имени профиля, Chrome тогда
# создаёт левый профиль. Пропускаем весь command line одной строкой с
# правильным экранированием кавычек через ProcessStartInfo.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName        = $chrome
$psi.Arguments       = "--profile-directory=`"$ChromeProfile`" `"$ExtensionUrl`""
$psi.UseShellExecute = $true
[System.Diagnostics.Process]::Start($psi) | Out-Null
