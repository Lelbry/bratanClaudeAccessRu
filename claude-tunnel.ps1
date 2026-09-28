# claude-tunnel.ps1
# Основной запускатор: поднимает туннель (если не поднят), проверяет прокси,
# задаёт HTTPS_PROXY только для этого процесса и запускает claude.
# Все аргументы пробрасываются в claude.

. "$PSScriptRoot\config.ps1"

# 1. Туннель
if (-not (LPFC-IsTunnelUp)) {
    & "$PSScriptRoot\start-tunnel.ps1"
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Host "[tunnel] already up on 127.0.0.1:$LPFC_LocalPort" -ForegroundColor Green
}

# 2. Проверка прокси
Write-Host "[proxy] testing..." -ForegroundColor Cyan
$code = & curl.exe -s -o NUL -w "%{http_code}" -x "http://127.0.0.1:$LPFC_LocalPort" "https://api.anthropic.com/" --max-time 10
if ($code -notmatch "^[234]") {
    Write-Host "[proxy] FAIL (HTTP=$code)" -ForegroundColor Red
    Write-Host "        Туннель есть, но tinyproxy не отвечает. Проверь сервер." -ForegroundColor Yellow
    exit 1
}
Write-Host "[proxy] OK (HTTP $code)" -ForegroundColor Green

# 3. Прокси-env только для этого процесса и наследников (claude)
$env:HTTPS_PROXY = "http://127.0.0.1:$LPFC_LocalPort"
$env:HTTP_PROXY  = "http://127.0.0.1:$LPFC_LocalPort"
$env:NO_PROXY    = "localhost,127.0.0.1"

# 4. Запуск claude с прокидыванием аргументов
Write-Host "[claude] launching (traffic via $LPFC_SshHost)" -ForegroundColor Green
& claude @args
