@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0login.ps1"
if %errorlevel% neq 0 (
    echo.
    echo 运行失败，请检查 login.log
    pause
)
