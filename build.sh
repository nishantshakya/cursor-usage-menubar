#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Cursor Usage"
BUILD_DIR="$ROOT/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building Cursor Usage..."
cd "$ROOT"
swift build -c release --product CursorUsage

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/CursorUsage" "$MACOS/CursorUsage"
cp Info.plist "$CONTENTS/Info.plist"

# Icon: copy from installed Cursor IDE (not stored in this repo)
ICON_SRC=""
for candidate in \
  "/Applications/Cursor.app/Contents/Resources/Cursor.icns" \
  "$HOME/Applications/Cursor.app/Contents/Resources/Cursor.icns" \
  "$ROOT/Resources/Cursor.icns"; do
  if [[ -f "$candidate" ]]; then
    ICON_SRC="$candidate"
    break
  fi
done

if [[ -n "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RESOURCES/Cursor.icns"
else
  echo "Note: Cursor.icns not found — menu bar will use chart only until Cursor IDE is installed."
fi

echo "Built: $APP_DIR"
echo ""
echo "Install: cp -r \"$APP_DIR\" /Applications/"
echo "Or run:  open \"$APP_DIR\""
