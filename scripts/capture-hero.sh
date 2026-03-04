#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PORT="${PORT:-8765}"
VIEWPORT="${VIEWPORT:-1600,1200}"
WAIT_MS="${WAIT_MS:-1200}"
TMP_DIR="$ROOT_DIR/.tmp/capture-hero"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required."
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required."
  exit 1
fi

echo "Ensuring Playwright Chromium runtime is available..."
npx --yes playwright install chromium >/dev/null

if lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "Port $PORT is already in use. Re-run with a free port, e.g. PORT=8766 ./scripts/capture-hero.sh"
  exit 1
fi

mkdir -p "$TMP_DIR" "$ROOT_DIR/assets"

python3 -m http.server "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!

sleep 1

cat > "$TMP_DIR/storage-dark.json" <<JSON
{"cookies":[],"origins":[{"origin":"http://127.0.0.1:${PORT}","localStorage":[{"name":"preferred-mode","value":"dark"}]}]}
JSON

cat > "$TMP_DIR/storage-light.json" <<JSON
{"cookies":[],"origins":[{"origin":"http://127.0.0.1:${PORT}","localStorage":[{"name":"preferred-mode","value":"light"}]}]}
JSON

npx --yes playwright screenshot \
  --browser chromium \
  --viewport-size "$VIEWPORT" \
  --wait-for-timeout "$WAIT_MS" \
  --load-storage "$TMP_DIR/storage-dark.json" \
  "http://127.0.0.1:${PORT}/index.html#home" \
  "$ROOT_DIR/assets/hero-dark.jpg"

npx --yes playwright screenshot \
  --browser chromium \
  --viewport-size "$VIEWPORT" \
  --wait-for-timeout "$WAIT_MS" \
  --load-storage "$TMP_DIR/storage-light.json" \
  "http://127.0.0.1:${PORT}/index.html#home" \
  "$ROOT_DIR/assets/hero-light.jpg"

echo "Updated:"
ls -lh "$ROOT_DIR/assets/hero-dark.jpg" "$ROOT_DIR/assets/hero-light.jpg"
