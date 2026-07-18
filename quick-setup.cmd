@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\quick-setup.ps1" %*
exit /b %ERRORLEVEL%
