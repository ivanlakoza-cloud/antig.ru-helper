@echo off
setlocal enabledelayedexpansion
echo ============================================
echo   Antigravity Auto-Retry UNPATCH
echo ============================================
echo.

set "SRC_DIR=%~dp0"

:: ===== Auto-detect Antigravity path =====
set "AG_DIR="
if exist "C:\Antigravity\resources\app\product.json" set "AG_DIR=C:\Antigravity\resources\app"
if not defined AG_DIR if exist "C:\Program Files\Antigravity\resources\app\product.json" set "AG_DIR=C:\Program Files\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\Antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\antigravity\resources\app"

if not defined AG_DIR (
    echo [ERROR] Antigravity not found.
    set /p "AG_DIR=Enter path to resources\app: "
)

set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_FILE=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"

:: Check if patched
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Patch not detected. Nothing to unpatch.
    pause
    exit /b 0
)

echo [1/3] Removing auto-retry.js from HTML...
powershell -ExecutionPolicy Bypass -File "%SRC_DIR%remove-inject.ps1" -HtmlFile "%HTML_FILE%"

:: Verify
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [WARNING] Could not fully clean HTML.
    echo Try restoring backup: copy "%HTML_FILE%.bak" "%HTML_FILE%"
    pause
    exit /b 1
)

echo [2/3] Updating checksum in product.json...
powershell -ExecutionPolicy Bypass -File "%SRC_DIR%checksum.ps1" -HtmlFile "%HTML_FILE%" -ProductJson "%PRODUCT_JSON%"

echo [3/3] Removing auto-retry.js from Antigravity...
if exist "%RETRY_JS%" (
    del "%RETRY_JS%"
    echo       auto-retry.js removed.
) else (
    echo       auto-retry.js already absent.
)

echo.
echo ============================================
echo   Unpatch complete!
echo   Restart Antigravity.
echo ============================================
echo.
pause
