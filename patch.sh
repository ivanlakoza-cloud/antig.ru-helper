#!/bin/bash
echo "============================================"
echo "  Antigravity Auto-Retry Patcher v2.0"
echo "============================================"
echo ""

# macOS paths
AG_DIR="/Applications/Antigravity.app/Contents/Resources/app"
WB_DIR="$AG_DIR/out/vs/code/electron-browser/workbench"
HTML_FILE="$WB_DIR/workbench-jetski-agent.html"
RETRY_JS="$WB_DIR/auto-retry.js"
PRODUCT_JSON="$AG_DIR/product.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$SCRIPT_DIR/dist/auto-retry.bundle.js"

# Check Antigravity installation
if [ ! -d "$AG_DIR" ]; then
    echo "[ERROR] Antigravity not found at $AG_DIR"
    echo "        If installed elsewhere, edit AG_DIR in this script."
    exit 1
fi

# Build if needed
if [ ! -f "$BUNDLE" ]; then
    echo "[INFO] Bundle not found. Building..."
    node "$SCRIPT_DIR/build.js"
    if [ ! -f "$BUNDLE" ]; then
        echo "[ERROR] Build failed!"
        exit 1
    fi
fi

# Copy bundle
echo "[1/4] Copying bundle to Antigravity..."
cp "$BUNDLE" "$RETRY_JS"
echo "      Done."

# Check if already patched
if grep -q "auto-retry.js" "$HTML_FILE" 2>/dev/null; then
    echo "[2/4] Patch already applied to HTML. Skipping."
else
    # Backup
    echo "[2/4] Creating backups..."
    cp "$HTML_FILE" "$HTML_FILE.bak"
    cp "$PRODUCT_JSON" "$PRODUCT_JSON.bak"
    echo "      Backups created."

    # Inject script tag
    echo "[3/4] Injecting auto-retry.js into HTML..."
    sed -i.tmp 's|<script src="./jetskiAgent.js" type="module"></script>|<script src="./auto-retry.js"></script>\n<script src="./jetskiAgent.js" type="module"></script>|' "$HTML_FILE"
    rm -f "$HTML_FILE.tmp"

    if grep -q "auto-retry.js" "$HTML_FILE"; then
        echo "      HTML patched."
    else
        echo "[ERROR] Failed to inject script!"
        cp "$HTML_FILE.bak" "$HTML_FILE"
        exit 1
    fi
fi

# Update checksum
echo "[4/4] Updating checksum in product.json..."
HASH=$(shasum -a 256 "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
python3 -c "
import re, sys
with open('$PRODUCT_JSON', 'r') as f: c = f.read()
c = re.sub(r'(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', r'\g<1>$HASH\g<3>', c)
with open('$PRODUCT_JSON', 'w') as f: f.write(c)
print('      Checksum:', '$HASH')
"

echo ""
echo "============================================"
echo "  Patch applied successfully!"
echo "  Restart Antigravity to activate."
echo "============================================"
echo ""
echo "Logs: DevTools (Cmd+Shift+I) - Console"
echo "API: window.__autoRetry"

