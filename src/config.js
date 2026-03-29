/**
 * config.js — Конфигурация Auto-Retry Patch
 * 
 * Все настройки в одном месте. Изменяются через:
 *   window.__autoRetry.config
 * 
 * @version 2.1
 */

const CONFIG = {
    // === Level 1: Fetch HTTP retry ===
    fetchMaxRetries: 8,
    fetchRetryBaseDelay: 5000,
    fetchRetryMaxDelay: 60000,
    fetchRetryJitter: 2000,
    fetchRetryStatuses: [429, 503, 502, 520, 522, 524],

    // === Level 2: Connect stream retry ===
    connectRetryCodeNames: ['resource_exhausted', 'unavailable', 'internal', 'deadline_exceeded'],
    connectRetryGrpcCodes: [8, 14, 13, 4],

    // === Level 4: DOM auto-click ===
    domEnabled: true,
    domClickDelay: 500,
    domMaxClicks: 100,
    domCooldown: 1000,
    domScanInterval: 1500,
    domResetTimeout: 5 * 60 * 1000,

    // === Тексты для поиска ===
    retryButtonTexts: ['try again', 'retry'],
    errorTexts: [
        'high traffic', 'servers are experiencing', 'try again in a minute',
        'too many requests', 'rate limit', 'agent terminated due to error',
        'error is likely temporary'
    ],

    // === Level 3: Audio muting ===
    muteErrorSounds: true,

    // === UI ===
    hideErrorNotifications: true,

    // === Логирование ===
    logEnabled: true,
    logPrefix: '[AutoRetry]'
};
