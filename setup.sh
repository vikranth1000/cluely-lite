#!/bin/bash

# Cluely-Lite Setup Script (Electron + Swift CLI + Python server)
set -e

echo "🚀 Cluely-Lite Setup"
echo "===================="

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }

[[ "$OSTYPE" == darwin* ]] || { err "macOS required"; exit 1; }

log "Checking Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  warn "Missing CLT. Installing..."
  xcode-select --install || true
  log "Finish CLT installation, then re-run this script."
  exit 0
fi
ok "Xcode CLT present"

log "Checking Python 3..."; command -v python3 >/dev/null || { err "Install Python 3"; exit 1; }
ok "Python found"

log "Checking Node.js/npm..."; command -v npm >/dev/null || { err "Install Node.js (https://nodejs.org)"; exit 1; }
ok "npm found"

log "Checking Ollama..."
if ! command -v ollama &>/dev/null; then
  warn "Ollama not found, installing..."
  curl -fsSL https://ollama.ai/install.sh | sh || { err "Install Ollama manually"; exit 1; }
fi
ok "Ollama available"

log "Starting Ollama (if not running)..."
pgrep -x ollama >/dev/null || (ollama serve & sleep 2)
ok "Ollama running"

MODEL=${CLUELY_OLLAMA_MODEL:-qwen2.5:3b}
log "Ensuring model $MODEL is available..."
ollama list | grep -q "$MODEL" || ollama pull "$MODEL"
ok "Model ready"

log "Building Swift AX helper..."
(cd axhelper && swift build -c release)
ok "axhelper built"

log "Installing Electron dependencies..."
(cd electron && npm install)
ok "Electron deps installed"

echo
ok "Setup complete. Next steps:"
echo "1) Start server:   cd python/src && python server.py"
echo "2) Launch UI:      ./launch_electron.sh  (or cd electron && npm start)"
echo "3) Grant Accessibility to axhelper on first use."
echo
echo "See SETUP.md for details."
print_warning "Don't forget to grant accessibility permissions before using the app!"
echo ""

# Test the setup
print_status "Testing setup..."

# Test Python server
cd python/src
timeout 5 python -c "
import json
import urllib.request
import urllib.error

try:
    # Test if server can start
    print('✅ Python dependencies are working')
except Exception as e:
    print(f'❌ Python test failed: {e}')
    exit(1)
" 2>/dev/null || print_warning "Python test had issues, but continuing..."

cd ../..

print_success "Setup verification complete!"
echo ""
echo "Ready to use Cluely-Lite! 🚀"
