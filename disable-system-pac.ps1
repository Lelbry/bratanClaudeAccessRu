# disable-system-pac.ps1
# Отключает системный PAC-скрипт (claude-proxy.pac), включённый через
# enable-system-pac.ps1. Не трогает Invisible Man / ProxyEnable.

$settingsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Remove-ItemProperty -Path $settingsKey -Name AutoConfigURL -ErrorAction SilentlyContinue

$sig = @"
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
Add-Type -MemberDefinition $sig -Namespace WinInet -Name NativeMethods -ErrorAction SilentlyContinue
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null

Write-Host "[pac] выключен" -ForegroundColor Green
Write-Host "Перезапусти Claude Desktop, чтобы изменения подхватились." -ForegroundColor Yellow
