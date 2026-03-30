@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
echo.
echo   AntiG.ru Helper - Install v4.2
echo   ================================
echo.

:: ===== Source dir =====
set "SRC_DIR=%~dp0"
set "SRC_MODULES=%SRC_DIR%src"
set "DIST_DIR=%SRC_DIR%dist"
set "BUNDLE=%DIST_DIR%\auto-retry.bundle.js"

:: ===== Verify source files =====
set "MODULES=config.js state.js status-badge.js fetch-retry.js audio-mute.js dom-clicker.js entry.js"
set "MISSING=0"
for %%m in (%MODULES%) do (
    if not exist "%SRC_MODULES%\%%m" (
        echo [ERROR] Source file missing: src\%%m
        set "MISSING=1"
    )
)
if "%MISSING%"=="1" (
    echo   Source files not found.
    pause
    exit /b 1
)

:: ===== Auto-detect Antigravity =====
set "AG_DIR="
if exist "C:\Antigravity\resources\app\product.json" set "AG_DIR=C:\Antigravity\resources\app"
if not defined AG_DIR if exist "C:\Program Files\Antigravity\resources\app\product.json" set "AG_DIR=C:\Program Files\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\Antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\Programs\Antigravity\resources\app"
if not defined AG_DIR if exist "%LOCALAPPDATA%\antigravity\resources\app\product.json" set "AG_DIR=%LOCALAPPDATA%\antigravity\resources\app"
if not defined AG_DIR if exist "%ProgramFiles(x86)%\Antigravity\resources\app\product.json" set "AG_DIR=%ProgramFiles(x86)%\Antigravity\resources\app"
if not defined AG_DIR if exist "%USERPROFILE%\Antigravity\resources\app\product.json" set "AG_DIR=%USERPROFILE%\Antigravity\resources\app"

if not defined AG_DIR (
    echo [INFO] Antigravity not found.
    set /p "AG_DIR=Enter path to resources\app: "
    if not exist "!AG_DIR!\product.json" (
        echo [ERROR] product.json not found.
        pause
        exit /b 1
    )
)

echo [OK] Antigravity: %AG_DIR%

set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_MAIN=%WB_DIR%\workbench.html"
set "HTML_JETSKI=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"

:: ===== Step 1: Build bundle =====
echo.
echo [1/5] Building bundle...
powershell -ExecutionPolicy Bypass -File "%SRC_DIR%build.ps1" -SrcDir "%SRC_MODULES%" -OutDir "%DIST_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)
echo       Bundle ready.

:: ===== Step 2: Copy bundle =====
echo [2/5] Copying to Antigravity...
powershell -ExecutionPolicy Bypass -Command "Copy-Item -Path '%BUNDLE%' -Destination '%RETRY_JS%' -Force"
if not exist "%RETRY_JS%" (
    echo [ERROR] Copy failed! Try running as Administrator.
    pause
    exit /b 1
)
echo       Done.

:: ===== Step 3: Backup =====
echo [3/5] Creating backups...
if not exist "%PRODUCT_JSON%.bak" copy /Y "%PRODUCT_JSON%" "%PRODUCT_JSON%.bak" >nul
if exist "%HTML_MAIN%" if not exist "%HTML_MAIN%.bak" copy /Y "%HTML_MAIN%" "%HTML_MAIN%.bak" >nul
if exist "%HTML_JETSKI%" if not exist "%HTML_JETSKI%.bak" copy /Y "%HTML_JETSKI%" "%HTML_JETSKI%.bak" >nul
echo       Done.

:: ===== Step 4: Inject into BOTH HTML files =====
echo [4/5] Injecting patch...

:: --- workbench.html (main window - status bar, fetch retry) ---
if exist "%HTML_MAIN%" (
    findstr /C:"auto-retry.js" "%HTML_MAIN%" >nul 2>&1
    if !errorlevel! neq 0 (
        powershell -ExecutionPolicy Bypass -File "%SRC_DIR%inject.ps1" -HtmlFile "%HTML_MAIN%"
        if !errorlevel! neq 0 (
            echo [ERROR] Injection into workbench.html failed!
        ) else (
            echo       workbench.html - OK
        )
    ) else (
        echo       workbench.html - already patched
    )
) else (
    echo       workbench.html - not found, skipping
)

:: --- workbench-jetski-agent.html (agent context) ---
if exist "%HTML_JETSKI%" (
    findstr /C:"auto-retry.js" "%HTML_JETSKI%" >nul 2>&1
    if !errorlevel! neq 0 (
        powershell -ExecutionPolicy Bypass -File "%SRC_DIR%inject.ps1" -HtmlFile "%HTML_JETSKI%"
        if !errorlevel! neq 0 (
            echo [ERROR] Injection into workbench-jetski-agent.html failed!
        ) else (
            echo       workbench-jetski-agent.html - OK
        )
    ) else (
        echo       workbench-jetski-agent.html - already patched
    )
) else (
    echo       workbench-jetski-agent.html - not found, skipping
)

:: ===== Step 5: Update checksums for ALL modified HTMLs =====
echo [5/5] Updating checksums...
if exist "%HTML_MAIN%" (
    powershell -ExecutionPolicy Bypass -File "%SRC_DIR%checksum.ps1" -HtmlFile "%HTML_MAIN%" -ProductJson "%PRODUCT_JSON%"
)
if exist "%HTML_JETSKI%" (
    powershell -ExecutionPolicy Bypass -File "%SRC_DIR%checksum.ps1" -HtmlFile "%HTML_JETSKI%" -ProductJson "%PRODUCT_JSON%"
)

:: ===== Verify =====
echo.
echo   Verifying installation...
set "VERIFY_OK=1"
if not exist "%RETRY_JS%" (
    echo   [FAIL] auto-retry.js not found
    set "VERIFY_OK=0"
)
if exist "%HTML_MAIN%" (
    findstr /C:"auto-retry.js" "%HTML_MAIN%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [FAIL] Not in workbench.html
        set "VERIFY_OK=0"
    )
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
