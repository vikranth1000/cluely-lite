# Cluely-Lite 🤖

A **local, privacy-focused AI desktop assistant** for macOS that can see and interact with your screen using accessibility APIs and local AI models.

![Cluely-Lite Demo](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.0-orange) ![Python](https://img.shields.io/badge/Python-3.8+-green) ![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local-brightgreen)

## ✨ Features

- **🎯 On-demand activation** - No continuous monitoring, only works when you invoke it
- **🔒 100% Local** - All AI processing happens on your machine using Ollama
- **👁️ Screen awareness** - Uses macOS Accessibility APIs to understand your screen
- **⚡ Quick access** - Press `⌘+Return` or hover at top edge to activate
- **🛡️ Safety first** - Confirmation required for destructive actions
- **🎨 Beautiful UI** - Native macOS design with translucent overlay
- **🔧 Highly configurable** - Customizable models, hotkeys, and behavior

## 🚀 Quick Start

### 1. Install Ollama
```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve
ollama pull phi4:mini
```

### 2. Run Setup Script
```bash
git clone <your-repo-url>
cd cluely-lite
chmod +x setup.sh
./setup.sh
```

### 3. Grant Permissions
- **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
- Add Cluely-Lite and check the box

### 4. Launch
```bash
./launch_cluely.sh
```

## 📖 Usage

### Basic Commands
- **Press `⌘+Return`** or **hover at top edge** to activate
- Type natural language commands:
  - "Click the Save button"
  - "Type 'Hello World' in the search box"
  - "Focus on the username field"
  - "What's on my screen right now?"
- When a potentially destructive action is detected you'll see a prompt—type `confirm` to proceed or `cancel` to abort.
- The overlay stays as a tiny pill at the top; hover your cursor to expand it or press the hotkey to interact.

### Available Actions
- **`answer`** - Provide text responses
- **`click`** - Click UI elements
- **`type`** - Type text into input fields
- **`focus`** - Focus on specific elements

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   macOS App     │    │  Python Server   │    │   Ollama AI     │
│                 │    │                  │    │                 │
│ • SwiftUI UI    │◄──►│ • HTTP Server    │◄──►│ • Local LLM     │
│ • Accessibility │    │ • Action Planner │    │ • Tool Planning │
│ • Hotkey Mgmt   │    │ • JSON Parser    │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🔧 Configuration

### Environment Variables
```bash
# Use different AI model
export CLUELY_OLLAMA_MODEL="llama3.2:3b"

# Use different Ollama server
export CLUELY_OLLAMA_URL="http://localhost:11434/api/generate"

# Enable debug mode
export CLUELY_DEBUG=1
```

### Recommended Models
- **`phi4:mini`** - Fastest, ~2GB RAM, good for basic tasks
- **`llama3.2:3b`** - Balanced performance, ~3GB RAM
- **`qwen2.5:3b`** - Excellent for complex tasks, ~3GB RAM

## 🛠️ Development

### Project Structure
```
cluely-lite/
├── CluelyLite/              # macOS Swift app
│   ├── CluelyLiteApp.swift  # Main app entry point
│   ├── OverlayView.swift    # UI overlay
│   ├── AgentClient.swift    # HTTP client
│   └── Accessibility*.swift # Screen interaction
├── python/src/              # Python AI server
│   └── server.py           # HTTP server & AI logic
├── setup.sh                # Automated setup
├── test_server.py          # Server testing
└── SETUP.md               # Detailed setup guide
```

### Building from Source
```bash
# Build macOS app
cd CluelyLite
xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Release build

# Start Python server
cd python/src
python server.py
```

### Testing
```bash
# Test the server
python test_server.py

# Test with curl
curl -X POST http://127.0.0.1:8765/command \
  -H "Content-Type: application/json" \
  -d '{"instruction":"Click Save button"}'
```

## 🔒 Privacy & Security

- **✅ 100% Local Processing** - No data leaves your machine
- **✅ No Telemetry** - No usage tracking or analytics
- **✅ Open Source** - Full source code available for review
- **✅ Minimal Permissions** - Only requests necessary accessibility access
- **✅ No Cloud Dependencies** - Works completely offline

## 🐛 Troubleshooting

### Common Issues

**"Accessibility permissions required"**
- Grant permissions in System Preferences → Security & Privacy → Privacy → Accessibility

**"Ollama not detected"**
- Start Ollama: `ollama serve`
- Check model: `ollama list`
- Verify URL in server logs

**"Agent HTTP error"**
- Ensure Python server is running on port 8765
- Check firewall settings
- Review server logs

**App doesn't respond to hotkeys**
- Grant accessibility permissions
- Restart the app
- Check for conflicting hotkeys

### Debug Mode
```bash
# Enable debug logging
export CLUELY_DEBUG=1
python python/src/server.py
```

### Performance Tips
1. Use smaller models for faster responses
2. Close unnecessary applications
3. Use specific, clear instructions
4. Ensure adequate RAM (4GB+ recommended)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Setup
```bash
# Clone and setup
git clone <your-fork>
cd cluely-lite
./setup.sh

# Run in development mode
cd python/src
python server.py &
cd ../../CluelyLite
xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Debug build
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Ollama** - For providing excellent local LLM infrastructure
- **macOS Accessibility APIs** - For enabling screen interaction
- **SwiftUI** - For the beautiful native UI
- **Python** - For the robust server implementation

## 📞 Support

- 📖 **Documentation**: See [SETUP.md](SETUP.md) for detailed setup
- 🐛 **Issues**: Report bugs on GitHub Issues
- 💬 **Discussions**: Join GitHub Discussions for questions
- 📧 **Contact**: [Your contact information]

---

**Made with ❤️ for privacy-conscious macOS users**

*Cluely-Lite: Your local AI assistant that respects your privacy.*