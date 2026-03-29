/**
 * token-ui.js — UI панель трекинга токенов (DOM API, без innerHTML)
 * 
 * Зависимости: config.js, state.js, token-store.js
 * @version 1.1
 */

let tokenBadgeEl = null;
let tokenPanelEl = null;
let tokenPanelVisible = false;

function formatTokenCount(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return String(n);
}

/** Хелпер: создать элемент с атрибутами и детьми */
function el(tag, style, children, attrs) {
    const e = document.createElement(tag);
    if (style) e.style.cssText = style;
    if (attrs) { for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v); }
    if (typeof children === 'string') e.textContent = children;
    else if (Array.isArray(children)) children.forEach(c => { if (c) e.appendChild(c); });
    return e;
}

function updateTokenBadge() {
    if (!tokenBadgeEl) return;
    const summary = getSessionSummary();
    const textEl = tokenBadgeEl.querySelector('.__tokenText');
    if (textEl) textEl.textContent = formatTokenCount(summary.totalTokens) + ' tok';
    tokenBadgeEl.title = 'Session: ' + summary.totalTokens.toLocaleString() + ' tokens | ' + summary.requests + ' req | Click for details';
}

function drawChart(canvas, data) {
    const ctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    const pad = { top: 10, right: 10, bottom: 20, left: 40 };
    const cW = W - pad.left - pad.right, cH = H - pad.top - pad.bottom;
    ctx.clearRect(0, 0, W, H);
    if (!data.length) {
        ctx.fillStyle = '#666'; ctx.font = '11px monospace'; ctx.textAlign = 'center';
        ctx.fillText('No data', W / 2, H / 2); return;
    }
    const maxVal = Math.max(...data.map(d => d.total), 1);
    ctx.strokeStyle = 'rgba(255,255,255,0.06)'; ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = pad.top + (cH / 4) * i;
        ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(W - pad.right, y); ctx.stroke();
    }
    ctx.fillStyle = '#888'; ctx.font = '9px monospace'; ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
        const val = maxVal - (maxVal / 4) * i;
        ctx.fillText(formatTokenCount(Math.round(val)), pad.left - 4, pad.top + (cH / 4) * i + 3);
    }
    const barW = Math.max(4, (cW / data.length) - 2);
    for (let i = 0; i < data.length; i++) {
        const x = pad.left + (cW / data.length) * i + 1;
        const inH = (data[i].in / maxVal) * cH, outH = (data[i].out / maxVal) * cH;
        ctx.fillStyle = '#3b82f6'; ctx.fillRect(x, pad.top + cH - inH - outH, barW, inH);
        ctx.fillStyle = '#22c55e'; ctx.fillRect(x, pad.top + cH - outH, barW, outH);
        if (i % Math.ceil(data.length / 7) === 0) {
            ctx.fillStyle = '#666'; ctx.font = '8px monospace'; ctx.textAlign = 'center';
            ctx.fillText(data[i].label, x + barW / 2, H - 3);
        }
    }
}

/** Построить DOM панели */
function buildPanelDOM(period) {
    const summary = getPeriodSummary(period);
    const session = getSessionSummary();
    const frag = document.createDocumentFragment();

    // Header с кнопками периодов
    const header = el('div', 'display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;');
    header.appendChild(el('span', 'font-weight:600;font-size:13px;', '\ud83d\udcca Token Usage'));
    const btnGroup = el('div', 'display:flex;gap:4px;');
    for (const p of ['today', 'week', 'month']) {
        const active = p === period;
        const btn = el('button', `padding:2px 8px;border-radius:4px;border:1px solid ${active ? '#3b82f6' : '#444'};background:${active ? '#3b82f6' : 'transparent'};color:${active ? '#fff' : '#aaa'};font-size:10px;cursor:pointer;font-family:inherit;`, p);
        btn.addEventListener('click', () => renderTokenPanel(p));
        btnGroup.appendChild(btn);
    }
    header.appendChild(btnGroup);
    frag.appendChild(header);

    // Модели
    const models = Object.entries(summary.byModel).sort((a, b) => b[1].total - a[1].total);
    if (models.length) {
        for (const [name, m] of models) {
            const pct = summary.totalTokens > 0 ? Math.round((m.total / summary.totalTokens) * 100) : 0;
            const modelDiv = el('div', 'margin:6px 0;');
            const row1 = el('div', 'display:flex;justify-content:space-between;font-size:11px;margin-bottom:2px;');
            row1.appendChild(el('span', 'color:#e2e8f0;font-weight:500;', name));
            row1.appendChild(el('span', 'color:#94a3b8;', m.requests + ' req'));
            modelDiv.appendChild(row1);
            const barBg = el('div', 'background:#1e293b;border-radius:3px;height:6px;overflow:hidden;');
            barBg.appendChild(el('div', 'width:' + pct + '%;height:100%;background:linear-gradient(90deg,#3b82f6,#8b5cf6);border-radius:3px;transition:width .3s;'));
            modelDiv.appendChild(barBg);
            const stats = el('div', 'display:flex;gap:12px;font-size:10px;color:#64748b;margin-top:2px;');
            stats.appendChild(el('span', '', 'In: ' + formatTokenCount(m.in)));
            stats.appendChild(el('span', '', 'Out: ' + formatTokenCount(m.out)));
            if (m.think) stats.appendChild(el('span', '', 'Think: ' + formatTokenCount(m.think)));
            stats.appendChild(el('span', 'color:#94a3b8;', formatTokenCount(m.total) + ' total'));
            modelDiv.appendChild(stats);
            frag.appendChild(modelDiv);
        }
    } else {
        frag.appendChild(el('div', 'color:#64748b;font-size:11px;text-align:center;padding:12px;', 'No data for this period'));
    }

    // График
    const chartSection = el('div', 'margin-top:8px;border-top:1px solid #1e293b;padding-top:8px;');
    const legend = el('div', 'font-size:10px;color:#64748b;margin-bottom:4px;');
    const blueSquare = el('span', 'color:#3b82f6;', '\u25a0');
    legend.appendChild(blueSquare); legend.appendChild(document.createTextNode(' input '));
    const greenSquare = el('span', 'color:#22c55e;margin-left:8px;', '\u25a0');
    legend.appendChild(greenSquare); legend.appendChild(document.createTextNode(' output'));
    chartSection.appendChild(legend);
    const canvas = document.createElement('canvas');
    canvas.width = 300; canvas.height = 100;
    canvas.style.cssText = 'width:100%;height:100px;';
    canvas.id = '__tokenChart';
    chartSection.appendChild(canvas);
    frag.appendChild(chartSection);

    // Footer
    const footer = el('div', 'margin-top:8px;border-top:1px solid #1e293b;padding-top:6px;display:flex;justify-content:space-between;font-size:10px;color:#64748b;');
    footer.appendChild(el('span', '', 'Session: ' + formatTokenCount(session.totalTokens) + ' | ' + session.requests + ' req'));
    footer.appendChild(el('span', '', summary.errors ? '\u26a0\ufe0f ' + summary.errors + ' err' : '\u2705'));
    frag.appendChild(footer);

    return { frag, canvas, period };
}

