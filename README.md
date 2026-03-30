# AntiG.ru Helper

Патч для [Antigravity IDE](https://antigravity.dev): автоматический retry при серверных ошибках, auto-click кнопок и подавление звуков.

> **Не требует Node.js, Python или других зависимостей.** Работает на чистом PowerShell (Windows) и bash (macOS/Linux).

## Что делает

- ⚡ **Auto-retry** — повторяет запросы при ошибках 429/502/503 (exponential backoff)
- 🔄 **Auto-click** — автоматически нажимает "Try again" / "Retry" / "Run"
- 🔇 **Mute** — подавляет звуки ошибок при retry
- 📊 **Badge** — индикатор ON/OFF в статусбаре

## Установка (одна команда)

Откройте терминал (`Ctrl + ~`) и вставьте команду:

### Windows (PowerShell)

```powershell
cd $env:TEMP; Invoke-WebRequest https://github.com/ivanlakoza-cloud/antig.ru-helper/archive/refs/heads/main.zip -OutFile helper.zip; Expand-Archive -Path helper.zip -DestinationPath . -Force; cd antig.ru-helper-main; cmd /c install.bat
```

### macOS (Terminal)

```bash
cd /tmp && curl -sL https://github.com/ivanlakoza-cloud/antig.ru-helper/archive/refs/heads/main.zip -o helper.zip && unzip -o helper.zip && cd antig.ru-helper-main && chmod +x patch.sh && ./patch.sh
```

### Linux (Terminal)

```bash
cd /tmp && curl -sL https://github.com/ivanlakoza-cloud/antig.ru-helper/archive/refs/heads/main.zip -o helper.zip && unzip -o helper.zip && cd antig.ru-helper-main && chmod +x patch.sh && ./patch.sh
```

> После установки **перезапустите Antigravity**.


## Удаление

```cmd
uninstall.bat
```

## Обновление

Просто скачайте и запустите `install.bat` заново → перезапустите IDE.

## После обновления Antigravity

Просто запустите `install.bat` повторно → перезапустите IDE.

---

## Возможности

| Уровень | Что делает |
|---|---|
| **Level 1** | HTTP retry (429/502/503/520/522/524) с exponential backoff |
| **Level 2** | Connect/gRPC stream error retry (resource_exhausted, unavailable и др.) |
| **Level 3** | Подавление звуков ошибок при retry |
| **Level 4** | Auto-click "Try again" / "Retry" / "Run" (MutationObserver + scan + XPath) |
| **UI** | Badge в статусбаре с индикатором ON/OFF и счётчиком retry |

## API (DevTools Console)

```javascript
window.__autoRetry.toggle()          // Вкл/Выкл retry
window.__autoRetry.getState()        // Текущее состояние
window.__autoRetry.diagnose()        // Список всех кнопок в DOM
window.__autoRetry.setDelay(1000)    // Задержка перед auto-click (ms)
window.__autoRetry.resetClicks()     // Сбросить счётчик кликов
```

## Конфигурация

Настройки доступны через `window.__autoRetry.config`:

```javascript
config.fetchMaxRetries = 8           // Макс. retry
config.fetchRetryBaseDelay = 5000    // Базовая задержка (ms)
config.domClickDelay = 500           // Задержка перед auto-click (ms)
config.domEnabled = true             // Вкл/выкл auto-click
config.muteErrorSounds = true        // Подавлять звуки
config.logEnabled = true             // Логи в console
```

## Структура проекта

```
├── install.bat              ← Установка Windows (одна команда)
├── patch.sh                 ← Установка macOS/Linux (одна команда)
├── uninstall.bat            ← Удаление (Windows)
├── unpatch.sh               ← Удаление (macOS/Linux)
├── src/                     ← Исходные модули
│   ├── config.js            ← Конфигурация
│   ├── state.js             ← Состояние + логгер
│   ├── status-badge.js      ← UI badge
│   ├── fetch-retry.js       ← Fetch + Connect stream retry
│   ├── audio-mute.js        ← Подавление звуков
│   ├── dom-clicker.js       ← DOM auto-click
│   └── entry.js             ← Точка входа + API
├── build.js                 ← Сборка (Node.js, опционально)
├── patch.bat                ← Установка (legacy)
├── unpatch.bat              ← Откат (legacy)
└── CONTRIBUTING.md          ← Для разработчиков
```

## Требования

| Компонент | Требуется? |
|---|---|
| Node.js | ❌ **Не нужен** |
| Python | ❌ Не нужен |
| PowerShell | ✅ Встроен в Windows |
| bash | ✅ Встроен в macOS/Linux |

## Кроссплатформенность

| | Windows | macOS | Linux |
|---|---|---|---|
| Установка | `install.bat` | `patch.sh` | `patch.sh` |
| Удаление | `uninstall.bat` | `unpatch.sh` | `unpatch.sh` |

## Лицензия

MIT
