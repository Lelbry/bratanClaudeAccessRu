# enable-system-pac.ps1
# Включает системный PAC-скрипт Windows (claude-proxy.pac), чтобы
# Claude Desktop (Store-приложение, без exe) и другие программы,
# читающие системный прокси, шли через наш туннель только для
# доменов claude.ai / anthropic.com. Остальной интернет не трогается.
#
# Не пересекается с ProxyEnable (которым управляет Invisible Man) —
# PAC работает независимо от него.

. "$PSScriptRoot\config.ps1"

if (-not (LPFC-IsTunnelUp)) {
    Write-Host "[tunnel] не поднят - сначала .\start-tunnel.ps1" -ForegroundColor Red
    exit 1
}

$pacPath = Join-Path $PSScriptRoot "claude-proxy.pac"
if (-not (Test-Path $pacPath)) {
    Write-Host "[pac] файл не найден: $pacPath" -ForegroundColor Red
    exit 1
}

# ВАЖНО: обязательно http://, не file:// - Chromium (Claude Desktop и
# другие Electron-приложения) блокирует чтение PAC по file:// в своём
# сетевом процессе (песочница). Раздаём файл через pac-server.ps1.
$pacPort = $LPFC_PacPort   # из config.ps1
$conn = Get-NetTCPConnection -LocalPort $pacPort -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -eq "127.0.0.1" }
if (-not $conn) {
    Write-Host "[pac-server] не запущен на порту $pacPort - запускаю..." -ForegroundColor Yellow
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "pac-server.ps1")
    )
    Start-Sleep -Seconds 1
}

$pacUrl = "http://127.0.0.1:$pacPort/proxy.pac"

$settingsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $settingsKey -Name AutoConfigURL -Value $pacUrl

# Просим Windows перечитать настройки прокси немедленно (иначе применится
# не сразу / только для новых процессов после перезапуска explorer).
$sig = @"
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
Add-Type -MemberDefinition $sig -Namespace WinInet -Name NativeMethods -ErrorAction SilentlyContinue
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null  # INTERNET_OPTION_SETTINGS_CHANGED
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null  # INTERNET_OPTION_REFRESH

Write-Host "[pac] включён: $pacUrl" -ForegroundColor Green
Write-Host "      claude.ai / anthropic.com теперь идут через 127.0.0.1:$LPFC_LocalPort у ЛЮБОГО приложения на этом ПК" -ForegroundColor Green
Write-Host "      (включая десктоп-версию Claude из Microsoft Store)" -ForegroundColor Green
Write-Host ""
Write-Host "Перезапусти Claude Desktop, чтобы изменения подхватились." -ForegroundColor Yellow
