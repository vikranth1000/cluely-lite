#!/bin/bash
set -e

# Always run from repo root
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "🚀 Launching Cluely-Lite (Electron UI) from $ROOT_DIR"

# Start Ollama if not running
if ! pgrep -x "ollama" >/dev/null 2>&1; then
  echo "Starting Ollama..."
  ollama serve &
  sleep 2
fi

# Start Python server if not running or port free
if lsof -iTCP:8765 -sTCP:LISTEN -Pn >/dev/null 2>&1; then
  echo "Python server already on port 8765; skipping start"
else
  if pgrep -f "python.*server.py" >/dev/null 2>&1; then
    echo "Python server seems running already; skipping start"
  else
    echo "Starting Python server..."
    (cd python/src && CLUELY_OLLAMA_MODEL=${CLUELY_OLLAMA_MODEL:-qwen2.5:3b} python server.py &) 
    sleep 2
  fi
fi

# Build Swift AX helper (best-effort)
if [ ! -x axhelper/.build/release/axhelper ]; then
  echo "Building Swift AX helper..."
  set +e
  (cd axhelper && swift build -c release)
  STATUS=$?
  set -e
  if [ $STATUS -ne 0 ]; then
    echo "⚠️  AX helper build failed; UI will still run. You can build later with: (cd axhelper && swift build -c release)"
  fi
fi

# Start Electron
if [ ! -d electron ]; then
  echo "❌ electron/ folder missing. Ensure repo is up to date."
  exit 1
fi
cd electron
if [ ! -d node_modules ]; then
  echo "Installing Electron deps (requires internet)..."
  npm install
fi
echo "Starting Electron..."
npm start
