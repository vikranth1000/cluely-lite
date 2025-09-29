#!/bin/bash
set -euo pipefail

# Cluely-Lite Professional Launch Script
# Ensures all components are ready and launches the application

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "${PURPLE}[CLUELY-LITE]${NC} $1"; }

# Get script directory
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

header "🚀 Starting Cluely-Lite v2.0"
echo "=================================="

# Check system requirements
log "Checking system requirements..."

# Check macOS version
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This application requires macOS"
    exit 1
fi

MACOS_VERSION=$(sw_vers -productVersion)
REQUIRED_VERSION="14.0"
if ! [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$MACOS_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]]; then
    error "macOS 14.0+ required (current: $MACOS_VERSION)"
    exit 1
fi
success "macOS version: $MACOS_VERSION"

# Check Python
if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not installed"
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
success "Python version: $PYTHON_VERSION"

# Check Node.js
if ! command -v node &> /dev/null; then
    error "Node.js is required but not installed"
    exit 1
fi
NODE_VERSION=$(node --version)
success "Node.js version: $NODE_VERSION"

# Check Ollama
if ! command -v ollama &> /dev/null; then
    warning "Ollama not found. Installing..."
    curl -fsSL https://ollama.ai/install.sh | sh || {
        error "Failed to install Ollama. Please install manually from https://ollama.ai"
        exit 1
    }
fi
success "Ollama found"

# Start Ollama if not running
log "Starting Ollama service..."
if ! pgrep -x "ollama" >/dev/null 2>&1; then
    log "Starting Ollama daemon..."
    ollama serve > /dev/null 2>&1 &
    sleep 3
fi

# Check if Ollama is responding
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    warning "Ollama not responding. Starting in background..."
    ollama serve > /dev/null 2>&1 &
    sleep 5
fi

# Ensure model is available
MODEL=${CLUELY_OLLAMA_MODEL:-qwen2.5:3b}
log "Ensuring model '$MODEL' is available..."
if ! ollama list | grep -q "$MODEL"; then
    log "Pulling model '$MODEL'..."
    ollama pull "$MODEL" || {
        error "Failed to pull model '$MODEL'"
        exit 1
    }
fi
success "Model '$MODEL' ready"

# Build Swift AX helper
log "Building Swift AX helper..."
cd axhelper
if ! swift build -c release; then
    error "Failed to build Swift AX helper"
    exit 1
fi
success "AX helper built successfully"
cd ..

# Install Python dependencies
log "Installing Python dependencies..."
cd python
if ! pip3 install -r requirements.txt; then
    error "Failed to install Python dependencies"
    exit 1
fi
success "Python dependencies installed"
cd ..

# Install Electron dependencies
log "Installing Electron dependencies..."
cd electron
if ! npm install; then
    error "Failed to install Electron dependencies"
    exit 1
fi
success "Electron dependencies installed"

# Check if Python server is already running
log "Checking Python server status..."
if lsof -iTCP:8765 -sTCP:LISTEN >/dev/null 2>&1; then
    warning "Python server already running on port 8765"
else
    log "Starting Python server..."
    cd ../python/src
    python3 server.py > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    # Check if server started successfully
    if ! curl -s http://127.0.0.1:8765/health >/dev/null 2>&1; then
        error "Failed to start Python server"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    success "Python server started (PID: $SERVER_PID)"
    cd ../..
fi

# Start Electron UI
log "Starting Electron UI..."
cd electron
success "Launching Cluely-Lite UI..."

# Set environment variables
export NODE_ENV=production

# Start the application
exec npm start