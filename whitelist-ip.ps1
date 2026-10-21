# whitelist-ip.ps1
# Добавляет IP в whitelist fail2ban на сервере.
# Правит /etc/fail2ban/jail.local, перезапускает fail2ban, разбанивает IP если был забанен.
#
# Использование:
#   .\whitelist-ip.ps1 1.2.3.4
#   .\whitelist-ip.ps1 1.2.3.4 -Reason "ноут в поездке"

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Ip,

    [Parameter(Position = 1)]
    [string]$Reason = ""
)

# Чтобы русский из stdout ssh не превращался в кракозябры в консоли
[Console]::OutputEncoding = [Text.Encoding]::UTF8

. "$PSScriptRoot\config.ps1"

# --- Валидация IPv4 ---
if ($Ip -notmatch '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$') {
    Write-Host "[whitelist] не похоже на IPv4: $Ip" -ForegroundColor Red
    LPFC-Exit 1
}
foreach ($octet in $matches[1..4]) {
    if ([int]$octet -gt 255) {
        Write-Host "[whitelist] октет $octet > 255: $Ip" -ForegroundColor Red
        LPFC-Exit 1
    }
}

Write-Host "[whitelist] $Ip -> fail2ban ignoreip на $LPFC_SshHost" -ForegroundColor Cyan
if ($Reason) { Write-Host "            причина: $Reason" -ForegroundColor DarkGray }

# --- Удалённая команда ---
# Экранируем точки в IP для grep (regex-safe) и работаем в sed.
$ipRe = $Ip -replace '\.', '\.'
$reasonComment = if ($Reason) { " ($Reason)" } else { "" }

$remote = @"
set -e
JAIL=/etc/fail2ban/jail.local

# 1. Файл есть и корректный? (минимум строка ignoreip)
if ! grep -q '^ignoreip' "`$JAIL" 2>/dev/null; then
    echo '[err] /etc/fail2ban/jail.local либо отсутствует, либо без строки ignoreip'
    echo '      создай нормальный jail.local руками'
    exit 2
fi

# 2. IP уже в whitelist?
if grep -qE "^ignoreip\s*=.*(\s|=)$ipRe(\s|$)" "`$JAIL"; then
    echo '[skip] уже в whitelist'
else
    sed -i -E "s|^(ignoreip\s*=.*)|\1 $Ip|" "`$JAIL"
    echo '[add]  добавлен в ignoreip'
    systemctl restart fail2ban
    sleep 1
    echo '[ok]   fail2ban перезапущен'
fi

# 3. Если IP сейчас забанен — разбанить
if fail2ban-client status sshd | grep -q "$ipRe"; then
    fail2ban-client set sshd unbanip $Ip && echo '[unban] был забанен, разбанил'
fi

echo
echo '--- Current ignoreip ---'
fail2ban-client get sshd ignoreip
echo
echo '--- Current bans ---'
fail2ban-client status sshd | grep -iE 'currently banned|banned IP'
"@

# --- Выполняем через SSH ---
# PowerShell 5.1 при pipe в native-команду может добавлять BOM и ломать
# $OutputEncoding (ASCII по умолчанию). Поэтому гоним скрипт через base64:
# это обходит все вопросы с кодировкой, переводами строк и экранированием.
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))
$remoteCmd = "echo $b64 | base64 -d | bash"

$result = & ssh -i $LPFC_KeyPath -p $LPFC_SshPort "$LPFC_SshUser@$LPFC_SshHost" $remoteCmd 2>&1
$exit = $LASTEXITCODE

$result | ForEach-Object { Write-Host $_ }
if ($exit -ne 0) {
    Write-Host "[whitelist] SSH вернул код $exit" -ForegroundColor Red
    LPFC-Exit $exit
}
Write-Host "[whitelist] готово" -ForegroundColor Green
LPFC-WaitIfLaunched
