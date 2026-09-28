# start-tunnel.ps1
# Поднимает SSH-туннель до сервера (single-shot).
# Если туннель уже поднят - ничего не делает.

. "$PSScriptRoot\config.ps1"

if (LPFC-IsTunnelUp) {
    Write-Host "[tunnel] already up on 127.0.0.1:$LPFC_LocalPort" -ForegroundColor Green
    exit 0
}

Write-Host "[tunnel] starting: 127.0.0.1:${LPFC_LocalPort} -> ${LPFC_SshHost}:${LPFC_RemotePort}" -ForegroundColor Cyan

Start-Process -WindowStyle Hidden -FilePath "ssh" -ArgumentList @(
    "-i", $LPFC_KeyPath,
    "-N",
    "-o", "ServerAliveInterval=30",
    "-o", "ServerAliveCountMax=3",
    "-o", "ExitOnForwardFailure=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "PasswordAuthentication=no",
    "-o", "BatchMode=yes",
    "-p", $LPFC_SshPort,
    "-L", "127.0.0.1:${LPFC_LocalPort}:127.0.0.1:${LPFC_RemotePort}",
    "$LPFC_SshUser@$LPFC_SshHost"
)

# Ждём открытия порта до 5 секунд
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if (LPFC-IsTunnelUp) { break }
}

if (LPFC-IsTunnelUp) {
    Write-Host "[tunnel] UP" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[tunnel] FAILED to open port $LPFC_LocalPort" -ForegroundColor Red
    Write-Host "  Возможные причины:" -ForegroundColor Yellow
    Write-Host "  - сервер $LPFC_SshHost недоступен (проверь ping)"
    Write-Host "  - SSH-ключ $LPFC_KeyPath битый или не установлен на сервере"
    Write-Host "  - порт $LPFC_LocalPort занят другим процессом (netstat -ano | findstr $LPFC_LocalPort)"
    exit 1
}