function toggleTokenPanel() {
    if (tokenPanelVisible) {
        if (tokenPanelEl) tokenPanelEl.style.display = 'none';
        tokenPanelVisible = false;
        return;
    }
    if (!tokenPanelEl) {
        tokenPanelEl = document.createElement('div');
        tokenPanelEl.id = '__tokenPanel';
        tokenPanelEl.style.cssText = 'position:fixed;bottom:28px;right:10px;width:320px;background:#0f172a;border:1px solid #1e293b;border-radius:8px;padding:12px;z-index:999999;box-shadow:0 8px 32px rgba(0,0,0,.5);font-family:system-ui,sans-serif;color:#e2e8f0;max-height:420px;overflow-y:auto;';
        document.body.appendChild(tokenPanelEl);
    }
    renderTokenPanel('today');
    tokenPanelEl.style.display = 'block';
    tokenPanelVisible = true;
}

function renderTokenPanel(period) {
    if (!tokenPanelEl) return;
    while (tokenPanelEl.firstChild) tokenPanelEl.removeChild(tokenPanelEl.firstChild);
    const { frag, canvas } = buildPanelDOM(period);
    tokenPanelEl.appendChild(frag);
    if (canvas) {
        const gran = period === 'today' ? 'hours' : 'days';
        const count = period === 'today' ? 24 : period === 'week' ? 7 : 30;
        drawChart(canvas, getChartData(gran, count));
    }
}

function initTokenBadge() {
    if (!document.body) { setTimeout(initTokenBadge, 300); return; }
    const findStatusBar = () => {
        const sb = document.querySelector('.part.statusbar .right-items, [id*="statusbar"] .right-items, footer .right-items');
        if (!sb) { setTimeout(findStatusBar, 1000); return; }

        tokenBadgeEl = document.createElement('div');
        tokenBadgeEl.id = '__tokenBadge';
        tokenBadgeEl.className = 'statusbar-item right';
        tokenBadgeEl.setAttribute('role', 'button');
        tokenBadgeEl.style.cssText = 'display:inline-flex;align-items:center;gap:3px;padding:0 6px;cursor:pointer;user-select:none;font-size:11px;height:100%;line-height:22px;color:var(--vscode-statusBar-foreground, #94a3b8);transition:background .15s;position:relative;';
        const icon = el('span', 'font-size:12px;', '\ud83d\udcca');
        const text = el('span', 'white-space:nowrap;', '0 tok');
        text.className = '__tokenText';
        tokenBadgeEl.appendChild(icon);
        tokenBadgeEl.appendChild(text);
        tokenBadgeEl.addEventListener('mouseenter', () => { tokenBadgeEl.style.background = 'rgba(255,255,255,.1)'; });
        tokenBadgeEl.addEventListener('mouseleave', () => { tokenBadgeEl.style.background = 'transparent'; });
        tokenBadgeEl.addEventListener('click', toggleTokenPanel);
        const retryBadge = document.getElementById('__autoRetryStatusItem');
        if (retryBadge && retryBadge.nextSibling) sb.insertBefore(tokenBadgeEl, retryBadge.nextSibling);
        else sb.insertBefore(tokenBadgeEl, sb.firstChild);
        updateTokenBadge();
        setInterval(updateTokenBadge, 5000);
        log('[TOKENS] Badge installed in status bar');
    };
    findStatusBar();
    document.addEventListener('click', (e) => {
        if (tokenPanelVisible && tokenPanelEl && tokenBadgeEl && !tokenPanelEl.contains(e.target) && !tokenBadgeEl.contains(e.target)) toggleTokenPanel();
    });
}
