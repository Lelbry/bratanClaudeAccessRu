# stop-tunnel.ps1
# Убивает SSH-туннель. Определяет свои процессы по пути к ключу.

. "$PSScriptRoot\config.ps1"

$pids = LPFC-GetTunnelPids
if ($pids.Count -eq 0) {
    Write-Host "[tunnel] not running" -ForegroundColor Yellow
    exit 0
}

foreach ($p in $pids) {
    Write-Host "[tunnel] killing PID=$p" -ForegroundColor Cyan
    Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 500

if (LPFC-IsTunnelUp) {
    Write-Host "[tunnel] port $LPFC_LocalPort still bound - что-то ещё висит" -ForegroundColor Red
    exit 1
}
Write-Host "[tunnel] stopped" -ForegroundColor Green
