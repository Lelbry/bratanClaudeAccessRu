# uninstall-autostart.ps1
# Убирает scheduled tasks автозапуска (туннель + PAC-сервер).

. "$PSScriptRoot\config.ps1"

foreach ($name in @($LPFC_TaskName, $LPFC_PacTaskName)) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "[autostart] task '$name' не установлен" -ForegroundColor Yellow
        continue
    }
    Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $name -Confirm:$false
    Write-Host "[autostart] task '$name' удалён" -ForegroundColor Green
}

# Убить туннель если ещё висит
& "$PSScriptRoot\stop-tunnel.ps1"

# Убить pac-server если висит
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine -like '*pac-server*'
} | ForEach-Object {
    Write-Host "[pac-server] killing PID=$($_.Id)" -ForegroundColor Cyan
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
