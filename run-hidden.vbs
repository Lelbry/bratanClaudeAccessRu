' run-hidden.vbs
' Универсальный лаунчер: запускает PowerShell-скрипт полностью скрыто (без консольного окна).
' Использование: wscript.exe run-hidden.vbs "path\to\script.ps1"
'
' wscript.exe (в отличие от cscript.exe) не создаёт консоль,
' а параметр 0 в .Run = vbHide — PowerShell тоже скрыт.

If WScript.Arguments.Count = 0 Then
    WScript.Echo "Usage: wscript.exe run-hidden.vbs <script.ps1>"
    WScript.Quit 1
End If

Dim scriptPath
scriptPath = WScript.Arguments(0)

Dim shell
Set shell = CreateObject("WScript.Shell")

' 0 = vbHide (полностью скрытое окно), True = ждать завершения
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, True
