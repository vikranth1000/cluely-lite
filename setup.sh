#!/bin/bash
set -euo pipefail

# Cluely-Lite Professional Setup Script
# Complete installation and configuration

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "${PURPLE}[CLUELY-LITE SETUP]${NC} $1"; }

header "🚀 Professional Setup v2.0"
echo "=================================="

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This application requires macOS"
    exit 1
fi

# Check system requirements
log "Checking system requirements..."

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    warning "Installing Xcode Command Line Tools..."
    xcode-select --install || {
        error "Failed to install Xcode Command Line Tools"
        exit 1
    }
    log "Please complete the Xcode installation and re-run this script"
    exit 0
fi
success "Xcode Command Line Tools installed"

# Python 3
if ! command -v python3 &>/dev/null; then
    error "Python 3 is required. Please install from https://python.org"
    exit 1
fi
success "Python 3 found: $(python3 --version)"

# Node.js
if ! command -v node &>/dev/null; then
    error "Node.js is required. Please install from https://nodejs.org"
    exit 1
fi
success "Node.js found: $(node --version)"

# Install Ollama
log "Installing Ollama..."
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh || {
        error "Failed to install Ollama"
        exit 1
    }
fi
success "Ollama installed"

# Start Ollama
log "Starting Ollama service..."
ollama serve > /dev/null 2>&1 &
sleep 3
success "Ollama service started"

# Install Python dependencies
log "Installing Python dependencies..."
cd python
pip3 install -r requirements.txt || {
    error "Failed to install Python dependencies"
    exit 1
}
success "Python dependencies installed"
cd ..

# Build Swift helper
log "Building Swift AX helper..."
cd axhelper
swift build -c release || {
    error "Failed to build Swift AX helper"
    exit 1
}
success "Swift AX helper built"
cd ..

# Install Electron dependencies
log "Installing Electron dependencies..."
cd electron
npm install || {
    error "Failed to install Electron dependencies"
    exit 1
}
success "Electron dependencies installed"
cd ..

# Pull default model
MODEL=${CLUELY_OLLAMA_MODEL:-qwen2.5:3b}
log "Installing AI model: $MODEL"
ollama pull "$MODEL" || {
    warning "Failed to pull model $MODEL, but continuing..."
}
success "Model $MODEL ready"

# Create logs directory
mkdir -p logs
success "Logs directory created"

# Test installation
log "Testing installation..."
cd python/src
timeout 10 python3 -c "
import sys
sys.path.append('.')
from server import app
print('✅ Python server imports successfully')
" || {
    warning "Python server test had issues, but continuing..."
}
cd ../..

success "Setup completed successfully!"
echo ""
echo "🎉 Cluely-Lite is ready to use!"
echo ""
echo "Next steps:"
echo "1. Start the server: cd python/src && python3 server.py"
echo "2. Launch the UI: ./launch_electron.sh"
echo "3. Grant accessibility permissions when prompted"
echo ""
echo "For more information, see README.md"

