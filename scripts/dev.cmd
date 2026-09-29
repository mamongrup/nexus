@echo off
rem Runs dev.ps1 on stock Windows PowerShell without changing the machine
rem execution policy. All arguments are forwarded to the script.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1" %*
exit /b %ERRORLEVEL%
