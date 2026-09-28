# restart-proxy.ps1
# Жёсткий перезапуск туннеля и PAC-сервера. Использовать если после
# включения/выключения Warp (или другого VPN) Claude Desktop завис —
# это значит, что scheduled tasks были убиты (например, вручную через
# Task Manager) и не поднялись сами.

. "$PSScriptRoot\config.ps1"

Write-Host "[restart] останавливаю задачи..." -ForegroundColor Cyan
Stop-ScheduledTask -TaskName $LPFC_TaskName -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskName $LPFC_PacTaskName -ErrorAction SilentlyContinue

# На всякий случай убить осиротевшие ssh/pac-server процессы, которые
# могли пережить убийство родительской задачи.
Get-Process ssh -ErrorAction SilentlyContinue | ForEach-Object {
    $cl = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cl -and $cl -like "*$LPFC_KeyPath*") { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'pac-server\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Seconds 1

Write-Host "[restart] запускаю задачи..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $LPFC_TaskName
Start-ScheduledTask -TaskName $LPFC_PacTaskName

Start-Sleep -Seconds 3

& "$PSScriptRoot\status.ps1"
