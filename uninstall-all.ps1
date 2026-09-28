# uninstall-all.ps1
# Полный откат всего LocalProxyForClaude:
#   1. Убить туннель
#   2. Снять scheduled task
#   3. Удалить tinyproxy с сервера
#   4. (опционально) удалить SSH-ключ из authorized_keys на сервере
#
# Саму папку LocalProxyForClaude не удаляет - удали руками.

. "$PSScriptRoot\config.ps1"

Write-Host "=== Rollback LocalProxyForClaude ===" -ForegroundColor Cyan
Write-Host ""

# 1. Autostart + туннель
Write-Host "[1/3] снимаем автозапуск и убиваем туннель" -ForegroundColor Cyan
& "$PSScriptRoot\uninstall-autostart.ps1"

# 2. Сервер: снести tinyproxy
Write-Host ""
Write-Host "[2/3] удаляем tinyproxy с сервера $LPFC_SshHost" -ForegroundColor Cyan
$serverScript = Get-Content "$PSScriptRoot\server\uninstall-tinyproxy.sh" -Raw
$serverScript | & ssh -i $LPFC_KeyPath -p $LPFC_SshPort "$LPFC_SshUser@$LPFC_SshHost" "bash -s"

# 3. authorized_keys на сервере
Write-Host ""
Write-Host "[3/3] удалить SSH-ключ из authorized_keys на сервере? [y/N]" -ForegroundColor Yellow
$answer = Read-Host
if ($answer -eq "y" -or $answer -eq "Y") {
    & ssh -i $LPFC_KeyPath -p $LPFC_SshPort "$LPFC_SshUser@$LPFC_SshHost" "sed -i '/claude-tunnel/d' ~/.ssh/authorized_keys && echo removed"
    Write-Host "  Ключ удалён с сервера. Теперь только парольный вход." -ForegroundColor Green
} else {
    Write-Host "  Ключ оставлен. Удалить вручную:" -ForegroundColor Yellow
    Write-Host "  ssh root@$LPFC_SshHost `"sed -i '/claude-tunnel/d' ~/.ssh/authorized_keys`""
}

Write-Host ""
Write-Host "DONE. Папку $LPFC_Root можно удалить вручную." -ForegroundColor Green
