# config.ps1
# ============================================================================
# Единая точка конфигурации LocalProxyForClaude.
# Все скрипты в этой папке дот-сорсят этот файл: `. $PSScriptRoot\config.ps1`
# Меняешь тут - меняется везде.
# ============================================================================

# --- Сервер ---
$Global:LPFC_SshHost    = "YOUR_SERVER_IP"    # <-- ЗАМЕНИ на IP своего сервера (setup.ps1 сделает это за тебя)
$Global:LPFC_SshUser    = "root"
$Global:LPFC_SshPort    = 22

# --- Туннель ---
$Global:LPFC_LocalPort  = 8888    # порт на этом ПК (127.0.0.1:LocalPort -> прокси на сервере)
$Global:LPFC_RemotePort = 8888   # порт tinyproxy на сервере (слушает 127.0.0.1)

# --- PAC-сервер ---
$Global:LPFC_PacPort    = 8899    # HTTP-сервер, раздающий PAC-файл (http://127.0.0.1:PacPort/proxy.pac)

# --- Chrome (для скриптов SwitchyOmega) ---
$Global:LPFC_ChromeProfile = ""   # папка профиля Chrome (setup.ps1 определит автоматически)

# --- Пути ---
$Global:LPFC_Root       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Global:LPFC_KeyPath    = Join-Path $Global:LPFC_Root "keys\id_ed25519_claude"
$Global:LPFC_LogFile    = Join-Path $Global:LPFC_Root "tunnel.log"

# --- Имена scheduled tasks для автозапуска ---
$Global:LPFC_TaskName      = "LocalProxyForClaude-Tunnel"
$Global:LPFC_PacTaskName   = "LocalProxyForClaude-PAC"

# --- Хелперы ---
function LPFC-IsTunnelUp {
    $conn = Get-NetTCPConnection -LocalPort $Global:LPFC_LocalPort -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -eq "127.0.0.1" }
    return [bool]$conn
}

function LPFC-GetTunnelPids {
    $pids = @()
    Get-Process ssh -ErrorAction SilentlyContinue | ForEach-Object {
        $cl = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cl -and $cl -like "*$($Global:LPFC_KeyPath)*") { $pids += $_.Id }
    }
    return $pids
}
