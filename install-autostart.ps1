# install-autostart.ps1
# Регистрирует scheduled tasks:
#   1. tunnel-daemon.ps1 — SSH-туннель до сервера (автореконнект)
#   2. pac-server.ps1    — HTTP-сервер, раздающий PAC-файл для Claude Desktop
# Обе задачи стартуют при входе в Windows и перезапускаются при сбое.
# Запускать НЕ обязательно от админа — tasks ставятся в пользовательский scope.

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
