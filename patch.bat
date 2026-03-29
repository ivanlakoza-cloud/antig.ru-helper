@echo off
echo ============================================
echo   Antigravity Auto-Retry Patcher v2.0
echo ============================================
echo.

set "AG_DIR=C:\Antigravity\resources\app"
set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_FILE=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"
set "SRC_DIR=%~dp0"
set "BUNDLE=%SRC_DIR%dist\auto-retry.bundle.js"

if not exist "%AG_DIR%" (
    echo [ERROR] Antigravity not found at %AG_DIR%
    pause
    exit /b 1
)

if not exist "%BUNDLE%" (
    echo [INFO] Bundle not found. Building...
    node "%SRC_DIR%build.js"
    if not exist "%BUNDLE%" (
        echo [ERROR] Build failed!
        pause
        exit /b 1
    )
)

echo [1/4] Copying bundle to Antigravity...
copy /Y "%BUNDLE%" "%RETRY_JS%" >nul
echo       Done.

findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [2/4] Patch already applied to HTML. Skipping.
    goto :update_checksum
)

echo [2/4] Creating backups...
copy /Y "%HTML_FILE%" "%HTML_FILE%.bak" >nul
copy /Y "%PRODUCT_JSON%" "%PRODUCT_JSON%.bak" >nul
echo       Backups created.

echo [3/4] Injecting auto-retry.js into HTML...
powershell -Command "$c = Get-Content '%HTML_FILE%' -Raw; $tag = '<script src=\"./auto-retry.js\"></script>'; $target = '<script src=\"./jetskiAgent.js\" type=\"module\"></script>'; $c = $c.Replace($target, $tag + [char]10 + $target); [System.IO.File]::WriteAllText('%HTML_FILE%', $c)"

findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to inject script!
    echo Restoring backup...
    copy /Y "%HTML_FILE%.bak" "%HTML_FILE%" >nul
    pause
    exit /b 1
)
echo       HTML patched.

:update_checksum
echo [4/4] Updating checksum in product.json...
powershell -Command "$bytes = [System.IO.File]::ReadAllBytes('%HTML_FILE%'); $sha = [System.Security.Cryptography.SHA256]::Create(); $hash = [Convert]::ToBase64String($sha.ComputeHash($bytes)); $c = Get-Content '%PRODUCT_JSON%' -Raw; $c = [regex]::Replace($c, '(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', '${1}' + $hash + '${3}'); [System.IO.File]::WriteAllText('%PRODUCT_JSON%', $c); Write-Host '      Checksum:' $hash"

echo.
echo ============================================
echo   Patch applied successfully!
echo   Restart Antigravity to activate.
echo ============================================
echo.
echo Logs: DevTools (Ctrl+Shift+I) - Console
echo API: window.__autoRetry
echo Tokens: window.__autoRetry.tokens
echo.
pause
