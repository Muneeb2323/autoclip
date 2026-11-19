@echo off
setlocal EnableExtensions
title PeakCut Setup ^& Launcher
cd /d "%~dp0"

echo ========================================================
echo                 PeakCut Auto-Launcher
echo ========================================================
echo.

:: 1. Reload PATH from registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%USERPATH%;%SYSPATH%;%PATH%;%~dp0bin"

:: 2. Check for Python
where python >nul 2>nul
if errorlevel 1 goto :install_python
goto :check_ffmpeg

:install_python
echo [!] Python is not found in PATH.
where winget >nul 2>nul
if errorlevel 1 goto :python_manual
echo [*] Installing Python 3.12 via winget...
winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%USERPATH%;%SYSPATH%;%PATH%"
where python >nul 2>nul
if not errorlevel 1 goto :check_ffmpeg

:python_manual
echo [ERROR] Python 3.10+ is required.
echo Please download and install Python from: https://www.python.org/downloads/
echo Note: Make sure to check "Add Python to PATH" during installation.
pause
exit /b 1

:check_ffmpeg
:: 3. Check for FFmpeg
where ffmpeg >nul 2>nul
if errorlevel 1 goto :install_ffmpeg
goto :check_venv

:install_ffmpeg
echo [!] FFmpeg is not found.
where winget >nul 2>nul
if errorlevel 1 goto :download_portable_ffmpeg
echo [*] Installing FFmpeg via winget...
winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%USERPATH%;%SYSPATH%;%PATH%"
where ffmpeg >nul 2>nul
if not errorlevel 1 goto :check_venv

:download_portable_ffmpeg
echo [*] Downloading portable FFmpeg...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Write-Host 'Downloading FFmpeg zip...'; Invoke-WebRequest -Uri 'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip' -OutFile 'ffmpeg.zip'; Expand-Archive ffmpeg.zip -DestinationPath 'ffmpeg_temp'; New-Item -ItemType Directory -Force -Path 'bin' | Out-Null; Copy-Item 'ffmpeg_temp\*\bin\*' 'bin\' -Force; Remove-Item 'ffmpeg.zip', 'ffmpeg_temp' -Recurse -Force; Write-Host 'FFmpeg downloaded successfully.' } catch { Write-Host 'Could not download FFmpeg automatically. Please install FFmpeg.' }"
set "PATH=%~dp0bin;%PATH%"

:check_venv
:: 4. Check / Create Virtual Environment (.venv)
if exist ".venv\Scripts\python.exe" goto :check_env
echo [*] Setting up Python virtual environment (.venv)...
python -m venv .venv
if errorlevel 1 (
    echo [ERROR] Failed to create virtual environment.
    pause
    exit /b 1
)
echo [*] Installing dependencies from requirements.txt...
.venv\Scripts\python.exe -m pip install --upgrade pip
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)

:check_env
:: 5. Ensure .env exists
if not exist ".env" (
    if exist ".env.example" (
        echo [*] Creating default .env from .env.example...
        copy ".env.example" ".env" >nul
    )
)

:: 6. Ensure speech-to-text model is downloaded
echo [*] Checking speech model...
.venv\Scripts\python.exe -m studio.fetch_model

:: 7. Launch PeakCut
echo.
echo ========================================================
echo           PeakCut is ready and starting up!
echo.
echo           Dashboard: http://127.0.0.1:8765
echo ========================================================
echo.

:: Automatically open dashboard in default browser after 2 seconds
start "" powershell -NoProfile -Command "Start-Sleep -Seconds 2; Start-Process 'http://127.0.0.1:8765'"

:: Run PeakCut server
.venv\Scripts\python.exe -m studio.server

pause
