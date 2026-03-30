/**
 * state.js — Общее состояние и утилиты логирования
 * 
 * Единый источник истины для всего разделяемого состояния.
 * Все модули читают/пишут через этот объект.
 * 
 * @version 2.1
 */

const STATE = {
    clickCount: 0,
    lastClickTime: 0,
    resetTimer: null,
    fetchRetryCount: 0,
    streamRetryCount: 0,
    retryActive: true,
    totalRetries: 0,
    badgeVisible: true,

    // UI элементы (устанавливаются status-badge.js)
    badgeEl: null,
    badgeStatusEl: null,
    badgeTextEl: null
};

/** WeakSet для предотвращения двойных кликов */
const clickedElements = new WeakSet();

/**
 * Логирование с таймстампом
 * @param {...any} args - Аргументы для console.log
 */
function log(...args) {
    if (CONFIG.logEnabled) {
        console.log(CONFIG.logPrefix, new Date().toLocaleTimeString(), ...args);
    }
}

/**
 * Предупреждение с таймстампом
 * @param {...any} args - Аргументы для console.warn
 */
function warn(...args) {
    if (CONFIG.logEnabled) {
        console.warn(CONFIG.logPrefix, new Date().toLocaleTimeString(), ...args);
    }
}

/**
 * Рассчитать задержку retry с exponential backoff + jitter
 * @param {number} attempt - Номер попытки (0-based)
 * @returns {number} Задержка в миллисекундах
 */
function retryDelay(attempt) {
    const base = Math.min(
        CONFIG.fetchRetryBaseDelay * Math.pow(1.5, attempt),
        CONFIG.fetchRetryMaxDelay
    );
    return base + Math.random() * CONFIG.fetchRetryJitter;
}
