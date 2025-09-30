# Cluely-Lite

A privacy-focused local AI assistant for macOS that runs entirely on your machine.

## Overview

Cluely-Lite is a desktop application that provides AI-powered assistance through a clean, minimal floating interface. All processing happens locally using Ollama, ensuring complete privacy without any cloud dependencies.

**Version:** 2.0.0  
**Platform:** macOS 14.0+  
**License:** MIT

## Key Features

### Current Implementation

- **Local AI Processing**: Integrated with Ollama for completely private, offline AI interactions
- **Floating Pill Interface**: Minimal, always-accessible UI that stays on top of other applications
- **Keyboard-Driven Workflow**: Quick access via Cmd+\ shortcut, Enter to submit queries
- **Multiple Model Support**: Compatible with various Ollama models (qwen2.5:3b, llama3.2:3b, etc.)
- **Incognito Mode**: Hide application from dock while maintaining functionality
- **Real-time Responses**: Direct integration with Ollama API with fallback to FastAPI server
- **Cross-Workspace Access**: Interface available across all virtual desktops

### Technical Architecture

```
┌─────────────────────┐
│   Electron UI       │  Modern desktop interface
│   (Main + Renderer) │  Context-isolated preload bridge
└──────────┬──────────┘
           │
           ├──────────► Ollama API (Primary)
           │            Direct HTTP requests to local LLM
           │
           └──────────► FastAPI Server (Fallback)
                        Python backend with rate limiting
                        and structured logging
```

## Prerequisites

- **macOS**: Version 14.0 (Sequoia) or later
- **Python**: 3.9 or higher
- **Node.js**: 18.0 or higher
- **Ollama**: For local LLM inference
- **Xcode Command Line Tools**: `xcode-select --install`

## Installation

### 1. Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull a model (recommended: qwen2.5:3b for balance of speed and quality)
ollama pull qwen2.5:3b
```

### 2. Clone Repository

```bash
git clone https://github.com/vikranth1000/cluely-lite.git
cd cluely-lite
```

### 3. Install Python Dependencies

```bash
cd python
pip3 install -r requirements.txt
cd ..
```

### 4. Install Electron Dependencies

```bash
cd electron
npm install
cd ..
```

## Running the Application

### Quick Start

Use the automated launch script:

```bash
./launch_electron.sh
```

This script handles:
- System requirements validation
- Ollama service initialization
- Model availability verification
- Python server startup
- Electron UI launch

### Manual Start

**Terminal 1 - Start Python Server:**
```bash
cd python/src
python3 server.py
```

**Terminal 2 - Launch Electron UI:**
```bash
cd electron
npm start
```

## Usage

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle UI visibility | `Cmd + \` |
| Submit query | `Enter` |
| Clear input | `Escape` |
| Close output tab | Click `×` button |

### Basic Workflow

1. Press `Cmd + \` to show the interface
2. Type your question or command in the input field
3. Press `Enter` to submit
4. View AI response in the output panel below
5. Close individual responses with the `×` button

### Incognito Mode

Click the eye icon to toggle incognito mode, which hides the application from the macOS dock while keeping it functional.

## Configuration

### Configuration File

Edit `config.json` to customize behavior:

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
  }
}
```

### Environment Variables

```bash
export CLUELY_OLLAMA_MODEL="qwen2.5:3b"
export CLUELY_OLLAMA_URL="http://127.0.0.1:11434/api/generate"
export CLUELY_PORT="8765"
export CLUELY_LOG_LEVEL="INFO"
```

## Development

### Project Structure

```
cluely-lite/
├── electron/
│   ├── main.js              # Electron main process
│   ├── preload.js           # IPC bridge (CommonJS)
│   ├── renderer/
│   │   ├── index.html       # UI structure
│   │   ├── app.js           # UI logic and state
│   │   └── styles.css       # Interface styling
│   └── package.json
├── python/
│   ├── src/
│   │   ├── server.py        # FastAPI application
│   │   ├── config.py        # Configuration loader
│   │   ├── models.py        # Pydantic models
│   │   └── logger.py        # Structured logging
│   └── requirements.txt
├── config.json              # Application configuration
└── launch_electron.sh       # Automated startup script
```

