@echo off
rem Runs setup.ps1 on stock Windows PowerShell without changing the machine
rem execution policy. All arguments are forwarded to the script.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
exit /b %ERRORLEVEL%
