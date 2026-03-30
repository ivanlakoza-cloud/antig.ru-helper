#!/bin/bash
set -e

echo "╔══════════════════════════════════════╗"
echo "║   AntiG.ru Helper - Install v4.0    ║"
echo "║   No dependencies required          ║"
echo "╚══════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"
BUNDLE="$DIST_DIR/auto-retry.bundle.js"

# Module order (dependencies first)
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
if [ "$MISSING" = "1" ]; then
    echo ""
    echo "  Source files not found. Ensure you're running from project root."
    exit 1
fi

# ===== Auto-detect Antigravity =====
AG_DIR=""

# macOS
if [ -d "/Applications/Antigravity.app/Contents/Resources/app" ]; then
    AG_DIR="/Applications/Antigravity.app/Contents/Resources/app"
fi

# Linux standard paths
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
    echo ""
    echo "  Checked:"
    echo "    - /Applications/Antigravity.app (macOS)"
    echo "    - ~/.local/share/antigravity (Linux)"
    echo "    - /usr/share/antigravity"
    echo "    - /opt/antigravity"
    echo ""
    read -p "Enter path to Antigravity resources/app: " AG_DIR
    if [ ! -f "$AG_DIR/product.json" ]; then
        echo "[ERROR] product.json not found at that path."
        exit 1
    fi
fi

echo "[OK] Antigravity: $AG_DIR"

WB_DIR="$AG_DIR/out/vs/code/electron-browser/workbench"
HTML_FILE="$WB_DIR/workbench-jetski-agent.html"
RETRY_JS="$WB_DIR/auto-retry.js"
PRODUCT_JSON="$AG_DIR/product.json"

if [ ! -f "$HTML_FILE" ]; then
    echo "[ERROR] Workbench HTML not found: $HTML_FILE"
    exit 1
fi

# ===== Step 1: Build bundle (pure bash, no Node.js) =====
echo ""
echo "[1/4] Building bundle..."

mkdir -p "$DIST_DIR"

# Check line limits
HAS_ERROR=0
for m in "${MODULES[@]}"; do
    LINES=$(wc -l < "$SRC_DIR/$m")
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        echo "[ERROR] $m exceeds $MAX_LINES lines ($LINES)"
        HAS_ERROR=1
    fi
done
if [ "$HAS_ERROR" = "1" ]; then
    echo "[ERROR] Build stopped."
    exit 1
fi

# Build IIFE bundle
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
            if [ -n "$line" ]; then
                echo "    $line"
            else
                echo ""
            fi
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
cp "$BUNDLE" "$RETRY_JS"
echo "      Done."

# ===== Step 3: Inject script tag =====
if grep -q "auto-retry.js" "$HTML_FILE" 2>/dev/null; then
    echo "[3/4] Patch already in HTML. Updating bundle only."
else
    echo "[3/4] Installing patch..."
    cp "$HTML_FILE" "$HTML_FILE.bak"
    cp "$PRODUCT_JSON" "$PRODUCT_JSON.bak"
    echo "      Backups created."

    TARGET='<script src="./jetskiAgent.js" type="module"></script>'
    TAG='<script src="./auto-retry.js"></script>'

    if grep -q "$TARGET" "$HTML_FILE"; then
        # Use sed to inject before jetskiAgent.js
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|$TARGET|$TAG\\
$TARGET|" "$HTML_FILE"
        else
            sed -i "s|$TARGET|$TAG\n$TARGET|" "$HTML_FILE"
        fi
        echo "      Script tag injected."
    else
        echo "[WARN] Target script tag not found. Trying alternative..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|</head>|$TAG\\
</head>|" "$HTML_FILE"
        else
            sed -i "s|</head>|$TAG\n</head>|" "$HTML_FILE"
        fi
        echo "      Injected before </head>."
    fi

    # Verify
    if ! grep -q "auto-retry.js" "$HTML_FILE"; then
        echo "[ERROR] Injection failed!"
        cp "$HTML_FILE.bak" "$HTML_FILE"
        echo "      Backup restored."
        exit 1
    fi
fi

# ===== Step 4: Update checksum =====
echo "[4/4] Updating checksum..."

# Compute SHA256 base64 hash
if command -v shasum &>/dev/null; then
    # macOS / BSD
    HASH=$(shasum -a 256 "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
elif command -v sha256sum &>/dev/null; then
    # Linux
    HASH=$(sha256sum "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
else
    echo "[ERROR] No SHA256 tool found (shasum/sha256sum)"
    exit 1
fi

# Update product.json using python3 (available on macOS and most Linux)
if command -v python3 &>/dev/null; then
    python3 -c "
import re
with open('$PRODUCT_JSON', 'r') as f: c = f.read()
c = re.sub(r'(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', r'\g<1>$HASH\g<3>', c)
with open('$PRODUCT_JSON', 'w') as f: f.write(c)
print('      Checksum:', '$HASH')
"
elif command -v perl &>/dev/null; then
    perl -i -pe "s|(\"vs/code/electron-browser/workbench/workbench-jetski-agent\\.html\": \")[^\"]+(\")|\${1}${HASH}\${2}|" "$PRODUCT_JSON"
    echo "      Checksum: $HASH"
elif command -v sed &>/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"[^\"]*\"|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"$HASH\"|" "$PRODUCT_JSON"
    else
        sed -i "s|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"[^\"]*\"|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"$HASH\"|" "$PRODUCT_JSON"
    fi
    echo "      Checksum: $HASH"
else
    echo "[ERROR] No tool to update JSON (python3/perl/sed not found)"
    exit 1
fi

# ===== Verification =====
echo ""
echo "  Verifying installation..."
VERIFY=1
if [ ! -f "$RETRY_JS" ]; then
    echo "  [FAIL] auto-retry.js not in workbench"
    VERIFY=0
fi
if ! grep -q "auto-retry.js" "$HTML_FILE"; then
    echo "  [FAIL] Script tag not in HTML"
    VERIFY=0
fi
if [ "$VERIFY" = "1" ]; then
    echo "  [OK] All checks passed!"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    Installation complete!            ║"
echo "║    Restart Antigravity to activate.  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Features:"
echo "    ⚡ Auto-retry on errors 429/502/503"
echo "    🔄 Auto-click Try again / Retry / Run"
echo "    🔇 Error sound muting"
echo "    📊 Status bar badge"
echo ""
echo "  Logs: DevTools (Cmd+Shift+I / Ctrl+Shift+I)"
echo "  API:  window.__autoRetry"
