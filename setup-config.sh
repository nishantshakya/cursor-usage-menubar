#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.cursor-usage"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXAMPLE="$(cd "$(dirname "$0")" && pwd)/config.example.json"

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  echo "Config already exists: $CONFIG_FILE"
  exit 0
fi

cp "$EXAMPLE" "$CONFIG_FILE"
echo "Created $CONFIG_FILE (optional — only refreshIntervalMinutes is configurable)"
echo ""
echo "Auth is automatic from Cursor IDE — just sign in to Cursor desktop app."
