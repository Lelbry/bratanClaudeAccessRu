# install-autostart.ps1
#
# ⚠️⚠️⚠️ В РАЗРАБОТКЕ — работает НЕНАДЁЖНО ⚠️⚠️⚠️
#
# Этот скрипт регистрирует Windows Scheduled Tasks для автозапуска
# туннеля и PAC-сервера при логоне. На практике:
#   - процессы падают с 0xC000013A (CTRL+C при закрытии консоли)
#   - после перезагрузки часто не стартуют вообще
#   - VBS-обёртка (run-hidden.vbs) помогает частично, не полностью
#
# Пока — запускай туннель и PAC-сервер руками:
#   .\start-tunnel.ps1
#   .\enable-system-pac.ps1    (поднимет pac-server.ps1 если нужно)
#
# Или через ярлык в shell:startup (Win+R → shell:startup) — положить
# туда ярлык на restart-proxy.ps1.
#
# Код ниже оставлен для экспериментов / будущей починки.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  install-autostart.ps1 — в разработке" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Автозапуск через Windows Scheduled Tasks работает ненадёжно." -ForegroundColor Gray
Write-Host "Пока запускай туннель вручную: .\start-tunnel.ps1" -ForegroundColor Gray
Write-Host "Или положи ярлык на restart-proxy.ps1 в shell:startup." -ForegroundColor Gray
Write-Host ""
$cont = Read-Host "Всё равно попробовать установить scheduled tasks? [y/N]"
if ($cont -ne "y" -and $cont -ne "Y") {
    exit 0
}

. "$PSScriptRoot\config.ps1"

# --- Общее: VBS-обёртка для скрытого запуска ---
# wscript.exe + run-hidden.vbs запускает PowerShell без консольного окна.
# powershell.exe -WindowStyle Hidden с Task Scheduler ненадёжен —
# создаёт видимое консольное окно, которое при закрытии убивает процесс (CTRL+C).
$vbsLauncher = Join-Path $LPFC_Root "run-hidden.vbs"

# --- Task 1: SSH tunnel daemon ---
$daemonPath = Join-Path $LPFC_Root "tunnel-daemon.ps1"

$action1 = New-ScheduledTaskAction `
    -Execute "wscript.exe" `
    -Argument "`"$vbsLauncher`" `"$daemonPath`""

$trigger1 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger1.Delay = "PT30S"

$settings1 = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable

Unregister-ScheduledTask -TaskName $LPFC_TaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $LPFC_TaskName `
    -Action $action1 `
    -Trigger $trigger1 `
    -Settings $settings1 `
    -RunLevel Limited `
    -Description "LocalProxyForClaude: SSH tunnel to $LPFC_SshHost, keeps 127.0.0.1:$LPFC_LocalPort alive."

Write-Host "[autostart] task '$LPFC_TaskName' installed" -ForegroundColor Green

# --- Task 2: PAC server ---
$pacPath = Join-Path $LPFC_Root "pac-server.ps1"

$action2 = New-ScheduledTaskAction `
    -Execute "wscript.exe" `
    -Argument "`"$vbsLauncher`" `"$pacPath`""

$trigger2 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger2.Delay = "PT30S"

$settings2 = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable

Unregister-ScheduledTask -TaskName $LPFC_PacTaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $LPFC_PacTaskName `
    -Action $action2 `
    -Trigger $trigger2 `
    -Settings $settings2 `
    -RunLevel Limited `
    -Description "LocalProxyForClaude: HTTP server for PAC file on 127.0.0.1:$LPFC_PacPort."

Write-Host "[autostart] task '$LPFC_PacTaskName' installed" -ForegroundColor Green

Write-Host ""
Write-Host "Обе задачи стартуют через 30 сек после логона (скрыто, без консольных окон)." -ForegroundColor Cyan
Write-Host "Перезапускаются каждую минуту при сбое." -ForegroundColor Cyan
Write-Host ""
Write-Host "Запустить прямо сейчас (без релогина):" -ForegroundColor Cyan
Write-Host "  Start-ScheduledTask -TaskName '$LPFC_TaskName'"
Write-Host "  Start-ScheduledTask -TaskName '$LPFC_PacTaskName'"
