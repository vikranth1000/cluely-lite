#!/bin/bash

# Cluely-Lite Launch Script
# This script starts both the Python server and macOS app

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🚀 Cluely-Lite Launcher"
echo "======================="
echo ""

# Check if we're in the right directory
if [ ! -f "python/src/server.py" ]; then
    print_error "Please run this script from the cluely-lite root directory"
    exit 1
fi

# Ensure a small, efficient local model by default (override via env)
export CLUELY_OLLAMA_MODEL=${CLUELY_OLLAMA_MODEL:-qwen2.5:3b}

# Ensure Ollama is running first (to avoid fallback mode)
if ! pgrep -x "ollama" > /dev/null; then
    print_warning "Ollama is not running. Starting Ollama..."
    ollama serve &
    sleep 3
    print_success "Ollama started"
else
    print_success "Ollama is already running"
fi

# Check if Python server is already running
if pgrep -f "python.*server.py" > /dev/null; then
    print_warning "Python server is already running"
else
    print_status "Starting Python server..."
    cd python/src
    # Pass through current env (including CLUELY_OLLAMA_MODEL)
    python server.py &
    SERVER_PID=$!
    cd ../..
    
    # Wait for server to start
    sleep 3
    
    # Test if server is responding
    if curl -s http://127.0.0.1:8765/health > /dev/null; then
        print_success "Python server started successfully"
    else
        print_error "Failed to start Python server"
        exit 1
    fi
fi

print_status "Forwarding to Electron UI launcher..."
./launch_electron.sh
exit $?
