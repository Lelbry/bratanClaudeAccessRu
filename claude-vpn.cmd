@echo off
REM claude-vpn.cmd - двойной клик или из cmd: запускает claude через SSH-туннель.
REM Все аргументы командной строки пробрасываются в claude.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-tunnel.ps1" %*
