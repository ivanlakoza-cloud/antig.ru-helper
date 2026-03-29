# Antigravity Auto-Retry Patch + Token Tracking

Патч для Antigravity IDE: автоматический retry при серверных ошибках + подсчёт токенов по моделям с графиками.

## Установка

### Windows
```cmd
node build.js
patch.bat
:: Перезапустить Antigravity
```

### macOS / Linux
```bash
node build.js
chmod +x patch.sh
./patch.sh
# Перезапустить Antigravity
```

> **Примечание для macOS:** Если Antigravity установлен не в `/Applications/Antigravity.app/`, отредактируйте `AG_DIR` в `patch.sh`.

## Откат

| Windows | macOS / Linux |
|---|---|
| `unpatch.bat` | `chmod +x unpatch.sh && ./unpatch.sh` |

## Структура проекта

```
├── src/                    ← Исходные модули (каждый ≤ 300 строк)
│   ├── config.js           ← Конфигурация
│   ├── state.js            ← Состояние + логгер + TrustedTypes
│   ├── fetch-retry.js      ← Fetch retry + token tracking
│   ├── audio-mute.js       ← Подавление звуков ошибок
│   ├── dom-clicker.js      ← DOM auto-click
│   ├── status-badge.js     ← UI: Retry badge
│   ├── token-parser.js     ← Парсинг usageMetadata
│   ├── token-store.js      ← localStorage хранилище
│   ├── token-ui.js         ← UI: Token panel + badge
│   └── entry.js            ← Entry point + API
├── build.js                ← Сборка (с проверкой лимита 300 строк)
├── dist/                   ← Собранный bundle
├── patch.bat / patch.sh    ← Установка (Windows / macOS)
├── unpatch.bat / unpatch.sh← Откат
└── CONTRIBUTING.md         ← Правила разработки
```

## Возможности

### Auto-Retry (4 уровня)
- **Level 1:** HTTP status retry (429/502/503) — exponential backoff
- **Level 2:** Connect stream error retry (resource_exhausted и др.)
- **Level 3:** Подавление звуков ошибок
- **Level 4:** Auto-click "Try again" (MutationObserver + scan + XPath)

### Token Tracking
- Подсчёт input/output/thinking/cached токенов
- Разбивка по моделям
- Canvas-графики за день/неделю/месяц
- Хранение 30 дней в localStorage
- Экспорт в JSON

## API (DevTools Console)

```javascript
window.__autoRetry.toggle()              // Вкл/Выкл retry
window.__autoRetry.getState()            // Состояние

window.__autoRetry.tokens.session()      // Сводка сессии
window.__autoRetry.tokens.period('week') // Сводка за период
window.__autoRetry.tokens.panel()        // Показать popup
window.__autoRetry.tokens.export()       // Экспорт JSON
window.__autoRetry.tokens.clear()        // Очистить данные
```

## Кроссплатформенность

| Компонент | Windows | macOS | Linux |
|---|---|---|---|
| `auto-retry.bundle.js` | ✅ | ✅ | ✅ |
| `build.js` | ✅ | ✅ | ✅ |
| `patch.bat` | ✅ | — | — |
| `patch.sh` | — | ✅ | ✅ |

## После обновления Antigravity

Запустить `patch.bat` (Win) или `./patch.sh` (Mac) → перезапустить.

## Правила разработки

См. [CONTRIBUTING.md](CONTRIBUTING.md) — лимит 300 строк на файл, модульность.
