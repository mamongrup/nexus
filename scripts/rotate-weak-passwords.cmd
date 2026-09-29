@echo off
rem Runs rotate-weak-passwords.ps1 on stock Windows PowerShell without changing
rem the machine execution policy. All arguments are forwarded to the script.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rotate-weak-passwords.ps1" %*
exit /b %ERRORLEVEL%
