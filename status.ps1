# status.ps1
# Диагностика: жив ли туннель, работает ли прокси, какой внешний IP видно.

. "$PSScriptRoot\config.ps1"

Write-Host "=== LocalProxyForClaude status ===" -ForegroundColor Cyan
Write-Host ""

# 1. Туннель
if (LPFC-IsTunnelUp) {
    $pids = LPFC-GetTunnelPids
    Write-Host "[tunnel]  UP    port 127.0.0.1:$LPFC_LocalPort  (ssh PID: $($pids -join ','))" -ForegroundColor Green
} else {
    Write-Host "[tunnel]  DOWN  port $LPFC_LocalPort не слушается" -ForegroundColor Red
    Write-Host "          Запусти: .\start-tunnel.ps1" -ForegroundColor Yellow
    exit 1
}

# 2. Прокси на сервере через туннель
$code = & curl.exe -s -o NUL -w "%{http_code}" -x "http://127.0.0.1:$LPFC_LocalPort" "https://api.anthropic.com/" --max-time 10
if ($code -match "^[234]") {
    Write-Host "[proxy]   OK    api.anthropic.com отвечает HTTP $code" -ForegroundColor Green
} else {
    Write-Host "[proxy]   FAIL  HTTP $code через прокси" -ForegroundColor Red
    exit 1
}

# 3. Внешний IP из-под прокси vs напрямую
$viaProxy = & curl.exe -s -x "http://127.0.0.1:$LPFC_LocalPort" "https://api.ipify.org" --max-time 10
$direct   = & curl.exe -s "https://api.ipify.org" --max-time 10
Write-Host "[ip]      via proxy: $viaProxy"
Write-Host "[ip]      direct:    $direct"
if ($viaProxy -eq $LPFC_SshHost) {
    Write-Host "          Прокси корректно отправляет трафик через $LPFC_SshHost" -ForegroundColor Green
} else {
    Write-Host "          Ожидался IP $LPFC_SshHost, но прокси вернул $viaProxy" -ForegroundColor Red
}

# 4. Scheduled task
$task = Get-ScheduledTask -TaskName $LPFC_TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "[autostart] enabled ($($task.State))" -ForegroundColor Green
} else {
    Write-Host "[autostart] not installed - .\install-autostart.ps1" -ForegroundColor Yellow
}
