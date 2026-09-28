# pac-server.ps1
# Мини HTTP-сервер, раздающий claude-proxy.pac по http://127.0.0.1:$LPFC_PacPort/proxy.pac
#
# Зачем: Chromium (на нём построены Claude Desktop и другие Electron-
# приложения) из соображений безопасности блокирует чтение PAC-скрипта
# по file:// в своём network service (сетевой процесс в песочнице не
# имеет доступа к файловой системе). Поэтому системный PAC обязан быть
# HTTP-адресом, а не file:///... .
#
# Держать в фоне постоянно, как и SSH-туннель (см. install-autostart.ps1).

. "$PSScriptRoot\config.ps1"

$PacPort = $LPFC_PacPort        # из config.ps1
$PacFile = Join-Path $PSScriptRoot "claude-proxy.pac"

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [pac-server] $msg"
    Write-Host $line
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$PacPort/")
$listener.Start()
Log "listening on http://127.0.0.1:$PacPort/proxy.pac"

# Заставляем все приложения перечитать прокси-настройки из реестра.
# Без этого Claude Desktop (и другие Electron-приложения), стартовавшие
# ДО нас, закешируют "нет прокси" и не подхватят PAC до ручного рефреша.
$sig = @"
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
Add-Type -MemberDefinition $sig -Namespace WinInet -Name NativeMethods -ErrorAction SilentlyContinue
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null  # SETTINGS_CHANGED
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null  # REFRESH
Log "proxy settings refreshed (InternetSetOption)"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        try {
            # Подставляем порт из config.ps1 — PAC-файл может содержать любой порт,
            # но раздаём всегда с актуальным значением $LPFC_LocalPort.
            $pacRaw = Get-Content -Raw -Path $PacFile
            $pacRaw = $pacRaw -replace 'PROXY 127\.0\.0\.1:\d+', "PROXY 127.0.0.1:$LPFC_LocalPort"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($pacRaw)
            $response.ContentType = "application/x-ns-proxy-autoconfig"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } finally {
            $response.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
}
