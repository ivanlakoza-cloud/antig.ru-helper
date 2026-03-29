# Правила разработки — Antigravity Auto-Retry Patch

## ⚠️ Обязательные правила

### 1. Максимальный размер файла — 300 строк

> **Ни один файл `.js` не должен превышать 300 строк кода.**

- Рекомендуемый размер: **100–200 строк**
- Минимальный размер модуля: **20 строк** (избегать чрезмерной фрагментации)
- Комментарии и пустые строки входят в подсчёт
- Если файл приближается к 250 строкам — планировать декомпозицию

### 2. Модульность (Single Responsibility)

- **Один файл = одна ответственность**
- Модули размещаются в `src/`
- Каждый модуль — это секция IIFE, экспортирующая свой функционал через общий namespace
- Общее состояние (`state`) — отдельный модуль `src/state.js`
- Конфигурация — отдельный модуль `src/config.js`

### 3. Именование

| Что | Формат | Пример |
|---|---|---|
| Файлы | `kebab-case.js` | `fetch-retry.js`, `dom-clicker.js` |
| Модули/namespace | `camelCase` | `fetchRetry`, `domClicker` |
| Константы | `UPPER_SNAKE_CASE` | `FETCH_MAX_RETRIES` |
| Функции | `camelCase` | `findRetryElements()` |

### 4. Документирование

- JSDoc в начале каждого файла (назначение, версия, автор)
- Публичные функции — JSDoc с `@param`, `@returns`
- `README.md` актуализируется при изменении структуры

### 5. Обратная совместимость

- `window.__autoRetry` API — сохранять при рефакторинге
- `patch.bat` / `unpatch.bat` — обновлять синхронно с изменениями
- Бэкапы оригинальных файлов Antigravity — обязательны

## Структура проекта

```
C:\GitHub\Retry\
├── src/                    ← Исходные модули (каждый ≤ 300 строк)
│   ├── config.js           ← Конфигурация и константы
│   ├── state.js            ← Общее состояние + логгер
│   ├── fetch-retry.js      ← Fetch monkey-patch + Connect stream
│   ├── audio-mute.js       ← Подавление звуков ошибок
│   ├── dom-clicker.js      ← DOM авто-клик ("Try again")
│   └── status-badge.js     ← UI: badge в статусбаре
├── auto-retry.js           ← Entry point + public API
├── build.js                ← Сборка: конкатенация → dist/
├── dist/
│   └── auto-retry.bundle.js  ← Собранный файл для Antigravity
├── patch.bat               ← Установка патча
├── unpatch.bat             ← Откат патча
├── CONTRIBUTING.md         ← Этот файл
├── .editorconfig           ← Правила форматирования
└── README.md               ← Документация
```

## Сборка

Поскольку скрипт внедряется как `<script>` (не ES module), используется конкатенация:

```bash
node build.js
```

Результат: `dist/auto-retry.bundle.js` — один IIFE файл.

## Чеклист перед коммитом

- [ ] Ни один файл `.js` не превышает 300 строк
- [ ] Каждый модуль имеет JSDoc-заголовок
- [ ] `window.__autoRetry` API не сломан
- [ ] `node build.js` создаёт работающий bundle
- [ ] Тест в Antigravity: retry работает на всех уровнях
- [ ] `README.md` актуален
