#!/bin/bash

# Exit on any error
set -e

# 0. Safety Check
if [[ ! -f "package.json" ]] || [[ ! $(pwd) == *"tuxedo-control-center"* ]]; then
    echo "Error: This script must be run from the tuxedo-control-center root directory."
    exit 1
fi

# 1. Clean everything
echo "--- Cleaning project environment ---"
rm -rf node_modules/
rm -f package-lock.json
rm -rf dist/
rm -rf build/
echo "Clean complete."

# 2. Install dependencies (Automated)
echo "--- Installing dependencies with legacy-peer-deps ---"
npm install --legacy-peer-deps

# --- FIX: Downgrade @types/ms to stay compatible with Angular 10's TypeScript version ---
echo "--- Patching @types/ms for TS compatibility ---"
npm install @types/ms@0.7.31 --save-dev --save-exact --legacy-peer-deps

# 3. Set environment and Build
echo "--- Building project ---"
export NODE_OPTIONS=--openssl-legacy-provider
npm run build

# 4. Define paths
SOURCE_BIN="./dist/tuxedo-control-center/data/service/tccd"
DEST_BIN="/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/service/tccd"

if [ ! -f "$SOURCE_BIN" ]; then
    echo "Error: Compiled binary not found at $SOURCE_BIN"
    exit 1
fi

# 5. Stop and Replace
echo "--- Updating TCCD Binary ---"
if systemctl is-active --quiet tccd; then
    sudo systemctl stop tccd
fi

echo "Copying new binary to /opt..."
sudo cp "$SOURCE_BIN" "$DEST_BIN"

# 6. Verification
echo "Verifying checksums..."
SHA_SRC=$(sha1sum "$SOURCE_BIN" | awk '{print $1}')
SHA_DEST=$(sha1sum "$DEST_BIN" | awk '{print $1}')

if [ "$SHA_SRC" == "$SHA_DEST" ]; then
    echo "Check: Success. Binaries match ($SHA_SRC)."
else
    echo "Check: Failure. Binaries do not match!"
    exit 1
fi

sync

# 7. Start and Status
echo "--- Restarting Service ---"
sudo systemctl start tccd

# Wait half a second for the service to settle
sleep 0.5

sudo systemctl status tccd --no-pager
