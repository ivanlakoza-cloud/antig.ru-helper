/**
 * audio-mute.js — Level 3: Подавление звуков ошибок
 * 
 * Monkey-patch HTMLAudioElement.play() для подавления
 * звуковых нотификаций во время retry.
 * 
 * Зависимости: config.js, state.js
 * 
 * @version 2.1
 */

/** Время до которого звуки подавлены (timestamp) */
let muteUntil = 0;

/**
 * Включить подавление звуков на указанную длительность
 * @param {number} [durationMs=10000] - Длительность подавления в ms
 */
function muteAudio(durationMs) {
    muteUntil = Date.now() + (durationMs || 10000);
}

/**
 * Инициализация audio muting
 * Патчит HTMLAudioElement.prototype.play
 */
function initAudioMute() {
    if (!CONFIG.muteErrorSounds) return;

    const origPlay = HTMLAudioElement.prototype.play;

    // Экспорт функции mute для других модулей
    window.__autoRetry_mute = muteAudio;

    HTMLAudioElement.prototype.play = function() {
        if (Date.now() < muteUntil) {
            log('[MUTE] Suppressed notification sound');
            return Promise.resolve();
        }
        return origPlay.apply(this, arguments);
    };

    log('[MUTE] Audio suppression active.');
}
