# AntiG.ru Helper

Патч для [Antigravity IDE](https://antigravity.dev): автоматический retry при серверных ошибках, auto-click кнопок и подавление звуков.

## Что делает

- ⚡ **Auto-retry** — повторяет запросы при ошибках 429/502/503 (exponential backoff)
- 🔄 **Auto-click** — автоматически нажимает "Try again" / "Retry" / "Run"
- 🔇 **Mute** — подавляет звуки ошибок при retry
- 📊 **Badge** — индикатор ON/OFF в статусбаре

## Установка (Windows)

### Вариант 1: Одной командой (PowerShell)

```powershell
git clone https://github.com/ivanlakoza-cloud/antig.ru-helper.git; cd antig.ru-helper; .\install.bat
```

### Вариант 2: Пошагово

```cmd
git clone https://github.com/ivanlakoza-cloud/antig.ru-helper.git
cd antig.ru-helper
install.bat
```

> После установки **перезапустите Antigravity**.

### Вариант 3: Без Git

1. Скачайте [ZIP-архив](https://github.com/ivanlakoza-cloud/antig.ru-helper/archive/refs/heads/main.zip)
2. Распакуйте
3. Запустите `install.bat`
4. Перезапустите Antigravity

## Удаление

```cmd
uninstall.bat
```

## Обновление

```cmd
cd antig.ru-helper
git pull
install.bat
```

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
├── install.bat              ← Установка (одна команда)
├── uninstall.bat            ← Удаление
├── src/                     ← Исходные модули
│   ├── config.js            ← Конфигурация
│   ├── state.js             ← Состояние + логгер
│   ├── status-badge.js      ← UI badge
│   ├── fetch-retry.js       ← Fetch + Connect stream retry
│   ├── audio-mute.js        ← Подавление звуков
│   ├── dom-clicker.js       ← DOM auto-click
│   └── entry.js             ← Точка входа + API
├── build.js                 ← Сборка
├── patch.bat / patch.sh     ← Установка (legacy)
├── unpatch.bat / unpatch.sh ← Откат (legacy)
└── CONTRIBUTING.md          ← Для разработчиков
```

## Кроссплатформенность

| | Windows | macOS | Linux |
|---|---|---|---|
| Установка | `install.bat` | `patch.sh` | `patch.sh` |
| Удаление | `uninstall.bat` | `unpatch.sh` | `unpatch.sh` |

## Лицензия

MIT
