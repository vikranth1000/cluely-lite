# Cluely‑Lite (Local‑First)

Cluely‑Lite is a macOS assistant that keeps all automation and language processing on your machine. The UI is built with Electron for rapid iteration and minimal screen footprint. A tiny Swift CLI helper performs macOS Accessibility (AX) actions when asked. A local Python server talks to your Ollama model to generate responses — no extra prompting or remote calls.

## Key Capabilities

- 100% local: Ollama model on your Mac
- Direct prompt → full response (no extra context)
- Minimal pill UI, predictable drag + resize (width + height)
- Optional AX actions: snapshot, click, focus, type (via Swift helper)

## Requirements

- macOS 14.0+
- Python 3.9+
- Xcode command line tools (Swift toolchain) to build the AX helper
- Ollama with a small local model (default `qwen2.5:3b`)

## Install + Run

1) Install Ollama and a model
```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve
ollama pull qwen2.5:3b
# optional: ollama pull llama3.2:3b
```

2) Clone the repo
```bash
git clone <repo-url>
cd cluely-lite
```

3) Start the local server (direct prompt in → raw model out)
```bash
cd python/src
# optionally: export CLUELY_OLLAMA_MODEL="llama3.2:3b"
python server.py
```

4) Build AX helper + start Electron UI
```bash
cd axhelper && swift build -c release && cd ..
./launch_electron.sh
```

## How It Works
```
┌────────────────┐   ┌────────────────────┐   ┌──────────────┐   ┌──────────────┐
│ Electron (UI)  │──►│ Python Server      │──►│ Ollama Model │   │ Swift AX Help │
│ • Pill + HUD   │   │ • raw prompt I/O   │   │ • local LLM  │   │ • AX actions  │
│ • Transcript   │   │ • no extra prompt  │   │              │   │ • snapshot    │
│ • Hotkeys      │   │                    │   │              │   │ (CLI)         │
└────────────────┘   └────────────────────┘   └──────────────┘   └──────────────┘
```

## Usage
- Show/hide: Command + \
- Type and press Enter → transcript shows full model output
- Drag anywhere on the pill; resize from right edge (width) and bottom bar (height)
- Tools bar (optional): Snapshot / Click / Focus / Type — on first use, grant Accessibility permissions for `axhelper` under System Settings → Privacy & Security → Accessibility

## Configuration
```bash
export CLUELY_OLLAMA_MODEL="qwen2.5:3b"        # override default model
export CLUELY_OLLAMA_URL="http://127.0.0.1:11434/api/generate"
export CLUELY_DEBUG=1                          # verbose Python logs
```

Endpoints (local):
- Health: `GET http://127.0.0.1:8765/health`
- Models: `GET http://127.0.0.1:8765/models`
- Settings: `GET/POST http://127.0.0.1:8765/settings`
- Command: `POST http://127.0.0.1:8765/command {"instruction":"..."}`

## Development
- Server: `python python/src/server.py`
- AX Helper: `cd axhelper && swift build -c release`
- Electron UI: `cd electron && npm install && npm start`
- Tests: `python test_server.py`

## Notes
- Old Swift overlay app has been removed; AX is now a tiny Swift CLI (`axhelper`).
- Packaging: `electron-builder` config is included (see `electron/package.json`).

## License
MIT

