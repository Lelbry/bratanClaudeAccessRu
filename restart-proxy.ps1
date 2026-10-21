# restart-proxy.ps1
# Жёсткий перезапуск туннеля и PAC-сервера. Использовать если после
# включения/выключения Warp (или другого VPN) Claude Desktop завис —
# это значит, что процессы ssh/pac-server могли упасть и не поднялись.
#
# Работает без scheduled tasks: убивает процессы напрямую и запускает заново.

. "$PSScriptRoot\config.ps1"

Write-Host "[restart] останавливаю туннель и PAC-сервер..." -ForegroundColor Cyan

# 1. Убить SSH-туннель (ssh-процессы с нашим ключом в cmdline)
$sshPids = LPFC-GetTunnelPids
foreach ($p in $sshPids) {
    Write-Host "  killing ssh PID=$p" -ForegroundColor DarkGray
    Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
}

# 2. Убить pac-server.ps1 если крутится
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'pac-server\.ps1' } |
    ForEach-Object {
        Write-Host "  killing pac-server PID=$($_.ProcessId)" -ForegroundColor DarkGray
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

Start-Sleep -Seconds 1

# 3. Поднять туннель заново
Write-Host "[restart] запускаю туннель..." -ForegroundColor Cyan
& "$PSScriptRoot\start-tunnel.ps1"

# 4. Поднять PAC-сервер если его порт свободен (значит нужен — он был запущен)
#    (если PAC не был включён — enable-system-pac.ps1 его сам запустит при необходимости)
$pacListening = Get-NetTCPConnection -LocalPort $LPFC_PacPort -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -eq "127.0.0.1" }
if (-not $pacListening) {
    Write-Host "[restart] запускаю PAC-сервер..." -ForegroundColor Cyan
    $pacScript = Join-Path $PSScriptRoot "pac-server.ps1"
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$pacScript`""
    )
    Start-Sleep -Seconds 1
}

Start-Sleep -Seconds 1

& "$PSScriptRoot\status.ps1"
