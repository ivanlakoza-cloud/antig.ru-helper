@echo off
setlocal enabledelayedexpansion
echo.
echo   AntiG.ru Helper - Install v3.1
echo   ================================
echo.

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found!
    echo Install from https://nodejs.org/ and try again.
    pause
    exit /b 1
)

:: ===== Auto-detect Antigravity path =====
set "AG_DIR="

if exist "C:\Antigravity\resources\app\product.json" (
    set "AG_DIR=C:\Antigravity\resources\app"
)
if not defined AG_DIR if exist "C:\Program Files\Antigravity\resources\app\product.json" (
    set "AG_DIR=C:\Program Files\Antigravity\resources\app"
)
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\antigravity\resources\app\product.json" (
    set "AG_DIR=%LOCALAPPDATA%\Programs\antigravity\resources\app"
)
if not defined AG_DIR if exist "%LOCALAPPDATA%\Programs\Antigravity\resources\app\product.json" (
    set "AG_DIR=%LOCALAPPDATA%\Programs\Antigravity\resources\app"
)
if not defined AG_DIR if exist "%LOCALAPPDATA%\antigravity\resources\app\product.json" (
    set "AG_DIR=%LOCALAPPDATA%\antigravity\resources\app"
)

if not defined AG_DIR (
    echo [INFO] Antigravity not found in standard paths.
    echo.
    echo Enter path to Antigravity resources\app folder:
    echo Example: C:\Users\YourName\AppData\Local\Programs\antigravity\resources\app
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
set "SRC_DIR=%~dp0"
set "BUNDLE=%SRC_DIR%dist\auto-retry.bundle.js"

if not exist "%HTML_FILE%" (
    echo [ERROR] Workbench file not found: %HTML_FILE%
    pause
    exit /b 1
)

:: Build
echo [1/4] Building...
node "%SRC_DIR%build.js"
if not exist "%BUNDLE%" (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

:: Copy using PowerShell (cmd copy fails silently when called via cmd /c from PS)
echo [2/4] Copying to Antigravity...
powershell -Command "Copy-Item -Path '%BUNDLE%' -Destination '%RETRY_JS%' -Force"
if not exist "%RETRY_JS%" (
    echo [ERROR] Copy failed! Try running as Administrator.
    pause
    exit /b 1
)
echo       Done. Verified.

:: Inject into HTML
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [3/4] Already installed. Updating.
    goto :update_checksum
)

echo [3/4] Installing patch...
copy /Y "%HTML_FILE%" "%HTML_FILE%.bak" >nul
copy /Y "%PRODUCT_JSON%" "%PRODUCT_JSON%.bak" >nul

powershell -Command "$c = Get-Content '%HTML_FILE%' -Raw; $tag = '<script src=\"./auto-retry.js\"></script>'; $target = '<script src=\"./jetskiAgent.js\" type=\"module\"></script>'; $c = $c.Replace($target, $tag + [char]10 + $target); [System.IO.File]::WriteAllText('%HTML_FILE%', $c)"

findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to inject script!
    copy /Y "%HTML_FILE%.bak" "%HTML_FILE%" >nul
    pause
    exit /b 1
)
echo       Patch installed.

:update_checksum
echo [4/4] Updating checksum...
powershell -Command "$bytes = [System.IO.File]::ReadAllBytes('%HTML_FILE%'); $sha = [System.Security.Cryptography.SHA256]::Create(); $hash = [Convert]::ToBase64String($sha.ComputeHash($bytes)); $c = Get-Content '%PRODUCT_JSON%' -Raw; $c = [regex]::Replace($c, '(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', '${1}' + $hash + '${3}'); [System.IO.File]::WriteAllText('%PRODUCT_JSON%', $c); Write-Host '      OK'"

echo.
echo   ================================
echo   Install complete!
echo   Restart Antigravity to activate.
echo   ================================
echo.
echo   Features:
echo     - Auto-retry on errors 429/502/503
echo     - Auto-click Try again / Retry / Run
echo     - Error sound muting
echo.
echo   To uninstall: run uninstall.bat
echo.
pause
