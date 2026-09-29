@echo off
rem Runs smoke.ps1 on stock Windows PowerShell without changing the machine
rem execution policy. All arguments are forwarded to the script.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0smoke.ps1" %*
exit /b %ERRORLEVEL%
