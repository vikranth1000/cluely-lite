# Cluely‑Lite Setup Guide (Electron + Local‑First)

Cluely‑Lite is a local AI assistant for macOS. The UI is an Electron pill overlay; screen actions are performed by a tiny Swift CLI (`axhelper`). A Python server talks to your local Ollama model.

## Prerequisites

- macOS 14+
- Python 3.9+
- Xcode Command Line Tools (for Swift build)
- Node.js + npm (for Electron)
- Ollama (local LLM runtime)

## 1) Install and start Ollama

```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve
ollama pull qwen2.5:3b          # default
# optional: ollama pull llama3.2:3b
```

## 2) Clone repo and build the Swift helper

```bash
git clone <your-repo-url>
cd cluely-lite
cd axhelper && swift build -c release && cd ..
```

## 3) Install Electron deps and run

```bash
cd electron
npm install
npm start
```

Or use the convenience script from repo root:

```bash
./launch_electron.sh
```

## 4) Start the Python server

```bash
cd python/src
# optional: export CLUELY_OLLAMA_MODEL="llama3.2:3b"
python server.py
```

## Permissions

On first use of the tools bar (Snapshot/Click/Type/Focus), grant Accessibility permissions for the `axhelper` binary:
- System Settings → Privacy & Security → Accessibility → add and enable `axhelper`.

Screen Recording permissions are optional and only needed for advanced workflows.

## Configuration

```bash
export CLUELY_OLLAMA_MODEL="qwen2.5:3b"        # override default model
export CLUELY_OLLAMA_URL="http://127.0.0.1:11434/api/generate"
export CLUELY_DEBUG=1                          # verbose Python logs
```

## Troubleshooting

- Check server health: `curl http://127.0.0.1:8765/health`
- List models: `curl http://127.0.0.1:8765/models`
- Ensure Ollama is running: `ollama serve`
- Build helper if missing: `(cd axhelper && swift build -c release)`

## Project Structure

```
cluely-lite/
├── electron/                 # Electron UI (pill + transcript + tools)
├── axhelper/                 # Swift CLI for macOS AX actions
├── python/src/server.py      # Local HTTP server (Ollama integration)
├── launch_electron.sh        # Convenience launcher for UI + helper
└── SETUP.md                  # This file
```

Happy automating! 🤖✨
