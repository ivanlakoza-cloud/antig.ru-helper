@echo off
chcp 65001 >nul
echo.
echo   ╔══════════════════════════════════════════╗
echo   ║   AntiG.ru Helper — Установка v3.0       ║
echo   ╚══════════════════════════════════════════╝
echo.

:: Проверка Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Node.js не найден!
    echo Установите с https://nodejs.org/ и повторите.
    pause
    exit /b 1
)

set "AG_DIR=C:\Antigravity\resources\app"
set "WB_DIR=%AG_DIR%\out\vs\code\electron-browser\workbench"
set "HTML_FILE=%WB_DIR%\workbench-jetski-agent.html"
set "RETRY_JS=%WB_DIR%\auto-retry.js"
set "PRODUCT_JSON=%AG_DIR%\product.json"
set "SRC_DIR=%~dp0"
set "BUNDLE=%SRC_DIR%dist\auto-retry.bundle.js"

:: Проверка Antigravity
if not exist "%AG_DIR%" (
    echo [ОШИБКА] Antigravity не найден: %AG_DIR%
    echo Убедитесь, что Antigravity установлен.
    pause
    exit /b 1
)

:: Сборка
echo [1/4] Сборка...
node "%SRC_DIR%build.js"
if not exist "%BUNDLE%" (
    echo [ОШИБКА] Сборка провалилась!
    pause
    exit /b 1
)

:: Копирование
echo [2/4] Копирование в Antigravity...
copy /Y "%BUNDLE%" "%RETRY_JS%" >nul
echo       Готово.

:: Инъекция в HTML
findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo [3/4] Уже установлен. Обновление.
    goto :update_checksum
)

echo [3/4] Установка патча...
copy /Y "%HTML_FILE%" "%HTML_FILE%.bak" >nul
copy /Y "%PRODUCT_JSON%" "%PRODUCT_JSON%.bak" >nul

powershell -Command "$c = Get-Content '%HTML_FILE%' -Raw; $tag = '<script src=\"./auto-retry.js\"></script>'; $target = '<script src=\"./jetskiAgent.js\" type=\"module\"></script>'; $c = $c.Replace($target, $tag + [char]10 + $target); [System.IO.File]::WriteAllText('%HTML_FILE%', $c)"

findstr /C:"auto-retry.js" "%HTML_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось установить патч!
    copy /Y "%HTML_FILE%.bak" "%HTML_FILE%" >nul
    pause
    exit /b 1
)
echo       Патч установлен.

:update_checksum
echo [4/4] Обновление контрольной суммы...
powershell -Command "$bytes = [System.IO.File]::ReadAllBytes('%HTML_FILE%'); $sha = [System.Security.Cryptography.SHA256]::Create(); $hash = [Convert]::ToBase64String($sha.ComputeHash($bytes)); $c = Get-Content '%PRODUCT_JSON%' -Raw; $c = [regex]::Replace($c, '(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', '${1}' + $hash + '${3}'); [System.IO.File]::WriteAllText('%PRODUCT_JSON%', $c); Write-Host '      OK'"

echo.
echo   ╔══════════════════════════════════════════╗
echo   ║   Установка завершена!                    ║
echo   ║   Перезапустите Antigravity.              ║
echo   ╚══════════════════════════════════════════╝
echo.
echo   Что делает:
echo     - Auto-retry при ошибках 429/502/503
echo     - Auto-click "Try again" / "Retry" / "Run"
echo     - Подавление звуков ошибок
echo.
echo   Откат: запустите uninstall.bat
echo.
pause
