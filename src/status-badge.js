/**
 * status-badge.js — UI: Индикатор в статусбаре
 * 
 * Отображает статус Auto-Retry (ON/OFF), счётчик retry,
 * flash-анимации при событиях. Поддерживает:
 *   - Встроенный элемент статусбара (primary)
 *   - Floating badge (fallback)
 * 
 * Зависимости: config.js, state.js
 * 
 * @version 2.1
 */

/**
 * Обновить отображение badge (текст, цвет, tooltip)
 */
function updateBadge() {
    if (!STATE.badgeEl || !STATE.badgeVisible) return;
    const counterText = STATE.totalRetries > 0 ? ` (${STATE.totalRetries})` : '';
    if (STATE.retryActive) {
        STATE.badgeStatusEl.style.background = '#4ade80';
        STATE.badgeStatusEl.style.boxShadow = '0 0 4px #4ade80';
        STATE.badgeTextEl.textContent = 'ON' + counterText;
        STATE.badgeEl.title = `AutoRetry active | ${STATE.totalRetries} retries | Click to disable`;
    } else {
        STATE.badgeStatusEl.style.background = '#666';
        STATE.badgeStatusEl.style.boxShadow = 'none';
        STATE.badgeTextEl.textContent = 'OFF' + counterText;
        STATE.badgeEl.title = `AutoRetry disabled | ${STATE.totalRetries} retries | Click to enable`;
    }
}

/**
 * Flash-анимация badge при событии retry
 * @param {string} text - Текст для отображения
 * @param {string} color - CSS цвет (#hex)
 * @param {number} duration - Длительность flash в ms
 */
function flashBadge(text, color, duration) {
    if (!STATE.badgeEl) return;
    STATE.totalRetries++;

    const flash = document.getElementById('__autoRetryFlash');
    if (flash) {
        flash.style.background = color;
        setTimeout(() => { flash.style.background = 'transparent'; }, 400);
    }

    STATE.badgeStatusEl.style.background = color;
    STATE.badgeStatusEl.style.boxShadow = `0 0 8px ${color}`;

    const origText = STATE.badgeTextEl.textContent;
    STATE.badgeTextEl.textContent = text;

    setTimeout(() => { updateBadge(); }, duration || 3000);
}

/**
 * Создать элемент flash overlay
 * @returns {HTMLElement}
 */
function createFlashOverlay() {
    const el = document.createElement('div');
    el.id = '__autoRetryFlash';
    el.style.cssText = `
        position: absolute; inset: 0;
        background: transparent; transition: background .15s;
        pointer-events: none; border-radius: 3px;
    `;
    return el;
}

/**
 * Создать элемент status dot
 * @returns {HTMLElement}
 */
function createStatusDot() {
    const el = document.createElement('span');
    el.style.cssText = `
        width: 7px; height: 7px; border-radius: 50%;
        display: inline-block; flex-shrink: 0;
        transition: background .3s, box-shadow .3s;
    `;
    return el;
}

/**
 * Привязать toggle-клик и hover к badge
 * @param {HTMLElement} el - Badge элемент
 */
function bindBadgeEvents(el) {
    el.addEventListener('mouseenter', () => { el.style.background = 'rgba(255,255,255,.1)'; });
    el.addEventListener('mouseleave', () => { el.style.background = 'transparent'; });
    el.addEventListener('click', () => {
        STATE.retryActive = !STATE.retryActive;
        CONFIG.domEnabled = STATE.retryActive;
        updateBadge();
        log(STATE.retryActive ? 'ENABLED' : 'DISABLED');
    });
}

/**
 * Инициализация badge в VS Code status bar
 */
