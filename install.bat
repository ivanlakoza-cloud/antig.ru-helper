@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
echo.
echo   AntiG.ru Helper - Install v4.1
echo   ================================
echo.

:: ===== Source dir (where this .bat lives) =====
set "SRC_DIR=%~dp0"
set "SRC_MODULES=%SRC_DIR%src"
set "DIST_DIR=%SRC_DIR%dist"
set "BUNDLE=%DIST_DIR%\auto-retry.bundle.js"

:: ===== Verify source files exist =====
set "MODULES=config.js state.js status-badge.js fetch-retry.js audio-mute.js dom-clicker.js entry.js"
set "MISSING=0"
for %%m in (%MODULES%) do (
    if not exist "%SRC_MODULES%\%%m" (
        echo [ERROR] Source file missing: src\%%m
        set "MISSING=1"
    )
)
if "%MISSING%"=="1" (
    echo.
    echo   Source files not found. Ensure you are running
    echo   from the project root directory.
    pause
    exit /b 1
)

:: ===== Auto-detect Antigravity path =====
set "AG_DIR="
if exist "C:\Antigravity\resources\app\product.json" set "AG_DIR=C:\Antigravity\resources\app"
if not defined AG_DIR if exist "C:\Program Files\Antigravity\resources\app\product.json" set "AG_DIR=C:\Program Files\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\Antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\antigravity\resources\app"
if not defined AG_DIR if exist "%ProgramFiles(x86)%\Antigravity\resources\app\product.json" set "AG_DIR=%ProgramFiles(x86)%\Antigravity\resources\app"
if not defined AG_DIR if exist "%USERPROFILE%\Antigravity\resources\app\product.json" set "AG_DIR=%USERPROFILE%\Antigravity\resources\app"
if not defined AG_DIR if exist "%USERPROFILE%\AppData\Local\antigravity\resources\app\product.json" set "AG_DIR=%USERPROFILE%\AppData\Local\antigravity\resources\app"

if not defined AG_DIR (
    echo [INFO] Antigravity not found in standard paths.
    echo.
    echo   Enter path to Antigravity resources\app folder:
    echo   Example: C:\Users\YourName\AppData\Local\Programs\antigravity\resources\app
    echo.
    set /p "AG_DIR=Path: "
    if not exist "!AG_DIR!\product.json" (
        echo [ERROR] product.json not found at that path.
        pause
        exit /b 1
    )
)

echo [OK] Antigravity: %AG_DIR%

set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_FILE=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"

if not exist "%HTML_FILE%" (
    echo [ERROR] Workbench HTML not found: %HTML_FILE%
    pause
    exit /b 1
)

:: ===== Step 1: Build bundle =====
echo.
echo [1/4] Building bundle...
powershell -ExecutionPolicy Bypass -File "%SRC_DIR%build.ps1" -SrcDir "%SRC_MODULES%" -OutDir "%DIST_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)
if not exist "%BUNDLE%" (
    echo [ERROR] Bundle file not created!
    pause
    exit /b 1
)
echo       Bundle ready.

:: ===== Step 2: Copy bundle =====
echo [2/4] Copying to Antigravity...
powershell -ExecutionPolicy Bypass -Command "Copy-Item -Path '%BUNDLE%' -Destination '%RETRY_JS%' -Force"
if not exist "%RETRY_JS%" (
    echo [ERROR] Copy failed! Try running as Administrator.
    pause
    exit /b 1
)
echo       Done.

:: ===== Step 3: Inject script tag =====
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [3/4] Patch already in HTML. Updating bundle only.
    goto :update_checksum
)

echo [3/4] Installing patch...
copy /Y "%HTML_FILE%" "%HTML_FILE%.bak" >nul
copy /Y "%PRODUCT_JSON%" "%PRODUCT_JSON%.bak" >nul
echo       Backups created.

powershell -ExecutionPolicy Bypass -File "%SRC_DIR%inject.ps1" -HtmlFile "%HTML_FILE%"
if %errorlevel% neq 0 (
    echo [ERROR] Injection failed!
    copy /Y "%HTML_FILE%.bak" "%HTML_FILE%" >nul
    pause
    exit /b 1
)

:: Verify injection
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Injection verification failed!
    copy /Y "%HTML_FILE%.bak" "%HTML_FILE%" >nul
    pause
    exit /b 1
)

:update_checksum
:: ===== Step 4: Update checksum =====
echo [4/4] Updating checksum...
powershell -ExecutionPolicy Bypass -File "%SRC_DIR%checksum.ps1" -HtmlFile "%HTML_FILE%" -ProductJson "%PRODUCT_JSON%"
if %errorlevel% neq 0 (
    echo [ERROR] Checksum update failed!
    pause
    exit /b 1
)

:: ===== Verify =====
echo.
echo   Verifying installation...
set "VERIFY_OK=1"
if not exist "%RETRY_JS%" (
    echo   [FAIL] auto-retry.js not found in workbench
    set "VERIFY_OK=0"
)
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo   [FAIL] Script tag not in HTML
    set "VERIFY_OK=0"
)
if "%VERIFY_OK%"=="1" (
    echo   [OK] All checks passed!
)

echo.
echo   ================================
echo    Installation complete!
echo    Restart Antigravity to activate.
echo   ================================
echo.
echo   To uninstall: run uninstall.bat
echo.
pause
