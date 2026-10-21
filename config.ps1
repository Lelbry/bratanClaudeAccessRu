# config.ps1
# ============================================================================
# ОБЩИЙ конфиг LocalProxyForClaude — пушится в git, одинаков у всех.
#
# Личные данные (IP сервера, SSH-порт, Chrome-профиль) лежат в
#   private\server.ps1
# — этот файл в .gitignore и у каждого свой.
#
# Первая установка:
#   Copy-Item private\server.ps1.example private\server.ps1
#   notepad private\server.ps1    # впиши IP своего VPS
#
# Или запусти setup.ps1 — он спросит значения и создаст server.ps1 сам.
#
# Все скрипты в репе дот-сорсят этот файл: `. $PSScriptRoot\config.ps1`.
# ============================================================================

# --- Подгружаем личные данные из private\server.ps1 ---
$privateCfg = Join-Path $PSScriptRoot "private\server.ps1"
if (-not (Test-Path $privateCfg)) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  Нет private\server.ps1 — не найдены данные сервера." -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Сделай одно из двух:" -ForegroundColor Yellow
    Write-Host "  1. Запусти .\setup.ps1 (ответит на все вопросы интерактивно)"
    Write-Host "  2. Руками:"
    Write-Host "       Copy-Item private\server.ps1.example private\server.ps1"
    Write-Host "       notepad private\server.ps1"
    Write-Host ""
    throw "private\server.ps1 не найден"
}
. $privateCfg

# --- Туннель (одинаково у всех) ---
$Global:LPFC_LocalPort  = 8888    # порт на этом ПК (127.0.0.1:LocalPort -> прокси на сервере)
$Global:LPFC_RemotePort = 8888    # порт tinyproxy на сервере (слушает 127.0.0.1)

# --- PAC-сервер ---
$Global:LPFC_PacPort    = 8899    # HTTP-сервер, раздающий PAC-файл (http://127.0.0.1:PacPort/proxy.pac)

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

# Ждёт Enter в конце скрипта, но ТОЛЬКО если скрипт был запущен так, что
# консоль схлопнется после его выхода: двойной клик по .ps1, .cmd-обёртка
# из explorer, ярлык, scheduled task. Если скрипт вызван из уже открытой
# PS-сессии (из консоли, через функцию tunnel-xxx, dot-source, из ISE/VS Code),
# пауза пропускается — пользователь сам видит вывод и работает дальше.
#
# Вызывать в конце каждого основного скрипта, а также перед exit в ветках
# с ошибкой.
function LPFC-WaitIfLaunched {
    try {
        $parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction SilentlyContinue).ParentProcessId
        if (-not $parentPid) { return }
        $parent = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
        if (-not $parent) { return }
        # Интерактивные хосты, где пользователь продолжит работать — не паузимся.
        # Сюда входят все шеллы и терминалы, из которых обычно вызывают скрипты
        # вручную; окно у таких процессов не закроется после завершения скрипта.
        $interactiveHosts = @(
            'powershell','pwsh','powershell_ise',
            'cmd','conhost','OpenConsole',
            'WindowsTerminal','wt',
            'Code','devenv','rider64','idea64',
            'bash','sh','zsh','fish','git-bash',
            'node','claude'
        )
        if ($parent.ProcessName -in $interactiveHosts) { return }
        # Запущено через explorer / .cmd-обёртку из explorer / ярлык / scheduled task
        # — окно схлопнется, ждём, чтобы пользователь успел прочитать вывод
        Write-Host ""
        Write-Host "Нажми Enter чтобы закрыть окно..." -ForegroundColor DarkGray
        [void][System.Console]::ReadLine()
    } catch {
        # не роняем скрипт из-за паузы
    }
}

# Удобная обёртка: ждёт Enter (если нужно) и завершает скрипт с нужным кодом.
# Использовать вместо `exit N` в скриптах, которые пользователь может запускать
# двойным кликом.
function LPFC-Exit {
    param([int]$Code = 0)
    LPFC-WaitIfLaunched
    exit $Code
}
