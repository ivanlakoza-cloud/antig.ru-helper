#!/bin/bash
set -e

echo "╔══════════════════════════════════════╗"
echo "║   AntiG.ru Helper - Install v4.2    ║"
echo "║   No dependencies required          ║"
echo "╚══════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"
BUNDLE="$DIST_DIR/auto-retry.bundle.js"

MODULES=(config.js state.js status-badge.js fetch-retry.js audio-mute.js dom-clicker.js entry.js)
MAX_LINES=300

# ===== Verify source files =====
MISSING=0
for m in "${MODULES[@]}"; do
    if [ ! -f "$SRC_DIR/$m" ]; then
        echo "[ERROR] Source file missing: src/$m"
        MISSING=1
    fi
done
[ "$MISSING" = "1" ] && exit 1

# ===== Auto-detect Antigravity =====
AG_DIR=""
if [ -d "/Applications/Antigravity.app/Contents/Resources/app" ]; then
    AG_DIR="/Applications/Antigravity.app/Contents/Resources/app"
fi
if [ -z "$AG_DIR" ]; then
    for d in \
        "$HOME/.local/share/antigravity/resources/app" \
        "/usr/share/antigravity/resources/app" \
        "/opt/antigravity/resources/app" \
        "/usr/local/share/antigravity/resources/app" \
        "/snap/antigravity/current/resources/app"; do
        if [ -f "$d/product.json" ]; then
            AG_DIR="$d"
            break
        fi
    done
fi
if [ -z "$AG_DIR" ]; then
    echo "[ERROR] Antigravity not found!"
    read -p "Enter path to resources/app: " AG_DIR
    [ ! -f "$AG_DIR/product.json" ] && echo "[ERROR] Not found." && exit 1
fi

echo "[OK] Antigravity: $AG_DIR"

WB_DIR="$AG_DIR/out/vs/code/electron-browser/workbench"
HTML_MAIN="$WB_DIR/workbench.html"
HTML_JETSKI="$WB_DIR/workbench-jetski-agent.html"
RETRY_JS="$WB_DIR/auto-retry.js"
PRODUCT_JSON="$AG_DIR/product.json"

# ===== Detect if sudo is needed =====
SUDO=""
if [ ! -w "$WB_DIR" ]; then
    echo ""
    echo "[INFO] Write access required. Requesting sudo..."
    SUDO="sudo"
    sudo -v || { echo "[ERROR] sudo required."; exit 1; }
fi

# ===== Helper functions =====
inject_html() {
    local html_file="$1"
    local name="$(basename "$html_file")"
    
    if [ ! -f "$html_file" ]; then
        echo "      $name - not found, skipping"
        return 0
    fi
    
    if grep -q "auto-retry.js" "$html_file" 2>/dev/null; then
        echo "      $name - already patched"
        return 0
    fi
    
    # Backup
    $SUDO cp "$html_file" "$html_file.bak"
    
    local TAG='<script src="./auto-retry.js"></script>'
    local TARGET='<script src="./jetskiAgent.js" type="module"></script>'
    
    if grep -q "$TARGET" "$html_file"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            $SUDO sed -i '' "s|$TARGET|$TAG\\
$TARGET|" "$html_file"
        else
            $SUDO sed -i "s|$TARGET|$TAG\n$TARGET|" "$html_file"
        fi
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            $SUDO sed -i '' "s|</head>|$TAG\\
</head>|" "$html_file"
        else
            $SUDO sed -i "s|</head>|$TAG\n</head>|" "$html_file"
        fi
    fi
    
    if grep -q "auto-retry.js" "$html_file"; then
        echo "      $name - OK"
    else
        echo "      $name - FAILED"
        $SUDO cp "$html_file.bak" "$html_file"
        return 1
    fi
}

