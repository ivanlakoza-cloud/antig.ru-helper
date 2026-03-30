#!/bin/bash
echo "============================================"
echo "  Antigravity Auto-Retry UNPATCH"
echo "============================================"
echo ""

# ===== Auto-detect Antigravity =====
AG_DIR=""
if [ -d "/Applications/Antigravity.app/Contents/Resources/app" ]; then
    AG_DIR="/Applications/Antigravity.app/Contents/Resources/app"
fi
if [ -z "$AG_DIR" ]; then
    for d in \
        "$HOME/.local/share/antigravity/resources/app" \
        "/usr/share/antigravity/resources/app" \
        "/opt/antigravity/resources/app"; do
        if [ -f "$d/product.json" ]; then
            AG_DIR="$d"
            break
        fi
    done
fi
if [ -z "$AG_DIR" ]; then
    echo "[ERROR] Antigravity not found."
    read -p "Enter path to resources/app: " AG_DIR
fi

WB_DIR="$AG_DIR/out/vs/code/electron-browser/workbench"
HTML_FILE="$WB_DIR/workbench-jetski-agent.html"
RETRY_JS="$WB_DIR/auto-retry.js"
PRODUCT_JSON="$AG_DIR/product.json"

# Check if patched
if ! grep -q "auto-retry.js" "$HTML_FILE" 2>/dev/null; then
    echo "[INFO] Patch not detected. Nothing to unpatch."
    exit 0
fi

# Detect if sudo is needed
SUDO=""
if [ ! -w "$WB_DIR" ]; then
    echo "[INFO] Write access required. Requesting sudo..."
    SUDO="sudo"
    sudo -v || { echo "[ERROR] sudo required."; exit 1; }
fi

echo "[1/3] Removing auto-retry.js from HTML..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    $SUDO sed -i '' '/<script src="\.\/auto-retry\.js"><\/script>/d' "$HTML_FILE"
else
    $SUDO sed -i '/<script src="\.\/auto-retry\.js"><\/script>/d' "$HTML_FILE"
fi

if grep -q "auto-retry.js" "$HTML_FILE"; then
    echo "[WARNING] Could not fully clean HTML."
    echo "Try: $SUDO cp $HTML_FILE.bak $HTML_FILE"
    exit 1
fi
echo "      HTML restored."

echo "[2/3] Updating checksum..."
if command -v shasum &>/dev/null; then
    HASH=$(shasum -a 256 "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
elif command -v sha256sum &>/dev/null; then
    HASH=$(sha256sum "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
else
    echo "[ERROR] No SHA256 tool found"
    exit 1
fi

TMPJSON=$(mktemp)
cp "$PRODUCT_JSON" "$TMPJSON"
if command -v python3 &>/dev/null; then
    python3 -c "
import re
with open('$TMPJSON', 'r') as f: c = f.read()
c = re.sub(r'(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', r'\g<1>$HASH\g<3>', c)
with open('$TMPJSON', 'w') as f: f.write(c)
"
elif command -v sed &>/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"[^\"]*\"|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"$HASH\"|" "$TMPJSON"
    else
        sed -i "s|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"[^\"]*\"|\"vs/code/electron-browser/workbench/workbench-jetski-agent.html\": \"$HASH\"|" "$TMPJSON"
    fi
fi
$SUDO cp "$TMPJSON" "$PRODUCT_JSON"
rm -f "$TMPJSON"
echo "      Checksum: $HASH"

echo "[3/3] Removing auto-retry.js..."
if [ -f "$RETRY_JS" ]; then
    $SUDO rm "$RETRY_JS"
    echo "      Removed."
else
    echo "      Already absent."
fi

echo ""
echo "============================================"
echo "  Unpatch complete!"
echo "  Restart Antigravity."
echo "============================================"