### API Endpoints

**FastAPI Server (http://localhost:8765):**

- `GET /health` - Server health and status
- `GET /settings` - Current configuration
- `POST /settings` - Update configuration
- `GET /models` - List available Ollama models
- `POST /command` - Process AI command

### Development Mode

```bash
# Run Electron with DevTools
cd electron
NODE_ENV=development npm start

# Python server with debug logging
cd python/src
CLUELY_LOG_LEVEL=DEBUG python3 server.py
```

### Building Distribution

```bash
cd electron
npm run dist
```

Outputs to `electron/dist/` as `.dmg` and `.zip` packages.

## Troubleshooting

### Common Issues

**Bridge Communication Error:**
- Ensure `preload.js` uses CommonJS syntax (require, not import)
- Check browser console for detailed error messages

**Ollama Not Responding:**
```bash
# Verify Ollama is running
curl http://127.0.0.1:11434/api/tags

# Restart Ollama
killall ollama
ollama serve
```

**Port Already in Use:**
```bash
# Find process using port 8765
lsof -i :8765

# Kill the process or change port in config.json
```

**Output Tabs Not Visible:**
- Window height has been increased to 400px (from 120px)
- Scroll down if multiple responses are present

### Log Files

- Python server: `logs/cluely-lite.log`
- Electron: Check terminal output or DevTools console

## Roadmap

### Planned Features

**Near-term (v2.1):**
- Voice input integration using native speech recognition
- Conversation history and context management
- Export conversations to Markdown/PDF
- Custom system prompts per conversation

**Mid-term (v2.2):**
- Model switching from UI
- Streaming responses for real-time feedback
- Multi-turn conversations with context
- Clipboard integration for quick queries

**Long-term (v3.0):**
- macOS Accessibility API integration for UI automation
- Plugin system for extensibility
- Cloud sync option (optional, encrypted)
- Multi-language support

### Known Limitations

- Currently no conversation persistence between sessions
- Listen button UI present but voice input not yet implemented
- No built-in model management (use Ollama CLI)
- Window positioning may need adjustment on multi-monitor setups

## Performance

**Tested Configuration:**
- **Hardware:** Apple M4, 16GB RAM
- **Model:** qwen2.5:3b (1.9GB)
- **Response Time:** ~2-3 seconds average
- **Memory Usage:** ~2.5GB (including model in Metal memory)

## Security

- All data processing occurs locally
- No external API calls except to local Ollama instance
- Rate limiting prevents abuse (60 requests/minute default)
- CORS restricted to localhost
- Context isolation in Electron renderer process
- Input validation via Pydantic models

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Follow existing code style and conventions
4. Add tests for new functionality
5. Update documentation as needed
6. Submit a pull request with clear description

## Technical Details

### Dependencies

**Python:**
- fastapi (0.104.1)
- uvicorn (0.24.0)
- httpx (0.25.2)
- pydantic (2.5.0)
- structlog (23.2.0)

**Node.js:**
- electron (28.0.0)
- node-fetch (3.3.2)

### System Integration

- Uses Electron's IPC (Inter-Process Communication) for secure main-renderer messaging
- Context isolation enabled with explicit contextBridge API exposure
- Sandboxed renderer process for security
- Direct Ollama API access with FastAPI fallback architecture

## License

MIT License - See LICENSE file for details.

## Acknowledgments

- Ollama team for the excellent local LLM runtime
- FastAPI for the modern Python web framework
- Electron team for cross-platform desktop capabilities

---

**Author:** Vikranth Reddimasu  
**Repository:** https://github.com/vikranth1000/cluely-lite  
**Issues:** https://github.com/vikranth1000/cluely-lite/issues