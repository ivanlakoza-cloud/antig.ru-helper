/**
 * token-parser.js — Парсинг usageMetadata из Connect protocol
 * 
 * Извлекает данные о потреблении токенов из Connect RPC стримов.
 * Парсит length-prefixed фреймы, ищет usageMetadata в последнем фрейме (flag=0x02).
 * Также извлекает model ID из URL запроса.
 * 
 * Зависимости: config.js, state.js
 * 
 * @version 1.0
 */

/**
 * Извлечь model ID из URL запроса
 * @param {string} url - URL fetch запроса
 * @returns {string} Model ID или 'unknown'
 */
function extractModelFromUrl(url) {
    if (!url) return 'unknown';
    const str = typeof url === 'string' ? url : url.toString();

    // Паттерны URL Antigravity/Gemini:
    // .../models/gemini-2.5-pro:streamGenerateContent
    // .../models/gemini-2.5-flash:generateContent
    const modelMatch = str.match(/models\/([^:/?]+)/);
    if (modelMatch) return modelMatch[1];

    // Fallback: ищем известные имена моделей в URL
    const knownModels = [
        'gemini-2.5-pro', 'gemini-2.5-flash', 'gemini-2.0-pro',
        'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash',
        'claude-opus', 'claude-sonnet', 'claude-haiku'
    ];
    for (const m of knownModels) {
        if (str.includes(m)) return m;
    }

    return 'unknown';
}

/**
 * Извлечь model из тела запроса (JSON/protobuf)
 * @param {Request|Object} request - Fetch request
 * @returns {Promise<string|null>} Model ID или null
 */
async function extractModelFromBody(request) {
    try {
        if (!request || !request.clone) return null;
        const clone = request.clone();
        const text = await clone.text();
        if (!text) return null;

        // JSON body: { "model": "gemini-2.5-pro", ... }
        const modelMatch = text.match(/"model"\s*:\s*"([^"]+)"/);
        if (modelMatch) return modelMatch[1];
    } catch (e) {}
    return null;
}

/**
 * Парсить ВСЕ Connect protocol фреймы из ArrayBuffer
 * @param {Uint8Array} data - Raw bytes ответа
 * @returns {Array<{flag: number, payload: Uint8Array}>} Массив фреймов
 */
function parseConnectFrames(data) {
    const frames = [];
    let offset = 0;

    while (offset + 5 <= data.length) {
        const flag = data[offset];
        const length = (data[offset + 1] << 24) |
                       (data[offset + 2] << 16) |
                       (data[offset + 3] << 8) |
                       data[offset + 4];

        if (length < 0 || offset + 5 + length > data.length) break;

        frames.push({
            flag,
            payload: data.slice(offset + 5, offset + 5 + length)
        });
        offset += 5 + length;
    }

    return frames;
}

/**
 * Извлечь usageMetadata из Connect stream response
 * Клонирует response, читает всё тело, парсит фреймы.
 * 
 * @param {Response} response - Fetch Response (НЕ клон — клонируем внутри)
 * @returns {Promise<{promptTokens: number, outputTokens: number, totalTokens: number, thinkTokens: number, cachedTokens: number}|null>}
 */
async function extractTokenUsage(response) {
    try {
        const ct = (response.headers.get('content-type') || '');
        if (!ct.includes('connect') && !ct.includes('grpc') && !ct.includes('proto')) {
            return null;
        }
        if (!response.body) return null;

        const clone = response.clone();
        const buffer = await clone.arrayBuffer();
        const data = new Uint8Array(buffer);

        if (data.length < 5) return null;

        const frames = parseConnectFrames(data);

        // Ищем ПОСЛЕДНИЙ end-of-stream фрейм (flag & 0x02)
        let endStreamJson = null;
        for (let i = frames.length - 1; i >= 0; i--) {
            if (frames[i].flag & 0x02) {
                try {
                    const text = new TextDecoder().decode(frames[i].payload);
                    endStreamJson = JSON.parse(text);
                    break;
                } catch (e) {}
            }
        }

        if (!endStreamJson) {
            // Fallback: ищем usageMetadata в любом data-фрейме (последнем)
            for (let i = frames.length - 1; i >= 0; i--) {
                try {
                    const text = new TextDecoder().decode(frames[i].payload);
                    if (text.includes('usageMetadata') || text.includes('usage_metadata')) {
                        endStreamJson = JSON.parse(text);
                        break;
                    }
                } catch (e) {}
            }
        }

        if (!endStreamJson) return null;

        // Ищем usageMetadata в разных форматах (camelCase и snake_case)
        const usage = endStreamJson.usageMetadata ||
                      endStreamJson.usage_metadata ||
                      endStreamJson.metadata?.usageMetadata ||
                      endStreamJson.metadata?.usage_metadata ||
                      null;

        if (!usage) return null;

        return {
            promptTokens: usage.promptTokenCount || usage.prompt_token_count || 0,
            outputTokens: usage.candidatesTokenCount || usage.candidates_token_count || 0,
            totalTokens: usage.totalTokenCount || usage.total_token_count || 0,
            thinkTokens: usage.thoughtsTokenCount || usage.thoughts_token_count || 0,
            cachedTokens: usage.cachedContentTokenCount || usage.cached_content_token_count || 0
        };

    } catch (e) {
        // Не удалось распарсить — не критично
        return null;
    }
}
