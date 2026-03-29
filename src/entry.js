/**
 * entry.js — Entry Point
 * 
 * Точка входа Auto-Retry Patch.
 * Инициализирует все уровни защиты + трекинг токенов.
 * 
 * @version 2.2
 */

// Инициализация всех уровней
initFetchRetry();   // Level 1+2: Fetch + Stream + Token tracking
initAudioMute();    // Level 3: Audio muting
initDomClicker();   // Level 4: DOM auto-click
initBadge();        // UI: Status bar badge (retry)
initTokenBadge();   // UI: Status bar badge (tokens)

// ===== PUBLIC API =====
window.__autoRetry = {
    version: '2.2',
    config: CONFIG,
    getState: () => ({
        retryActive: STATE.retryActive,
        totalRetries: STATE.totalRetries,
        clickCount: STATE.clickCount,
        fetchRetryCount: STATE.fetchRetryCount,
        streamRetryCount: STATE.streamRetryCount,
        lastClick: STATE.lastClickTime ? new Date(STATE.lastClickTime).toLocaleTimeString() : 'never'
    }),
    toggle: () => {
        STATE.retryActive = !STATE.retryActive;
        CONFIG.domEnabled = STATE.retryActive;
        updateBadge();
        return STATE.retryActive;
    },
    showBadge: () => { STATE.badgeVisible = true; if (STATE.badgeEl) STATE.badgeEl.style.display = 'inline-flex'; },
    hideBadge: () => { STATE.badgeVisible = false; if (STATE.badgeEl) STATE.badgeEl.style.display = 'none'; },
    resetClicks: () => { STATE.clickCount = 0; STATE.totalRetries = 0; updateBadge(); },
    setDelay: (ms) => { CONFIG.domClickDelay = ms; },
    flash: (msg) => flashBadge(msg || 'Test flash!', '#d97706', 2000),
    diagnose: () => {
        const btns = document.body.querySelectorAll('button, [role="button"]');
        log('All buttons:');
        for (const b of btns) {
            const t = (b.textContent || '').trim();
            if (t) log(`  <${b.tagName}> "${t.substring(0, 40)}"`);
        }
    },

    // Token tracking API
    tokens: {
        /** Сводка текущей сессии */
        session: () => getSessionSummary(),
        /** Сводка за период ('today'|'week'|'month'|'all') */
        period: (p) => getPeriodSummary(p || 'today'),
        /** Данные для графика */
        chart: (gran, count) => getChartData(gran || 'hours', count || 24),
        /** Очистить все данные */
        clear: () => clearTokenStore(),
        /** Показать/скрыть панель */
        panel: () => toggleTokenPanel(),
        /** Экспорт данных в JSON */
        export: () => {
            const data = loadTokenRecords();
            const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = `tokens_${new Date().toISOString().slice(0,10)}.json`;
            a.click(); URL.revokeObjectURL(url);
            log('[TOKENS] Данные экспортированы');
        }
    }
};

log('=== Antigravity Auto-Retry v2.2 + Token Tracking ===');
log('Badge: ↻ = retry toggle | 📊 = token stats');
