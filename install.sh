#!/usr/bin/env bash
# Rebuild, install, and relaunch. Must quit the running app so the new binary loads.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Cursor Usage"
APP_PATH="/Applications/${APP_NAME}.app"

echo "Stopping ${APP_NAME} if running..."
pkill -x CursorUsage 2>/dev/null || true
sleep 0.5

"$ROOT/build.sh"

echo "Installing to /Applications..."
rm -rf "$APP_PATH"
cp -R "$ROOT/.build/${APP_NAME}.app" "$APP_PATH"

echo "Launching..."
open -a "$APP_NAME"

echo "Done. Click the menu bar item — you should see a Today section with spend in dollars."
