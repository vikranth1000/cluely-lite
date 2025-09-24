# Cluely-Lite

Cluely-Lite is a macOS desktop companion that keeps all cognitive work on your machine. The SwiftUI front end captures context through accessibility APIs, while a local Python agent plans actions with a small language model served by Ollama. The result is a privacy-preserving automation layer that can read what is on screen, reason about your request, and act through native macOS primitives.

## Key Capabilities

- Local-only language planning (no network calls beyond your Ollama daemon)
- Accessibility snapshotting with confirmation gates for destructive intents
- Minimal pill-shaped heads-up display that expands for requests and collapses to stay out of the way
- Floating transcript window that shows full model responses, detachable from the main HUD
- Hotkey control (Command + \) for instant hide/show and hover activation at the top edge of the screen

## Requirements

- macOS 14.0 or newer with accessibility permissions granted to Cluely-Lite
- Xcode command line tools (or full Xcode) to build the Swift target
- Python 3.9+ with standard library only (no additional dependencies required)
- Ollama with at least one compact model pulled locally (the defaults assume `phi4:mini`)

## Installation Checklist

1. **Install Ollama**
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ollama serve
   ollama pull phi4:mini
   ```

2. **Clone and prepare**
   ```bash
   git clone <repo-url>
   cd cluely-lite
   ```

3. **Build the macOS app**
   ```bash
   xcodebuild -project CluelyLite/CluelyLite.xcodeproj \
              -scheme CluelyLite \
              -configuration Release \
              CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
   ```
   Copy `CluelyLite.app` from `Build/Products/Release` into `/Applications` (or another writable location) so macOS will allow you to grant permissions.

4. **Grant permissions**
   - System Settings → Privacy & Security → Accessibility → add the copied `CluelyLite.app`
   - Optional: System Settings → Privacy & Security → Screen Recording for richer snapshots

5. **Start the automation agent**
   ```bash
   cd python/src
   python server.py
   ```

6. **Launch the macOS client**
   Start `/Applications/CluelyLite.app`. The pill will appear at the top of your primary display once it has accessibility access.

## Operating the Assistant

- **Toggle visibility**: Command + \ hides or shows the HUD. When hidden, the response transcript is also dismissed.
- **Expand to interact**: Hover at the top edge or press Command + \ while visible to expand the pill and focus the text field automatically.
- **Submit commands**: Type a natural-language instruction and press Return. The response float appears beneath the pill and can be closed with Escape or the close button.
- **Confirm risky actions**: When the planner proposes something that might be destructive, Cluely-Lite requires you to type `confirm` or `cancel` before executing.
- **Resize or reposition**: Drag the left grip to move the HUD. Use the vertical handle on the right to widen or narrow it. Positions persist until you move or resize again.

## Anatomy of the System

```
┌──────────────┐     ┌────────────────────────────────────┐     ┌──────────────┐
│ Swift Client │◄───►│ Python Action Planner (http://127) │◄───►│ Ollama Model │
│              │     │ • instruction + snapshot ingestion │     │              │
│ • HUD + UX   │     │ • structured JSON tool planning    │     │ • local LLM  │
│ • AX bridge  │     │ • fallback echo when LLM offline   │     │              │
└──────────────┘     └────────────────────────────────────┘     └──────────────┘
```

The Swift target is responsible for capturing the accessibility tree, presenting UI, and invoking macOS actions. The Python service translates natural language requests into structured “tools” that the macOS layer can execute. Both components communicate via a local HTTP API on port 8765.

## Configuration Surface

Environment variables influence the Python agent:

```bash
export CLUELY_OLLAMA_MODEL="llama3.2:3b"      # pick a different local model
export CLUELY_OLLAMA_URL="http://127.0.0.1:11434/api/generate"  # custom Ollama endpoint
export CLUELY_DEBUG=1                          # verbose logging for the server
```

The Swift code exposes adjustments in `OverlayWindow.swift` and `OverlayView.swift` for UI timings, sizing, and confirmation thresholds. Hotkey definitions live in `HotkeyManager.swift`.

## Troubleshooting

| Symptom | Checklist |
| --- | --- |
| Assistant answers “snapshot unavailable” | Ensure Cluely-Lite is checked under Privacy & Security → Accessibility. If the target app is on another Space or display, bring it forward before asking. |
| `python server.py` prints connection errors | Verify `ollama serve` is running and that the model listed in `CLUELY_OLLAMA_MODEL` is pulled locally. |
| Command + \ does nothing | Another app may already use the shortcut. Update `HotkeyManager.swift` to a different key combination and rebuild. |
| Floating transcript lingers after closing the HUD | Press Command + \ once to hide both the pill and transcript; press again to bring them back. |
| Model output is unhelpful | Try a richer Ollama model (`llama3.2:3b` or `qwen2.5:3b`) and restart the Python server so it picks up the new environment variable. |

Logs:
- Swift output: Console.app filtered by “CluelyLite”
- Python server: stdout from `python server.py`

## Development Workflow

1. Keep `python/src/server.py` running for live testing.
2. In another terminal, use `xcodebuild` (or Xcode GUI) to build the Swift target. During iteration, pass `-configuration Debug` for faster builds.
3. `OverlayView.swift` contains the SwiftUI UI. `OverlayWindow.swift` wraps NSPanel behavior. Accessibility capture and execution live in `AccessibilitySnapshotter.swift` and `AccessibilityActionPerformer.swift` respectively.
4. The mini HUD responds to SwiftUI state, making it easy to experiment with layout and interactions. `OverlayController` is the mediator between UI events and backend calls.
5. For automated verification of the Python API, run `python test_server.py`. It exercises the health endpoint and sample commands.

## License

Cluely-Lite is available under the MIT License. See `LICENSE` for the full text.

## Support

Issues and feature requests are welcome via GitHub Issues. For local debugging questions, open a discussion or contact the maintainers through the project’s preferred communication channel.
