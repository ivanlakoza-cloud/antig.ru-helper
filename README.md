# Antigravity Auto-Retry Patch

Патч для [Antigravity IDE](https://antigravity.dev): автоматический retry при серверных ошибках (429, 502, 503 и др.), auto-click кнопок "Try again" / "Retry" / "Run", подавление звуков ошибок.

## Возможности

| Уровень | Что делает |
|---|---|
| **Level 1** | HTTP retry (429/502/503/520/522/524) с exponential backoff |
| **Level 2** | Connect/gRPC stream error retry (resource_exhausted, unavailable и др.) |
| **Level 3** | Подавление звуков ошибок при retry |
| **Level 4** | Auto-click "Try again" / "Retry" / "Run" (MutationObserver + periodic scan + XPath) |
| **UI** | Badge в статусбаре с индикатором ON/OFF и счётчиком retry |

## Установка

### Windows

```cmd
node build.js
patch.bat
```

### macOS / Linux

```bash
node build.js
chmod +x patch.sh
./patch.sh
```

Перезапустите Antigravity после установки.

> **macOS:** Если Antigravity установлен не в `/Applications/Antigravity.app/`, отредактируйте `AG_DIR` в `patch.sh`.

## Откат

| Windows | macOS / Linux |
|---|---|
| `unpatch.bat` | `chmod +x unpatch.sh && ./unpatch.sh` |

Перезапустите Antigravity после отката.

## После обновления Antigravity

Запустить `patch.bat` (Win) или `./patch.sh` (Mac/Linux) повторно → перезапустить IDE.

## Структура проекта

```
├── src/                     ← Исходные модули (каждый ≤ 300 строк)
│   ├── config.js            ← Конфигурация
│   ├── state.js             ← Состояние + логгер + TrustedTypes
│   ├── status-badge.js      ← UI badge в статусбаре
│   ├── fetch-retry.js       ← Level 1+2: Fetch + Connect stream retry
│   ├── audio-mute.js        ← Level 3: Подавление звуков ошибок
│   ├── dom-clicker.js       ← Level 4: DOM auto-click
│   └── entry.js             ← Точка входа + public API
├── build.js                 ← Сборка (с проверкой лимита 300 строк)
├── dist/                    ← Собранный bundle (в .gitignore)
├── patch.bat / patch.sh     ← Установка
├── unpatch.bat / unpatch.sh ← Откат
└── CONTRIBUTING.md          ← Правила разработки
```

## API (DevTools Console)

```javascript
window.__autoRetry.toggle()          // Вкл/Выкл retry
window.__autoRetry.getState()        // Текущее состояние
window.__autoRetry.diagnose()        // Список всех кнопок в DOM
window.__autoRetry.setDelay(1000)    // Задержка перед auto-click (ms)
window.__autoRetry.resetClicks()     // Сбросить счётчик кликов
window.__autoRetry.flash('Hello!')   // Тестовая flash-анимация badge
window.__autoRetry.showBadge()       // Показать badge
window.__autoRetry.hideBadge()       // Скрыть badge
```

## Конфигурация

Настройки доступны через `window.__autoRetry.config`:

```javascript
// Retry
config.fetchMaxRetries = 8           // Макс. кол-во retry
config.fetchRetryBaseDelay = 5000    // Базовая задержка (ms)
config.fetchRetryMaxDelay = 60000    // Макс. задержка (ms)

// Auto-click
config.domEnabled = true             // Вкл/выкл auto-click
config.domClickDelay = 500           // Задержка перед кликом (ms)
config.domMaxClicks = 100            // Макс. кликов до сброса
config.retryButtonTexts              // ['try again', 'retry', 'run']

// Другое
config.muteErrorSounds = true        // Подавлять звуки
config.logEnabled = true             // Логирование в console
```

## Кроссплатформенность

| Компонент | Windows | macOS | Linux |
|---|---|---|---|
| `auto-retry.bundle.js` | ✅ | ✅ | ✅ |
| `build.js` | ✅ | ✅ | ✅ |
| `patch.bat` / `unpatch.bat` | ✅ | — | — |
| `patch.sh` / `unpatch.sh` | — | ✅ | ✅ |

## Лицензия

MIT
