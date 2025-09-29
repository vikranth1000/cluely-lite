# Cluely-Lite v2.0 🚀

**Professional Local AI Assistant for macOS**

Cluely-Lite is a powerful, privacy-focused desktop automation assistant that runs entirely on your Mac. Built with modern architecture and professional-grade code quality, it provides seamless AI-powered automation without any cloud dependencies.

## ✨ Features

### 🤖 **AI-Powered Automation**
- **100% Local**: All AI processing happens on your Mac using Ollama
- **No Cloud Dependencies**: Complete privacy and offline operation
- **Multiple Models**: Support for various local LLM models
- **Real-time Processing**: Fast response times with professional error handling

### 🖥️ **Modern Desktop Interface**
- **Floating Pill UI**: Minimal, always-accessible interface
- **Professional Design**: Modern, accessible, and responsive design
- **Keyboard Shortcuts**: Cmd+\ to toggle, Enter to send, Escape to close
- **Resizable Interface**: Drag to resize width and height
- **Dark Theme**: Beautiful dark theme with proper contrast

### 🔧 **Desktop Automation**
- **UI Snapshot**: Capture and analyze current screen elements
- **Click Automation**: Click any UI element by description
- **Text Input**: Type text into any field
- **Focus Control**: Focus and interact with UI elements
- **Accessibility Integration**: Full macOS Accessibility API support

### 🛡️ **Security & Privacy**
- **Local-First**: No data leaves your machine
- **Secure Architecture**: Proper input validation and error handling
- **Rate Limiting**: Built-in protection against abuse
- **CORS Protection**: Secure cross-origin request handling

## 🏗️ **Architecture**

```
┌─────────────────┐   ┌──────────────────┐   ┌──────────────┐   ┌──────────────┐
│ Electron UI     │──►│ FastAPI Server   │──►│ Ollama LLM   │   │ Swift AX     │
│ • Modern UI     │   │ • Professional   │   │ • Local AI   │   │ • macOS AX   │
│ • State Mgmt    │   │ • Rate Limiting  │   │ • Multiple   │   │ • Automation │
│ • Error Handling│   │ • Logging        │   │   Models     │   │ • CLI Tool   │
└─────────────────┘   └──────────────────┘   └──────────────┘   └──────────────┘
```

## 🚀 **Quick Start**

### Prerequisites
- **macOS 14.0+** (Sequoia or later)
- **Python 3.9+** with pip
- **Node.js 18+** with npm
- **Xcode Command Line Tools** (for Swift compilation)
- **Ollama** (local LLM runtime)

### Installation

1. **Install Ollama and a model:**
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ollama serve
   ollama pull qwen2.5:3b
   ```

2. **Clone and setup:**
   ```bash
   git clone <your-repo-url>
   cd cluely-lite
   ```

3. **Install Python dependencies:**
   ```bash
   cd python
   pip install -r requirements.txt
   ```

4. **Build Swift helper:**
   ```bash
   cd ../axhelper
   swift build -c release
   ```

5. **Install Electron dependencies:**
   ```bash
   cd ../electron
   npm install
   ```

### Running

1. **Start the Python server:**
   ```bash
   cd python/src
   python server.py
   ```

2. **Launch the Electron UI:**
   ```bash
   cd ../../electron
   npm start
   ```

3. **Or use the convenience script:**
   ```bash
   ./launch_electron.sh
   ```

## 🎯 **Usage**

### Basic Commands
- **Toggle UI**: `Cmd + \`
- **Send Message**: Type and press `Enter`
- **Close Panel**: Press `Escape`
- **Toggle Tools**: `Ctrl + Enter`

### Automation Tools
- **Snapshot**: Capture current UI elements
- **Click**: Click any element by description
- **Focus**: Focus on any element
- **Type**: Type text into any field

### Example Workflows
```
"Take a screenshot of this page"
"Click the Save button"
"Type 'Hello World' into the search box"
"Focus on the email field and type my email"
```

## ⚙️ **Configuration**

### Environment Variables
```bash
export CLUELY_OLLAMA_MODEL="qwen2.5:3b"        # AI model
export CLUELY_OLLAMA_URL="http://127.0.0.1:11434/api/generate"
export CLUELY_HOST="127.0.0.1"                 # Server host
export CLUELY_PORT="8765"                      # Server port
export CLUELY_LOG_LEVEL="INFO"                 # Logging level
```

### Configuration File
Edit `config.json` for advanced settings:
```json
{
  "server": {
    "host": "127.0.0.1",
    "port": 8765,
    "max_requests_per_minute": 60
  },
  "ollama": {
    "model": "qwen2.5:3b",
    "temperature": 0.7,
    "max_tokens": 1024
  },
  "electron": {
    "width": 420,
    "height": 120
  }
}
```

## 🔧 **Development**

### Project Structure
```
cluely-lite/
├── python/                 # FastAPI server
│   ├── src/
│   │   ├── server.py      # Main server
│   │   ├── config.py      # Configuration
│   │   ├── models.py      # Pydantic models
│   │   └── logger.py      # Logging setup
│   └── requirements.txt   # Python dependencies
├── electron/              # Electron UI
│   ├── src/
│   │   ├── app.js        # Main app class
│   │   └── preload.js    # Preload script
│   ├── renderer/
│   │   ├── index.html    # UI template
│   │   ├── app.js        # UI controller
│   │   └── styles.css    # Professional styles
│   └── package.json      # Electron config
├── axhelper/             # Swift CLI
│   ├── Sources/AXHelper/
│   │   └── main.swift    # AX automation
│   └── Package.swift     # Swift config
├── config.json           # Global config
└── launch_electron.sh    # Launch script
```

### Development Commands
```bash
# Python server
cd python/src
python server.py

# Electron UI (development)
cd electron
npm run dev

# Build Swift helper
cd axhelper
swift build -c release

# Build distribution
cd electron
npm run dist
```

### API Endpoints
- `GET /health` - Health check
- `GET /settings` - Get current settings
- `POST /settings` - Update settings
- `GET /models` - List available models
- `POST /command` - Process AI command

## 🛠️ **Troubleshooting**

### Common Issues

**Server won't start:**
```bash
# Check if port is in use
lsof -iTCP:8765 -sTCP:LISTEN

# Check Python dependencies
pip install -r python/requirements.txt
```

**Ollama connection failed:**
```bash
# Check if Ollama is running
ollama serve

# Check available models
ollama list
```

**AX helper not working:**
```bash
# Rebuild the helper
cd axhelper && swift build -c release

# Grant accessibility permissions
# System Settings → Privacy & Security → Accessibility
```

**Electron won't start:**
```bash
# Clear node_modules and reinstall
cd electron
rm -rf node_modules package-lock.json
npm install
```

### Logs
- **Server logs**: `logs/cluely-lite.log`
- **Electron logs**: Check console output
- **Debug mode**: Set `CLUELY_LOG_LEVEL=DEBUG`

## 📋 **Requirements**

### System Requirements
- **macOS 14.0+** (Sequoia or later)
- **8GB RAM** (recommended for AI models)
- **2GB free disk space**
- **Internet connection** (for initial setup only)

### Dependencies
- **Python 3.9+**
- **Node.js 18+**
- **Xcode Command Line Tools**
- **Ollama** (local LLM runtime)

## 🤝 **Contributing**

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Ollama** for local LLM runtime
- **FastAPI** for the Python web framework
- **Electron** for the desktop app framework
- **macOS Accessibility API** for automation capabilities

---

**Made with ❤️ for macOS users who value privacy and local-first software.**