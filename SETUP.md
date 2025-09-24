# Cluely-Lite Setup Guide

Cluely-Lite is a local AI-powered desktop assistant for macOS that can see and interact with your screen using accessibility APIs and local AI models.

## Prerequisites

### 1. Install Ollama
First, install Ollama to run local AI models:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# In another terminal, pull a suitable model
ollama pull phi4:mini
# or for better performance (requires more RAM):
ollama pull llama3.2:3b
ollama pull qwen2.5:3b
```

### 2. Grant Accessibility Permissions
The app requires accessibility permissions to interact with other applications:

1. Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
2. Click the lock icon and enter your password
3. Add Cluely-Lite to the list of allowed applications
4. Make sure the checkbox is checked

### 3. Grant Screen Recording Permissions (Optional)
For better screen analysis:

1. Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Screen Recording**
2. Add Cluely-Lite to the list of allowed applications

## Installation

### Option 1: Build from Source

1. **Clone and build the project:**
   ```bash
   git clone <your-repo-url>
   cd cluely-lite
   ```

2. **Build the macOS app:**
   ```bash
   cd CluelyLite
   xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Release build
   ```

3. **Start the Python server:**
   ```bash
   cd python/src
   python server.py
   ```

4. **Run the macOS app:**
   ```bash
   open /path/to/build/CluelyLite.app
   ```

### Option 2: Use the Setup Script

Run the automated setup script:

```bash
chmod +x setup.sh
./setup.sh
```

## Usage

### Basic Usage

1. **Start the Python server** (if not already running):
   ```bash
   cd python/src
   python server.py
   ```

2. **Launch the macOS app** - it will appear in your menu bar with an eye icon

3. **Activate the overlay** using one of these methods:
   - Press `⌘+Return` (Command+Return)
   - Move your mouse to the very top edge of the screen
   - Click the eye icon in the menu bar

4. **Type your instruction** in the text field and press Enter

### Example Commands

- "Click the Save button"
- "Type 'Hello World' in the search box"
- "Focus on the username field"
- "What's on my screen right now?"
- If Cluely-Lite warns about a risky action, type `confirm` to continue or `cancel` to dismiss the action.
- A compact overlay stays visible at the top—hover to expand it or use the hotkey for quick access.

### Advanced Usage

#### Environment Variables

You can customize the AI model and server settings:

```bash
# Use a different Ollama model
export CLUELY_OLLAMA_MODEL="llama3.2:3b"

# Use a different Ollama server
export CLUELY_OLLAMA_URL="http://localhost:11434/api/generate"

# Start the server with custom settings
python server.py
```

#### Available Actions

The AI can perform these actions:
- **answer**: Provide a text response
- **click**: Click on UI elements
- **type**: Type text into input fields
- **focus**: Focus on specific elements

## Troubleshooting

### Common Issues

1. **"Accessibility permissions required"**
   - Go to System Preferences → Security & Privacy → Privacy → Accessibility
   - Add Cluely-Lite and ensure it's checked

2. **"Ollama not detected"**
   - Make sure Ollama is running: `ollama serve`
   - Check if the model is installed: `ollama list`
   - Verify the URL in the server logs

3. **"Agent HTTP error"**
   - Ensure the Python server is running on port 8765
   - Check firewall settings
   - Verify the server logs for errors

4. **App doesn't respond to hotkeys**
   - Grant accessibility permissions
   - Try restarting the app
   - Check if another app is using the same hotkey

### Debug Mode

Enable debug logging:

```bash
# For the Python server
export CLUELY_DEBUG=1
python server.py

# For the macOS app, check Console.app for logs
```

### Performance Tips

1. **Use smaller models** for faster response times:
   - `phi4:mini` (fastest, ~2GB RAM)
   - `qwen2.5:3b` (good balance, ~3GB RAM)

2. **Close unnecessary applications** to free up memory

3. **Use specific instructions** rather than vague ones

## Configuration

### Server Configuration

Edit `python/src/server.py` to customize:

- **Model selection**: Change `OLLAMA_MODEL`
- **Server port**: Modify the port in `main()`
- **Timeout settings**: Adjust `timeout=45` in `query_ollama()`
- **Response limits**: Modify `max_tokens` in the Ollama payload

### App Configuration

The macOS app settings are in the Swift files:

- **Hotkey**: Modify `HotkeyManager.swift`
- **UI appearance**: Edit `OverlayView.swift`
- **Auto-hide timing**: Change the timer in `OverlayWindow.swift`

## Security & Privacy

- **100% Local**: All processing happens on your machine
- **No Data Collection**: No information is sent to external servers
- **Open Source**: Full source code is available for review
- **Minimal Permissions**: Only requests necessary accessibility permissions

## Development

### Project Structure

```
cluely-lite/
├── CluelyLite/           # macOS Swift app
│   ├── CluelyLiteApp.swift
│   ├── OverlayView.swift
│   ├── AgentClient.swift
│   └── Accessibility*.swift
├── python/src/           # Python AI server
│   └── server.py
└── SETUP.md             # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Building for Distribution

1. **Archive the app:**
   ```bash
   xcodebuild -project CluelyLite.xcodeproj -scheme CluelyLite -configuration Release archive
   ```

2. **Export for distribution:**
   - Open Xcode
   - Window → Organizer
   - Select your archive
   - Click "Distribute App"

## License

This project is open source. See the LICENSE file for details.

## Support

For issues and questions:
1. Check this setup guide
2. Review the troubleshooting section
3. Check the GitHub issues
4. Create a new issue with detailed information

---

**Happy automating!** 🤖✨
