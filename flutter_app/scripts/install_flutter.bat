@echo off
echo ========================================
echo Flutter Installation Helper
echo ========================================
echo.

echo Checking if Chocolatey is installed...
where choco >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Chocolatey is installed!
    echo.
    echo Installing Flutter via Chocolatey...
    choco install flutter -y
    echo.
    echo Flutter installed! Please close and reopen this window.
    pause
) else (
    echo Chocolatey is NOT installed.
    echo.
    echo Please install Chocolatey first by running PowerShell as Administrator and executing:
    echo.
    echo Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    echo.
    echo Or download Flutter manually from:
    echo https://docs.flutter.dev/get-started/install/windows
    echo.
    pause
)