function initStatusBarItem() {
    const statusBar = document.querySelector(
        '.statusbar-item.right, footer .right-items, ' +
        '.part.statusbar .right-items, ' +
        '[id="workbench.parts.statusbar"] .right-items'
    );
    if (!statusBar) {
        setTimeout(initStatusBarItem, 500);
        return;
    }

    STATE.badgeEl = document.createElement('div');
    STATE.badgeEl.id = '__autoRetryStatusItem';
    STATE.badgeEl.className = 'statusbar-item right';
    STATE.badgeEl.setAttribute('role', 'button');
    STATE.badgeEl.setAttribute('tabindex', '0');
    STATE.badgeEl.style.cssText = `
        display: inline-flex; align-items: center; gap: 4px;
        padding: 0 6px; cursor: pointer; user-select: none;
        font-size: 12px; height: 100%; line-height: 22px;
        color: var(--vscode-statusBar-foreground, #ccc);
        transition: background .15s; position: relative; overflow: hidden;
    `;

    const icon = document.createElement('span');
    icon.textContent = '↻';
    icon.style.cssText = 'font-size: 13px; line-height: 1;';

    STATE.badgeStatusEl = createStatusDot();
    STATE.badgeTextEl = document.createElement('span');
    STATE.badgeTextEl.style.cssText = 'white-space: nowrap;';

    STATE.badgeEl.appendChild(createFlashOverlay());
    STATE.badgeEl.appendChild(STATE.badgeStatusEl);
    STATE.badgeEl.appendChild(icon);
    STATE.badgeEl.appendChild(STATE.badgeTextEl);

    bindBadgeEvents(STATE.badgeEl);
    statusBar.insertBefore(STATE.badgeEl, statusBar.firstChild);
    updateBadge();
    log('[UI] Status bar item installed');
}

/**
 * Инициализация floating badge (fallback)
 */
function initFloatingBadge() {
    STATE.badgeEl = document.createElement('div');
    STATE.badgeEl.id = '__autoRetryBadge';
    STATE.badgeEl.style.cssText = `
        position:fixed; bottom:24px; right:10px; padding:3px 8px;
        border-radius:5px; font-size:10px; font-family:monospace;
        font-weight:bold; z-index:999999; cursor:pointer;
        user-select:none; color:white;
        text-shadow:0 1px 2px rgba(0,0,0,.4);
        box-shadow:0 1px 6px rgba(0,0,0,.3);
        transition:background .3s,opacity .3s; opacity:.7;
        display:flex; align-items:center; gap:5px;
    `;

    STATE.badgeStatusEl = document.createElement('span');
    STATE.badgeStatusEl.style.cssText = `
        width:6px; height:6px; border-radius:50%;
        display:inline-block; transition:background .3s;
    `;
    STATE.badgeTextEl = document.createElement('span');

    STATE.badgeEl.appendChild(createFlashOverlay());
    STATE.badgeEl.appendChild(STATE.badgeStatusEl);
    STATE.badgeEl.appendChild(STATE.badgeTextEl);

    STATE.badgeEl.addEventListener('mouseenter', () => { STATE.badgeEl.style.opacity = '1'; });
    STATE.badgeEl.addEventListener('mouseleave', () => { STATE.badgeEl.style.opacity = '.7'; });
    STATE.badgeEl.addEventListener('click', () => {
        STATE.retryActive = !STATE.retryActive;
        CONFIG.domEnabled = STATE.retryActive;
        updateBadge();
    });

    document.body.appendChild(STATE.badgeEl);
    updateBadge();
}

/**
 * Инициализация badge с fallback
 * Сначала ищет VS Code status bar, если не найден — floating badge
 */
function initBadge() {
    if (!document.body) { setTimeout(initBadge, 200); return; }

    const sb = document.querySelector(
        '.part.statusbar .right-items, ' +
        '[id="workbench.parts.statusbar"] .right-items, ' +
        'footer[id*="status"] .right-items'
    );

    if (sb) {
        initStatusBarItem();
    } else {
        let attempts = 0;
        const tryInsert = () => {
            const rightItems = document.querySelector(
                '.part.statusbar .right-items, ' +
                '[id*="statusbar"] .right-items, ' +
                'footer .right-items'
            );
            if (rightItems) {
                initStatusBarItem();
            } else if (attempts < 30) {
                attempts++;
                setTimeout(tryInsert, 1000);
            } else {
                log('[UI] Status bar not found, using floating badge');
                initFloatingBadge();
            }
        };
        tryInsert();
    }
}
