/**
 * entry.js — Entry Point
 * 
 * Точка входа Auto-Retry Patch.
 * Инициализирует все уровни защиты.
 * 
 * @version 3.0
 */

// Инициализация всех уровней
initFetchRetry();    // Level 1+2: Fetch + Stream retry
initAudioMute();     // Level 3: Audio muting
initDomClicker();    // Level 4: DOM auto-click
initBadge();         // UI: Status bar badge

// ===== PUBLIC API =====
window.__autoRetry = {
    version: '3.0',
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
    }
};

log('=== Antigravity Auto-Retry v3.0 ===');
log('Badge: ↻ = retry toggle');
