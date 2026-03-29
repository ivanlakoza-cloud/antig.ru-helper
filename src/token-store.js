/**
 * token-store.js — Хранилище данных о потреблении токенов
 * 
 * Сохраняет записи в localStorage с автоматической ротацией.
 * Предоставляет API для агрегации по моделям, периодам, сессиям.
 * 
 * Лимиты: 10000 записей / 30 дней.
 * 
 * Зависимости: config.js, state.js
 * 
 * @version 1.0
 */

const TOKEN_STORE_KEY = '__autoRetry_tokens';
const TOKEN_SESSION_KEY = '__autoRetry_session';
const MAX_RECORDS = 10000;
const MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30 дней

/** ID текущей сессии (timestamp старта) */
const SESSION_ID = Date.now();

/**
 * Загрузить все записи из localStorage
 * @returns {Array} Массив записей
 */
function loadTokenRecords() {
    try {
        const raw = localStorage.getItem(TOKEN_STORE_KEY);
        return raw ? JSON.parse(raw) : [];
    } catch (e) {
        return [];
    }
}

/**
 * Сохранить записи в localStorage с ротацией
 * @param {Array} records - Массив записей
 */
function saveTokenRecords(records) {
    try {
        // Ротация по возрасту
        const cutoff = Date.now() - MAX_AGE_MS;
        let filtered = records.filter(r => r.ts > cutoff);

        // Ротация по количеству
        if (filtered.length > MAX_RECORDS) {
            filtered = filtered.slice(filtered.length - MAX_RECORDS);
        }

        localStorage.setItem(TOKEN_STORE_KEY, JSON.stringify(filtered));
    } catch (e) {
        warn('[STORE] Ошибка сохранения:', e.message);
    }
}

/**
 * Добавить запись о потреблении токенов
 * @param {Object} params
 * @param {string} params.model - Имя модели
 * @param {number} params.promptTokens - Входные токены
 * @param {number} params.outputTokens - Выходные токены
 * @param {number} params.thinkTokens - Thinking токены
 * @param {number} params.cachedTokens - Кэшированные токены
 * @param {number} params.totalTokens - Всего токенов
 * @param {number} params.duration - Длительность запроса (ms)
 * @param {string} params.status - 'ok' | 'error' | 'retry'
 */
function addTokenRecord(params) {
    const record = {
        ts: Date.now(),
        sid: SESSION_ID,
        model: params.model || 'unknown',
        in: params.promptTokens || 0,
        out: params.outputTokens || 0,
        think: params.thinkTokens || 0,
        cached: params.cachedTokens || 0,
        total: params.totalTokens || 0,
        dur: params.duration || 0,
        status: params.status || 'ok'
    };

    const records = loadTokenRecords();
    records.push(record);
    saveTokenRecords(records);

    log(`[TOKENS] ${record.model}: in=${record.in} out=${record.out} think=${record.think} total=${record.total}`);
    return record;
}

/**
 * Получить сводку по текущей сессии
 * @returns {Object} { totalIn, totalOut, totalThink, totalTokens, requests, byModel }
 */
function getSessionSummary() {
    const records = loadTokenRecords().filter(r => r.sid === SESSION_ID);
    return aggregateRecords(records);
}

/**
 * Получить сводку за период
 * @param {'today'|'week'|'month'|'all'} period - Период
 * @returns {Object} Агрегированные данные
 */
function getPeriodSummary(period) {
    const now = Date.now();
    const periods = {
        today: now - 24 * 60 * 60 * 1000,
        week: now - 7 * 24 * 60 * 60 * 1000,
        month: now - 30 * 24 * 60 * 60 * 1000,
        all: 0
    };
    const cutoff = periods[period] || periods.today;
    const records = loadTokenRecords().filter(r => r.ts > cutoff);
    return aggregateRecords(records);
}

/**
 * Получить данные для графика (по часам или дням)
 * @param {'hours'|'days'} granularity - Группировка
 * @param {number} count - Количество точек
 * @returns {Array<{label: string, in: number, out: number, total: number}>}
 */
function getChartData(granularity, count) {
    const records = loadTokenRecords();
    const now = Date.now();
    const bucketSize = granularity === 'hours' ? 60 * 60 * 1000 : 24 * 60 * 60 * 1000;
    const points = [];

    for (let i = count - 1; i >= 0; i--) {
        const start = now - (i + 1) * bucketSize;
        const end = now - i * bucketSize;
        const bucket = records.filter(r => r.ts >= start && r.ts < end);
        const agg = aggregateRecords(bucket);

        const d = new Date(end);
        const label = granularity === 'hours'
            ? `${d.getHours()}:00`
            : `${d.getDate()}/${d.getMonth() + 1}`;

        points.push({ label, in: agg.totalIn, out: agg.totalOut, total: agg.totalTokens });
    }

    return points;
}

/**
 * Агрегировать массив записей
 * @param {Array} records
 * @returns {Object}
 */
function aggregateRecords(records) {
    const byModel = {};
    let totalIn = 0, totalOut = 0, totalThink = 0, totalTokens = 0;
    let errors = 0, retries = 0;

    for (const r of records) {
        totalIn += r.in || 0;
        totalOut += r.out || 0;
        totalThink += r.think || 0;
        totalTokens += r.total || 0;

        if (r.status === 'error') errors++;
        if (r.status === 'retry') retries++;

        if (!byModel[r.model]) {
            byModel[r.model] = { in: 0, out: 0, think: 0, total: 0, requests: 0 };
        }
        byModel[r.model].in += r.in || 0;
        byModel[r.model].out += r.out || 0;
        byModel[r.model].think += r.think || 0;
        byModel[r.model].total += r.total || 0;
        byModel[r.model].requests++;
    }

    return { totalIn, totalOut, totalThink, totalTokens, requests: records.length, errors, retries, byModel };
}

/**
 * Очистить все данные
 */
function clearTokenStore() {
    localStorage.removeItem(TOKEN_STORE_KEY);
    log('[STORE] Данные очищены');
}