update_checksum() {
    local html_file="$1"
    local name="$(basename "$html_file")"
    local key=""
    
    [ ! -f "$html_file" ] && return 0
    
    case "$name" in
        "workbench.html")
            key="vs/code/electron-browser/workbench/workbench.html"
            ;;
        "workbench-jetski-agent.html")
            key="vs/code/electron-browser/workbench/workbench-jetski-agent.html"
            ;;
        *) return 0 ;;
    esac
    
    # Compute SHA256 base64
    local HASH=""
    if command -v shasum &>/dev/null; then
        HASH=$(shasum -a 256 "$html_file" | awk '{print $1}' | xxd -r -p | base64)
    elif command -v sha256sum &>/dev/null; then
        HASH=$(sha256sum "$html_file" | awk '{print $1}' | xxd -r -p | base64)
    else
        echo "      [ERROR] No SHA256 tool"
        return 1
    fi
    
    # Update product.json via temp file
    local TMPJSON=$(mktemp)
    cp "$PRODUCT_JSON" "$TMPJSON"
    
    if command -v python3 &>/dev/null; then
        python3 -c "
import re
with open('$TMPJSON', 'r') as f: c = f.read()
c = re.sub(r'(\"$key\": \")([^\"]+)(\")', r'\g<1>$HASH\g<3>', c)
with open('$TMPJSON', 'w') as f: f.write(c)
"
    elif command -v sed &>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|\"$key\": \"[^\"]*\"|\"$key\": \"$HASH\"|" "$TMPJSON"
        else
            sed -i "s|\"$key\": \"[^\"]*\"|\"$key\": \"$HASH\"|" "$TMPJSON"
        fi
    fi
    
    $SUDO cp "$TMPJSON" "$PRODUCT_JSON"
    rm -f "$TMPJSON"
    echo "      $name - $HASH"
}

# ===== Step 1: Build bundle =====
echo ""
echo "[1/4] Building bundle..."
mkdir -p "$DIST_DIR"

HAS_ERROR=0
for m in "${MODULES[@]}"; do
    LINES=$(wc -l < "$SRC_DIR/$m")
    [ "$LINES" -gt "$MAX_LINES" ] && echo "[ERROR] $m: $LINES lines" && HAS_ERROR=1
done
[ "$HAS_ERROR" = "1" ] && exit 1

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S.000Z")
{
    echo "/**"
    echo " * Antigravity Auto-Retry Patch v3.0 — Bundle"
    echo " * Built: $TIMESTAMP"
    echo " * Modules: $(IFS=', '; echo "${MODULES[*]}")"
    echo " */"
    echo "(function() {"
    echo "    'use strict';"
    echo ""
    for m in "${MODULES[@]}"; do
        echo "    // ========== $m =========="
        while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] && echo "    $line" || echo ""
        done < "$SRC_DIR/$m"
        echo ""
    done
    echo "})();"
} > "$BUNDLE"

TOTAL_LINES=$(wc -l < "$BUNDLE")
TOTAL_BYTES=$(wc -c < "$BUNDLE")
echo "      OK: $TOTAL_LINES lines, $TOTAL_BYTES bytes"

# ===== Step 2: Copy bundle =====
echo "[2/4] Copying to Antigravity..."
$SUDO cp "$BUNDLE" "$RETRY_JS"
echo "      Done."

# ===== Step 3: Inject into BOTH HTML files =====
echo "[3/4] Injecting patch..."
$SUDO cp "$PRODUCT_JSON" "$PRODUCT_JSON.bak" 2>/dev/null || true
inject_html "$HTML_MAIN"
inject_html "$HTML_JETSKI"

# ===== Step 4: Update checksums =====
echo "[4/4] Updating checksums..."
update_checksum "$HTML_MAIN"
update_checksum "$HTML_JETSKI"

# ===== Verify =====
echo ""
echo "  Verifying..."
VERIFY=1
[ ! -f "$RETRY_JS" ] && echo "  [FAIL] auto-retry.js missing" && VERIFY=0
if [ -f "$HTML_MAIN" ]; then
    grep -q "auto-retry.js" "$HTML_MAIN" || { echo "  [FAIL] workbench.html not patched"; VERIFY=0; }
fi
[ "$VERIFY" = "1" ] && echo "  [OK] All checks passed!"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    Installation complete!            ║"
echo "╚══════════════════════════════════════╝"
echo ""
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  macOS: if blocked, go to System Settings"
    echo "  → Privacy & Security → Open Anyway"
    echo ""
fi
echo "  Logs: DevTools (Cmd+Shift+I / Ctrl+Shift+I)"
echo "  API:  window.__autoRetry"
