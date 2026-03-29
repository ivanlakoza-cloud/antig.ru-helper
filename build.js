/**
 * build.js — Сборка Auto-Retry Patch
 * 
 * Конкатенирует модули из src/ в один IIFE bundle (dist/auto-retry.bundle.js).
 * Antigravity загружает скрипт как <script>, не как ES module,
 * поэтому нужен единый файл.
 * 
 * Использование: node build.js
 * 
 * @version 2.0
 */

const fs = require('fs');
const path = require('path');

const SRC_DIR = path.join(__dirname, 'src');
const DIST_DIR = path.join(__dirname, 'dist');
const OUTPUT = path.join(DIST_DIR, 'auto-retry.bundle.js');

// Порядок важен — зависимости должны быть загружены до зависимых модулей
const MODULE_ORDER = [
    'config.js',        // Конфигурация (нет зависимостей)
    'state.js',         // Состояние + логгер (зависит от config)
    'status-badge.js',  // UI badge (зависит от config, state)
    'fetch-retry.js',   // Fetch retry (зависит от config, state, badge)
    'audio-mute.js',    // Audio mute (зависит от config, state)
    'dom-clicker.js',   // DOM clicker (зависит от всех)
    'entry.js'          // Entry point + public API (зависит от всех)
];

const MAX_LINES = 300;

console.log('=== Auto-Retry Build ===\n');

// Проверка лимита строк
let hasErrors = false;
for (const file of MODULE_ORDER) {
    const filePath = path.join(SRC_DIR, file);
    if (!fs.existsSync(filePath)) {
        console.error(`[ОШИБКА] Файл не найден: ${file}`);
        hasErrors = true;
        continue;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').length;
    const status = lines > MAX_LINES ? '❌ ПРЕВЫШЕН' : '✅';
    console.log(`  ${status} ${file}: ${lines} строк`);
    if (lines > MAX_LINES) {
        console.error(`    [ОШИБКА] Превышен лимит ${MAX_LINES} строк!`);
        hasErrors = true;
    }
}

if (hasErrors) {
    console.error('\n[ОШИБКА] Сборка остановлена. Исправьте ошибки выше.');
    process.exit(1);
}

// Собираем bundle
console.log('\nСборка bundle...');

let bundle = `/**\n * Antigravity Auto-Retry Patch v3.0 — Bundle\n * Собрано: ${new Date().toISOString()}\n * Модули: ${MODULE_ORDER.join(', ')}\n */\n`;
bundle += '(function() {\n    \'use strict\';\n\n';

for (const file of MODULE_ORDER) {
    const filePath = path.join(SRC_DIR, file);
    const content = fs.readFileSync(filePath, 'utf8');
    bundle += `    // ========== ${file} ==========\n`;
    // Indent each line by 4 spaces (inside IIFE)
    const indented = content.split('\n').map(line => line ? '    ' + line : '').join('\n');
    bundle += indented + '\n\n';
}

bundle += '})();\n';

// Создаём dist/
if (!fs.existsSync(DIST_DIR)) {
    fs.mkdirSync(DIST_DIR, { recursive: true });
}

fs.writeFileSync(OUTPUT, bundle, 'utf8');

const totalLines = bundle.split('\n').length;
const totalBytes = Buffer.byteLength(bundle, 'utf8');
console.log(`\n✅ Bundle собран: ${OUTPUT}`);
console.log(`   ${totalLines} строк, ${totalBytes} байт`);
console.log('\nСледующий шаг: запустите patch.bat для применения к Antigravity');
