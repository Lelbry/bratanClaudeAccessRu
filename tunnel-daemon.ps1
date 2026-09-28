# tunnel-daemon.ps1
# Бесконечный цикл: держит SSH-туннель поднятым, перезапускает при обрыве.
# Используется scheduled task-ом install-autostart.ps1.
# Пишет лог в config: $LPFC_LogFile.

. "$PSScriptRoot\config.ps1"

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Write-Host $line
    Add-Content -Path $LPFC_LogFile -Value $line -Encoding UTF8
}

Log "daemon start (host=$LPFC_SshHost port=$LPFC_LocalPort)"

while ($true) {
    # Ждём сеть — при старте Windows она может быть ещё не готова
    while (-not (Test-Connection -ComputerName $LPFC_SshHost -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Log "waiting for network ($LPFC_SshHost unreachable)..."
        Start-Sleep -Seconds 5
    }

    # Фоновый job: как только порт поднимется — рефрешим прокси-настройки Windows,
    # чтобы Claude Desktop (Electron) подхватил PAC без ручного вмешательства.
    Start-Job -ScriptBlock {
        param($port, $logFile)
        for ($i = 0; $i -lt 30; $i++) {
            $up = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
                Where-Object { $_.LocalAddress -eq "127.0.0.1" }
            if ($up) {
                $sig = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h, int o, IntPtr b, int l);'
                Add-Type -MemberDefinition $sig -Namespace WinInet -Name R -ErrorAction SilentlyContinue
                [WinInet.R]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
                [WinInet.R]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
                $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') tunnel UP on port $port, proxy refreshed"
                Add-Content -Path $logFile -Value $line -Encoding UTF8
                return
            }
            Start-Sleep -Seconds 1
        }
    } -ArgumentList $LPFC_LocalPort, $LPFC_LogFile | Out-Null

    # ssh -N в foreground: скрипт блокируется здесь пока туннель жив
    & ssh `
        -i $LPFC_KeyPath `
        -N `
        -o ServerAliveInterval=30 `
        -o ServerAliveCountMax=3 `
        -o ExitOnForwardFailure=yes `
        -o StrictHostKeyChecking=accept-new `
        -o PasswordAuthentication=no `
        -o BatchMode=yes `
        -p $LPFC_SshPort `
        -L "127.0.0.1:${LPFC_LocalPort}:127.0.0.1:${LPFC_RemotePort}" `
        "$LPFC_SshUser@$LPFC_SshHost"

    Log "ssh exited (code=$LASTEXITCODE), reconnect in 5s"
    Start-Sleep -Seconds 5
}
