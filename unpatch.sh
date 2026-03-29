#!/bin/bash
echo "============================================"
echo "  Antigravity Auto-Retry UNPATCH v1.0"
echo "============================================"
echo ""

AG_DIR="/Applications/Antigravity.app/Contents/Resources/app"
WB_DIR="$AG_DIR/out/vs/code/electron-browser/workbench"
HTML_FILE="$WB_DIR/workbench-jetski-agent.html"
RETRY_JS="$WB_DIR/auto-retry.js"
PRODUCT_JSON="$AG_DIR/product.json"

# Check if patched
if ! grep -q "auto-retry.js" "$HTML_FILE" 2>/dev/null; then
    echo "[INFO] Patch not detected. Nothing to unpatch."
    exit 0
fi

echo "[1/3] Removing auto-retry.js from HTML..."
sed -i.tmp '/<script src="\.\/auto-retry\.js"><\/script>/d' "$HTML_FILE"
rm -f "$HTML_FILE.tmp"

if grep -q "auto-retry.js" "$HTML_FILE"; then
    echo "[WARNING] Could not fully clean HTML."
    echo "Try restoring backup: cp $HTML_FILE.bak $HTML_FILE"
    exit 1
fi
echo "      HTML restored."

echo "[2/3] Updating checksum in product.json..."
HASH=$(shasum -a 256 "$HTML_FILE" | awk '{print $1}' | xxd -r -p | base64)
python3 -c "
import re
with open('$PRODUCT_JSON', 'r') as f: c = f.read()
c = re.sub(r'(\"vs/code/electron-browser/workbench/workbench-jetski-agent\.html\": \")([^\"]+)(\")', r'\g<1>$HASH\g<3>', c)
with open('$PRODUCT_JSON', 'w') as f: f.write(c)
print('      Checksum:', '$HASH')
"

echo "[3/3] Removing auto-retry.js from Antigravity..."
if [ -f "$RETRY_JS" ]; then
    rm "$RETRY_JS"
    echo "      auto-retry.js removed."
else
    echo "      auto-retry.js already absent."
fi

echo ""
echo "============================================"
echo "  Unpatch complete!"
echo "  Restart Antigravity."
echo "============================================"
