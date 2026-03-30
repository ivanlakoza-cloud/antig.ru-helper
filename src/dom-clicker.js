/**
 * dom-clicker.js — Level 4: DOM Auto-Click
 * 
 * Автоматический поиск и клик кнопок "Try again" / "Retry" в DOM.
 * Три стратегии поиска:
 *   1. querySelector (buttons + role=button)
 *   2. spans внутри кнопок
 *   3. XPath текстовых нод
 * 
 * Два механизма детекции:
 *   - MutationObserver (реактивный)
 *   - Periodic scan (проактивный)
 * 
 * Зависимости: config.js, state.js, status-badge.js, audio-mute.js
 * 
 * @version 2.1
 */

/**
 * Инициализация DOM auto-click
 * Ожидает готовности document.body
 */
function initDomClicker() {
    if (!CONFIG.domEnabled) return;

    const doInit = () => {
        if (!document.body) { setTimeout(doInit, 200); return; }

        const pendingClicks = new Map();

        /**
         * Поиск кнопок retry в DOM (3 стратегии)
         * @returns {Element[]} Найденные кликабельные элементы
         */
        function findRetryElements() {
            const found = [];
            if (!document.body) return found;

            // Стратегия 1: buttons и role=button
            const btns = document.body.querySelectorAll('button, [role="button"]');
            for (const b of btns) {
                const t = (b.textContent || '').trim().toLowerCase();
                if (CONFIG.retryButtonTexts.some(p => t === p) && !clickedElements.has(b)) {
                    found.push(b);
                }
            }

            // Стратегия 2: spans внутри кнопок
            const spans = document.body.querySelectorAll('span');
            for (const s of spans) {
                const t = (s.textContent || '').trim().toLowerCase();
                if (!CONFIG.retryButtonTexts.some(p => t === p)) continue;
                if (clickedElements.has(s)) continue;
                const parent = s.closest('button, [role="button"], a');
                if (parent && !clickedElements.has(parent) && !found.includes(parent)) {
                    found.push(parent);
                }
            }

            // Стратегия 3: XPath
            try {
                const xp = "//text()[normalize-space()='Try again' or normalize-space()='Retry' or normalize-space()='Run']";
                const res = document.evaluate(xp, document.body, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                for (let i = 0; i < res.snapshotLength; i++) {
                    let el = res.snapshotItem(i).parentElement;
                    if (!el || clickedElements.has(el)) continue;
                    const c = el.closest('button, [role="button"]') || el;
                    if (!found.includes(c) && !clickedElements.has(c)) found.push(c);
                }
            } catch(e) {}

            return found;
        }

        /**
         * Скрыть текст ошибки в UI (визуальное подавление)
         * @param {Element} retryEl - Элемент кнопки retry
         */
        function hideErrorNotification(retryEl) {
            if (!CONFIG.hideErrorNotifications) return;
            try {
                let container = retryEl;
                for (let i = 0; i < 10 && container; i++) {
                    const text = (container.textContent || '').toLowerCase();
                    if (CONFIG.errorTexts.some(p => text.includes(p)) && container.parentElement) {
                        const msgs = container.querySelectorAll('p, span, div');
                        for (const m of msgs) {
                            const mt = (m.textContent || '').toLowerCase();
                            if (CONFIG.errorTexts.some(p => mt.includes(p)) && m.children.length === 0) {
                                m.style.opacity = '0.15';
                                m.style.fontSize = '0';
                                m.style.height = '0';
                                m.style.overflow = 'hidden';
                                m.style.transition = 'all 0.2s';
                                log('[HIDE] Hidden error message element');
                            }
                        }
                        break;
                    }
                    container = container.parentElement;
                }
            } catch(e) {}
        }

        /**
         * Запланировать клик по элементу с задержкой и cooldown
         * @param {Element} element - Элемент для клика
         */
        function scheduleClick(element) {
            const target = element.closest('button, [role="button"]') || element;
            if (pendingClicks.has(target) || clickedElements.has(target)) return;
            if (STATE.clickCount >= CONFIG.domMaxClicks) return;
            if (!STATE.retryActive) return;

            // Don't auto-click in background windows (prevents focus stealing)
            if (!document.hasFocus() && !document.hidden) return;

            const now = Date.now();
            const delay = Math.max(CONFIG.domClickDelay, CONFIG.domCooldown - (now - STATE.lastClickTime));

            log(`[DOM] Retry button found. Click in ${delay}ms (${STATE.clickCount + 1}/${CONFIG.domMaxClicks})`);

            // Подавить звуки на 10 секунд
            if (window.__autoRetry_mute) window.__autoRetry_mute(10000);

            // Скрыть текст ошибки
            hideErrorNotification(target);

            const tid = setTimeout(() => {
                pendingClicks.delete(target);
                if (!document.contains(target) || clickedElements.has(target)) return;

                // Re-check: don't steal focus from other windows
                if (!document.hasFocus()) return;

                STATE.clickCount++;
                STATE.lastClickTime = Date.now();
                clickedElements.add(target);
                clickedElements.add(element);

                log(`[DOM] Auto-click! "${target.textContent?.trim()}" (${STATE.clickCount}/${CONFIG.domMaxClicks})`);
                flashBadge('Auto-retry...', '#d97706', 2000);
                
                // Use dispatchEvent instead of .click() to avoid focus stealing
                target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));

                clearTimeout(STATE.resetTimer);
                STATE.resetTimer = setTimeout(() => {
                    STATE.clickCount = 0;
                    log('[DOM] Click count reset');
                }, CONFIG.domResetTimeout);
            }, delay);

            pendingClicks.set(target, tid);
        }

        // MutationObserver — реактивная детекция
        new MutationObserver((mutations) => {
            if (!STATE.retryActive) return;
            for (const m of mutations) {
                for (const node of m.addedNodes) {
                    if (node.nodeType !== 1) continue;
                    const t = (node.textContent || '').toLowerCase();
                    if (!CONFIG.retryButtonTexts.some(p => t.includes(p))) continue;
                    const btns = node.querySelectorAll ? node.querySelectorAll('button, [role="button"], span') : [];
                    for (const b of btns) {
                        const bt = (b.textContent || '').trim().toLowerCase();
                        if (CONFIG.retryButtonTexts.some(p => bt === p) && !clickedElements.has(b)) {
                            scheduleClick(b);
                        }
                    }
                }
            }
        }).observe(document.body, { childList: true, subtree: true });

        // Periodic scan — проактивная детекция
        setInterval(() => {
            if (!STATE.retryActive || STATE.clickCount >= CONFIG.domMaxClicks) return;
            const els = findRetryElements();
            for (const el of els) scheduleClick(el);
        }, CONFIG.domScanInterval);

        log('[DOM] Observer + scan active. Delay:', CONFIG.domClickDelay + 'ms');
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', doInit);
    } else {
        doInit();
    }
}
