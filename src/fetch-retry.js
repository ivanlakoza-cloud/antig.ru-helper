/**
 * fetch-retry.js — Level 1 + Level 2: Fetch Monkey-Patch
 * 
 * Level 1: HTTP status retry (429/502/503/520/522/524)
 * Level 2: Connect stream body interception (HTTP 200 + error in body)
 * 
 * Зависимости: config.js, state.js, status-badge.js
 * 
 * @version 2.1
 */

const originalFetch = window.fetch;

/**
 * Проверяет тело ответа на Connect protocol ошибки
 * Клонирует response, читает первый chunk, парсит length-prefixed фреймы
 * 
 * @param {Response} response - Fetch Response объект
 * @returns {Promise<{code: string, message: string}|null>} Ошибка или null
 */
async function peekConnectError(response) {
    try {
        const ct = (response.headers.get('content-type') || '');
        if (!ct.includes('connect') && !ct.includes('grpc')) return null;
        if (!response.body) return null;

        const clone = response.clone();
        const reader = clone.body.getReader();
        const { value, done } = await reader.read();
        reader.cancel();

        if (!value || value.length < 5 || done) return null;

        const flags = value[0];
        // 0x02 = end-of-stream marker (Connect protocol)
        if (!(flags & 0x02)) return null;

        const length = (value[1] << 24) | (value[2] << 16) | (value[3] << 8) | value[4];
        if (length <= 0 || value.length < 5 + length) return null;

        const json = new TextDecoder().decode(value.slice(5, 5 + length));
        const endStream = JSON.parse(json);

        if (endStream.error) {
            const code = (endStream.error.code || '').toLowerCase().replace(/ /g, '_');
            const shouldRetry = CONFIG.connectRetryCodeNames.includes(code);
            if (shouldRetry) {
                return { code, message: endStream.error.message || code };
            }
        }
    } catch (e) {
        // Can't parse — not an error or not our format
    }
    return null;
}

/**
 * Асинхронно извлечь и сохранить данные о токенах (не блокирует response)
 * @param {Response} response - Исходный Response (будет склонирован)
 * @param {string} url - URL запроса
 * @param {number} startTime - Время начала запроса
 * @param {string} status - 'ok' | 'retry'
 */
function trackTokenUsage(response, url, startTime, status) {
    // Запускаем асинхронно, не блокируя возврат response
    extractTokenUsage(response).then(usage => {
        if (!usage || usage.totalTokens === 0) return;
        const model = extractModelFromUrl(url);
        addTokenRecord({
            model,
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            thinkTokens: usage.thinkTokens,
            cachedTokens: usage.cachedTokens,
            totalTokens: usage.totalTokens,
            duration: Date.now() - startTime,
            status
        });
        updateTokenBadge();
    }).catch(() => {});
}

/**
 * Инициализация fetch monkey-patch
 * Заменяет window.fetch на обёртку с retry логикой + трекинг токенов
 */
function initFetchRetry() {
    window.fetch = async function(...args) {
        if (!STATE.retryActive) return originalFetch.apply(this, args);

        const requestUrl = args[0]?.url || args[0] || '';
        const startTime = Date.now();
        let lastError = null;

        for (let attempt = 0; attempt <= CONFIG.fetchMaxRetries; attempt++) {
            try {
                const response = await originalFetch.apply(this, args);

                // Level 1: HTTP status retry
                if (CONFIG.fetchRetryStatuses.includes(response.status) && attempt < CONFIG.fetchMaxRetries) {
                    const delay = retryDelay(attempt);
                    STATE.fetchRetryCount++;
                    log(`[FETCH] HTTP ${response.status}. Retry ${attempt + 1}/${CONFIG.fetchMaxRetries} in ${Math.round(delay / 1000)}s`);
                    flashBadge(`Retry ${attempt + 1}...`, '#d97706', 3000);
                    await new Promise(r => setTimeout(r, delay));
                    continue;
                }

                // Level 2: Connect stream body error detection
                if (response.status === 200 && attempt < CONFIG.fetchMaxRetries) {
                    const err = await peekConnectError(response);
                    if (err) {
                        const delay = retryDelay(attempt);
                        STATE.streamRetryCount++;
                        log(`[STREAM] Connect error: ${err.code} "${err.message}". Retry ${attempt + 1}/${CONFIG.fetchMaxRetries} in ${Math.round(delay / 1000)}s`);
                        flashBadge(`Stream retry ${attempt + 1}...`, '#dc2626', 3000);
                        try { response.body.cancel(); } catch(e) {}
                        await new Promise(r => setTimeout(r, delay));
                        continue;
                    }
                }

                if (attempt > 0) {
                    log(`[FETCH] Success after ${attempt} retries!`);
                    flashBadge('Retry OK!', '#16a34a', 3000);
                }

                // Token tracking (async — не блокирует return)
                trackTokenUsage(response, requestUrl, startTime, attempt > 0 ? 'retry' : 'ok');

                return response;

            } catch (error) {
                lastError = error;
                if (error.name === 'AbortError') throw error;
                if (attempt < CONFIG.fetchMaxRetries) {
                    const delay = retryDelay(attempt);
                    STATE.fetchRetryCount++;
                    warn(`[FETCH] Error: ${error.message}. Retry ${attempt + 1}/${CONFIG.fetchMaxRetries} in ${Math.round(delay / 1000)}s`);
                    flashBadge(`Net error retry ${attempt + 1}...`, '#d97706', 3000);
                    await new Promise(r => setTimeout(r, delay));
                    continue;
                }
                throw error;
            }
        }
        throw lastError || new Error('Max retries exceeded');
    };

    log('[FETCH] Monkey-patch active. Retry on HTTP:', CONFIG.fetchRetryStatuses.join(', '));
    log('[STREAM] Connect body interception active.');
    log('[TOKENS] Token tracking integrated.');
}
