# Cluely‑Lite Project Summary

## Overview

Cluely‑Lite is a local‑first macOS assistant:
- Electron UI (pill overlay + transcript + tools)
- Python server with Ollama integration
- Swift CLI helper (`axhelper`) for macOS Accessibility actions (snapshot/click/focus/type)

All inference runs locally; no cloud calls.

## Current State (✅)

- Electron UI: pill, input, transcript, and basic resize handles
- Global shortcut: `Cmd+\` toggles the window
- Python server: health/models/settings endpoints + prompt→response command
- Ollama integration: default `qwen2.5:3b`, override via env
- Swift axhelper: snapshot/click/focus/type wired via IPC
- Packaging: electron‑builder config with hardened runtime and entitlements
- Scripts: `launch_electron.sh` convenience launcher

## Cleanups Done

- Removed stale native Swift app references in docs
- Simplified Python server by dropping unused action‑planning code
- Tightened `.gitignore` to exclude `python/.venv` and `axhelper/.build`

## Remaining Polish (Suggested)

- Remove committed build artifacts: `python/.venv/`, `axhelper/.build/` from VCS
- Unify launch scripts (keep `launch_electron.sh`, deprecate old paths)
- Add a product icon for packaging (Electron build)
- Optional: single‑instance lock, basic auto‑update, and crash logging

## Quick Start

```bash
ollama serve && ollama pull qwen2.5:3b
(cd axhelper && swift build -c release)
(cd python/src && python server.py)
(cd electron && npm install && npm start)
```

## Structure

```
cluely-lite/
├── electron/          # UI
├── axhelper/          # Swift CLI (AX)
├── python/src/        # Local server
└── scripts            # launch_electron.sh (repo root)
```

Status: stable alpha, local‑first and usable. Focus next on packaging polish and artifact cleanup.
