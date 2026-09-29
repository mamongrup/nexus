@echo off
rem Runs reservation-smoke.ps1 on stock Windows PowerShell without changing the
rem machine execution policy. All arguments are forwarded to the script.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0reservation-smoke.ps1" %*
exit /b %ERRORLEVEL%
