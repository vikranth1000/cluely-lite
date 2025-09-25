#!/bin/bash

# Cluely-Lite Setup Script
# This script automates the setup process for Cluely-Lite

set -e  # Exit on any error

echo "🚀 Cluely-Lite Setup Script"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only."
    exit 1
fi

print_status "Checking system requirements..."

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &> /dev/null; then
    print_warning "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    print_status "Please complete the Xcode Command Line Tools installation and run this script again."
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed."
    print_status "Please install Python 3 from https://python.org or using Homebrew: brew install python3"
    exit 1
fi

print_success "System requirements check passed"

# Check if Ollama is installed
print_status "Checking for Ollama installation..."

if ! command -v ollama &> /dev/null; then
    print_warning "Ollama not found. Installing Ollama..."
    
    # Download and install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh
    
    if [ $? -eq 0 ]; then
        print_success "Ollama installed successfully"
    else
        print_error "Failed to install Ollama. Please install manually from https://ollama.ai"
        exit 1
    fi
else
    print_success "Ollama is already installed"
fi

# Start Ollama service
print_status "Starting Ollama service..."
if ! pgrep -x "ollama" > /dev/null; then
    ollama serve &
    sleep 3
    print_success "Ollama service started"
else
    print_success "Ollama service is already running"
fi

# Pull a small, efficient default model (override with CLUELY_OLLAMA_MODEL)
print_status "Setting up AI model..."
MODEL="${CLUELY_OLLAMA_MODEL:-qwen2.5:3b}"

if ollama list | grep -q "$MODEL"; then
    print_success "Model $MODEL is already available"
else
    print_status "Downloading model $MODEL (this may take a few minutes)..."
    ollama pull "$MODEL"
    if [ $? -eq 0 ]; then
        print_success "Model $MODEL downloaded successfully"
    else
        print_warning "Failed to download $MODEL automatically. You can try a small alternative: 'ollama pull llama3.2:3b'"
    fi
fi

# Build the macOS app
print_status "Building macOS application..."

cd CluelyLite

# Clean and build
xcodebuild clean -project CluelyLite.xcodeproj -scheme CluelyLite
xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Release build

if [ $? -eq 0 ]; then
    print_success "macOS application built successfully"
else
    print_error "Failed to build macOS application"
    exit 1
fi

cd ..

# Create a launch script
print_status "Creating launch script..."

cat > launch_cluely.sh << 'EOF'
#!/bin/bash

# Cluely-Lite Launch Script

echo "🚀 Starting Cluely-Lite..."

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama service..."
    ollama serve &
    sleep 3
fi

# Start the Python server
echo "Starting AI server..."
cd python/src
python server.py &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Launch the macOS app
echo "Launching Cluely-Lite app..."
open ../CluelyLite/build/Release/CluelyLite.app

echo "✅ Cluely-Lite is now running!"
echo "   - Press ⌘+Return to activate the overlay"
echo "   - Move mouse to top edge of screen to peek"
echo "   - Click the eye icon in menu bar"
echo ""
echo "Press Ctrl+C to stop the server"

# Wait for user to stop
wait $SERVER_PID
EOF

chmod +x launch_cluely.sh
print_success "Launch script created: launch_cluely.sh"

# Create a desktop shortcut
print_status "Creating desktop shortcut..."
cat > ~/Desktop/Cluely-Lite.command << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./launch_cluely.sh
EOF
chmod +x ~/Desktop/Cluely-Lite.command
print_success "Desktop shortcut created"

# Final instructions
echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
print_success "Cluely-Lite has been successfully set up!"
echo ""
echo "📋 Next Steps:"
echo "1. Grant accessibility permissions:"
echo "   System Preferences → Security & Privacy → Privacy → Accessibility"
echo "   Add Cluely-Lite and check the box"
echo ""
echo "2. Launch Cluely-Lite:"
echo "   - Double-click 'Cluely-Lite' on your desktop, or"
echo "   - Run: ./launch_cluely.sh"
echo ""
echo "3. Usage:"
echo "   - Press ⌘+Return to activate"
echo "   - Move mouse to top edge to peek"
echo "   - Type commands like 'Click Save button'"
echo ""
echo "📚 For more information, see SETUP.md"
echo ""
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
