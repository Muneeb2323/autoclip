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

:: 2. Find working Python (avoids Microsoft Store 0-byte dummy stub)
set "PY_CMD="

:: Check if standard python actually executes code
python -c "import sys; exit(0)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto :python_found
)

:: Check if Windows Python launcher (py.exe) works
py -3 -c "import sys; exit(0)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py -3"
    goto :python_found
)

:: Check common Python installation paths directly
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    set "PY_CMD=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
    goto :python_found
)
if exist "%ProgramFiles%\Python312\python.exe" (
    set "PY_CMD=%ProgramFiles%\Python312\python.exe"
    set "PATH=%ProgramFiles%\Python312;%ProgramFiles%\Python312\Scripts;%PATH%"
    goto :python_found
)
if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set "PY_CMD=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
    goto :python_found
)
if exist "%ProgramFiles%\Python311\python.exe" (
    set "PY_CMD=%ProgramFiles%\Python311\python.exe"
    set "PATH=%ProgramFiles%\Python311;%ProgramFiles%\Python311\Scripts;%PATH%"
    goto :python_found
)

:: If not found, attempt install via winget
goto :install_python

:install_python
echo [!] Python is not installed or intercepted by Microsoft Store shortcut.
where winget >nul 2>nul
if errorlevel 1 goto :python_manual

echo [*] Installing official Python 3.12 via winget...
winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements

:: Reload PATH and check standard locations
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%USERPATH%;%SYSPATH%;%PATH%"

if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    set "PY_CMD=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
    goto :python_found
)
if exist "%ProgramFiles%\Python312\python.exe" (
    set "PY_CMD=%ProgramFiles%\Python312\python.exe"
    set "PATH=%ProgramFiles%\Python312;%ProgramFiles%\Python312\Scripts;%PATH%"
    goto :python_found
)
py -3 -c "import sys; exit(0)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py -3"
    goto :python_found
)
python -c "import sys; exit(0)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto :python_found
)

:python_manual
echo.
echo ========================================================
echo [ERROR] Python 3.10+ is required.
echo.
echo 1. Download official Python from: https://www.python.org/downloads/
echo 2. IMPORTANT: Check the box "Add Python to PATH" during install!
echo 3. Also disable the Windows Store dummy shortcut in:
echo    Settings ^> Apps ^> Advanced app settings ^> App execution aliases
echo    (Turn OFF "App Installer - python.exe" and "python3.exe")
echo ========================================================
pause
exit /b 1

:python_found
:: 3. Check for FFmpeg
ffmpeg -version >nul 2>&1
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
ffmpeg -version >nul 2>&1
if not errorlevel 1 goto :check_venv

:download_portable_ffmpeg
echo [*] Downloading portable FFmpeg...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Write-Host 'Downloading FFmpeg zip...'; Invoke-WebRequest -Uri 'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip' -OutFile 'ffmpeg.zip'; Expand-Archive ffmpeg.zip -DestinationPath 'ffmpeg_temp'; New-Item -ItemType Directory -Force -Path 'bin' | Out-Null; Copy-Item 'ffmpeg_temp\*\bin\*' 'bin\' -Force; Remove-Item 'ffmpeg.zip', 'ffmpeg_temp' -Recurse -Force; Write-Host 'FFmpeg downloaded successfully.' } catch { Write-Host 'Could not download FFmpeg automatically. Please install FFmpeg.' }"
set "PATH=%~dp0bin;%PATH%"

:check_venv
:: 4. Check / Create Virtual Environment (.venv)
if exist ".venv\Scripts\python.exe" goto :install_deps
echo [*] Setting up Python virtual environment (.venv)...
%PY_CMD% -m venv .venv
if errorlevel 1 (
    echo [ERROR] Failed to create virtual environment using %PY_CMD%.
    pause
    exit /b 1
)

:install_deps
echo [*] Checking dependencies from requirements.txt...
.venv\Scripts\python.exe -m pip install --prefer-binary -r requirements.txt
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
