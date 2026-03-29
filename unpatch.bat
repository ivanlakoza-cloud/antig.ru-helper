@echo off
chcp 65001 >nul
echo ============================================
echo   Antigravity Auto-Retry ОТКАТ v1.0
echo ============================================
echo.

set "AG_DIR=C:\Antigravity\resources\app"
set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_FILE=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"

:: Проверяем, что патч вообще применён
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Патч не обнаружен. Нечего откатывать.
    pause
    exit /b 0
)

echo [1/3] Удаляю строку auto-retry.js из HTML...
powershell -Command ^
    "$c = Get-Content '%HTML_FILE%' -Raw;" ^
    "$c = $c.Replace(\"`n<script src=\"\"./auto-retry.js\"\"></script>\", '');" ^
    "$c = $c.Replace(\"<script src=\"\"./auto-retry.js\"\"></script>`n\", '');" ^
    "$c = $c.Replace(\"<script src=\"\"./auto-retry.js\"\"></script>\", '');" ^
    "[System.IO.File]::WriteAllText('%HTML_FILE%', $c);" ^
    "Write-Host '      HTML восстановлен.'"

:: Проверяем результат
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось полностью очистить HTML.
    echo Попробуйте восстановить из бэкапа:
    echo   copy "%HTML_FILE%.bak" "%HTML_FILE%"
    pause
    exit /b 1
)

echo [2/3] Обновляю checksum в product.json...
powershell -Command ^
    "$bytes = [System.IO.File]::ReadAllBytes('%HTML_FILE%');" ^
    "$sha256 = [System.Security.Cryptography.SHA256]::Create();" ^
    "$hash = $sha256.ComputeHash($bytes);" ^
    "$newHash = [Convert]::ToBase64String($hash);" ^
    "$content = Get-Content '%PRODUCT_JSON%' -Raw;" ^
    "$content = [regex]::Replace($content, '(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', '${1}' + $newHash + '${3}');" ^
    "[System.IO.File]::WriteAllText('%PRODUCT_JSON%', $content);" ^
    "Write-Host '      Checksum обновлён: ' $newHash"

echo [3/3] Удаляю auto-retry.js из Antigravity...
if exist "%RETRY_JS%" (
    del "%RETRY_JS%"
    echo       auto-retry.js удалён.
) else (
    echo       auto-retry.js уже отсутствует.
)

echo.
echo ============================================
echo   Откат завершён!
echo   Перезапустите Antigravity.
echo ============================================
echo.
pause
