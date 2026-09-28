# configure-browser-extension.ps1
# Открывает страницу настроек SwitchyOmega 3 (ZeroOmega) в выбранном Chrome-профиле
# и печатает пошаговую инструкцию как импортировать наш готовый конфиг.
# Chrome-профиль берётся из config.ps1 ($LPFC_ChromeProfile).

. "$PSScriptRoot\..\config.ps1"

$ChromeProfile   = $LPFC_ChromeProfile   # из config.ps1
$ExtensionId     = "pfnededegaaopdmhkdmcofjmoldfiped"
$OptionsUrl      = "chrome-extension://$ExtensionId/options.html#!/import"
# JSON лежит рядом со скриптом (в подпапке google chrome extention)
$ConfigFilePath  = Join-Path $PSScriptRoot "browser-extension-config.json"

# Проверить что расширение установлено (косвенно: папка есть?)
$extPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\$ChromeProfile\Extensions\$ExtensionId"
if (-not (Test-Path $extPath)) {
    Write-Host "[!] SwitchyOmega ещё не установлен в профиле '$ChromeProfile'" -ForegroundColor Yellow
    Write-Host "    Сначала запусти: .\install-browser-extension.cmd" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Если только что установил и Chrome не успел зарегистрировать -" -ForegroundColor Gray
    Write-Host "перезапусти Chrome-профиль и запусти этот скрипт снова." -ForegroundColor Gray
    exit 1
}

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

# Перегенерировать JSON с актуальным портом из config.ps1,
# чтобы при смене порта не нужно было править JSON вручную.
$jsonRaw = Get-Content $ConfigFilePath -Raw
$jsonRaw = $jsonRaw -replace '"port":\s*\d+', "`"port`": $LPFC_LocalPort"
Set-Content -Path $ConfigFilePath -Value $jsonRaw -Encoding UTF8

# Копируем файл в буфер обмена для удобства (можно сразу вставить)
Set-Clipboard -Value $jsonRaw

Write-Host "=== Настройка SwitchyOmega ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Открываю страницу Import в SwitchyOmega, профиль $ChromeProfile." -ForegroundColor Green
Write-Host ""
Write-Host "Инструкция (2 варианта):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  === Вариант A - импорт файла (проще) ==="
Write-Host "  1. Найди раздел 'Restore from file' или 'Import from file'"
Write-Host "  2. Выбери файл:"
Write-Host "     $ConfigFilePath" -ForegroundColor White
Write-Host "  3. Подтверди перезапись (Yes / OK)"
Write-Host ""
Write-Host "  === Вариант B - вставить из буфера ==="
Write-Host "  Содержимое конфига уже в буфере обмена!"
Write-Host "  1. Найди раздел 'Restore from text' (если есть) - вставь Ctrl+V"
Write-Host "  Иначе используй вариант A."
Write-Host ""
Write-Host "После импорта:" -ForegroundColor Yellow
Write-Host "  - В тулбаре Chrome появится иконка SwitchyOmega (тёмный кружок с O)"
Write-Host "  - Клик по ней -> выбор режима:"
Write-Host "    * [Direct]       - без прокси (встроенный, обычная работа)"
Write-Host "    * LelbryVPN      - весь Chrome через наш сервер"
Write-Host "    * auto switch    - только AI-сервисы и YouTube через сервер, остальное напрямую"
Write-Host ""
Write-Host "Рекомендую 'auto switch' - поставил и забыл." -ForegroundColor Green
Write-Host ""
Write-Host "Проверка что работает:"
Write-Host "  1. Убедись что туннель поднят:  .\status.ps1"
Write-Host "  2. В Chrome (профиль $ChromeProfile) открой https://api.ipify.org"
Write-Host "     - При режиме [Direct]    -> твой реальный IP"
Write-Host "     - При режиме LelbryVPN   -> $LPFC_SshHost"
Write-Host ""

# Через ProcessStartInfo с ручной строкой — иначе PowerShell ломает пробел в имени профиля
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName        = $chrome
$psi.Arguments       = "--profile-directory=`"$ChromeProfile`" `"$OptionsUrl`""
$psi.UseShellExecute = $true
[System.Diagnostics.Process]::Start($psi) | Out-Null
