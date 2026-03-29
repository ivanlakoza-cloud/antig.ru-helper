@echo off
setlocal enabledelayedexpansion
echo.
echo   AntiG.ru Helper - Uninstall
echo.

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

findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo   Patch not installed. Nothing to uninstall.
    pause
    exit /b 0
)

echo [1/3] Removing from HTML...
powershell -Command ^
    "$c = Get-Content '%HTML_FILE%' -Raw;" ^
    "$c = $c.Replace(\"`n<script src=\"\"./auto-retry.js\"\"></script>\", '');" ^
    "$c = $c.Replace(\"<script src=\"\"./auto-retry.js\"\"></script>`n\", '');" ^
    "$c = $c.Replace(\"<script src=\"\"./auto-retry.js\"\"></script>\", '');" ^
    "[System.IO.File]::WriteAllText('%HTML_FILE%', $c);" ^
    "Write-Host '      OK'"

echo [2/3] Updating checksum...
powershell -Command ^
    "$bytes = [System.IO.File]::ReadAllBytes('%HTML_FILE%');" ^
    "$sha = [System.Security.Cryptography.SHA256]::Create();" ^
    "$hash = [Convert]::ToBase64String($sha.ComputeHash($bytes));" ^
    "$c = Get-Content '%PRODUCT_JSON%' -Raw;" ^
    "$c = [regex]::Replace($c, '(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', '${1}' + $hash + '${3}');" ^
    "[System.IO.File]::WriteAllText('%PRODUCT_JSON%', $c);" ^
    "Write-Host '      OK'"

echo [3/3] Removing file...
if exist "%RETRY_JS%" del "%RETRY_JS%"
echo       OK

echo.
echo   Uninstall complete. Restart Antigravity.
echo.
pause
