@echo off
cd /d "%~dp0"
python auto_login.py
if %errorlevel% neq 0 (
    echo.
    echo 运行失败，请检查 Python 是否已安装并加入系统 PATH
    pause
)
