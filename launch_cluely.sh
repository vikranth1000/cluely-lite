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
if [ ! -f "python/src/server.py" ] || [ ! -d "CluelyLite" ]; then
    print_error "Please run this script from the cluely-lite root directory"
    exit 1
fi

# Check if Python server is already running
if pgrep -f "python.*server.py" > /dev/null; then
    print_warning "Python server is already running"
else
    print_status "Starting Python server..."
    cd python/src
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

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
    print_warning "Ollama is not running. Starting Ollama..."
    ollama serve &
    sleep 3
    print_success "Ollama started"
else
    print_success "Ollama is already running"
fi

# Build the app if needed
if [ ! -f "CluelyLite/build/Release/CluelyLite.app/Contents/MacOS/CluelyLite" ]; then
    print_status "Building macOS application..."
    cd CluelyLite
    xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Release build
    cd ..
    print_success "macOS application built"
fi

# Launch the macOS app
print_status "Launching Cluely-Lite app..."
open CluelyLite/build/Release/CluelyLite.app

print_success "Cluely-Lite is now running!"
echo ""
echo "📋 Usage Instructions:"
echo "  • Press ⌘+Return to activate the overlay"
echo "  • Move mouse to top edge of screen to peek"
echo "  • Click the eye icon in menu bar"
echo "  • Type commands like 'Click Save button'"
echo ""
echo "🔧 Troubleshooting:"
echo "  • Grant accessibility permissions in System Preferences"
echo "  • Check server status: curl http://127.0.0.1:8765/health"
echo "  • View logs: tail -f python/src/server.log"
echo ""
print_warning "Don't forget to grant accessibility permissions!"
echo ""

# Keep the script running to show status
echo "Press Ctrl+C to stop the server and exit"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    print_status "Shutting down..."
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
    fi
    print_success "Cluely-Lite stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Wait for user to stop
wait
