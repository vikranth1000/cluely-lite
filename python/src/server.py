#!/usr/bin/env python3
"""
Cluely-Lite Local AI Agent Server
A local HTTP server that provides AI-powered desktop automation using Ollama.
"""

import json
import http.server
import socketserver
import os
import textwrap
import logging
import time
from urllib.parse import urlparse
from urllib import request, error as urllib_error
import socket

# Configuration (defaults favor small, efficient local models)
DEFAULT_OLLAMA_URL = os.environ.get("CLUELY_OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
DEFAULT_OLLAMA_MODEL = os.environ.get("CLUELY_OLLAMA_MODEL", "qwen2.5:3b")
ALLOWED_ACTIONS = {"answer", "click", "type", "focus"}

# Mutable server state (runtime configurable via /settings)
server_state = {
    "ollama_url": DEFAULT_OLLAMA_URL,
    "ollama_model": DEFAULT_OLLAMA_MODEL,
}

# Setup logging
log_level = logging.DEBUG if os.environ.get("CLUELY_DEBUG") else logging.INFO
logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global state
request_count = 0
start_time = time.time()


class CommandHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        """Handle POST requests to /command endpoint or /settings."""
        global request_count
        request_count += 1

        parsed_path = urlparse(self.path)
        if parsed_path.path not in ('/command', '/settings'):
            self._send_error(404, "Not found")
            return

        content_length_header = self.headers.get('Content-Length')
        if content_length_header is None:
            self._send_error(411, "Content-Length header required")
            return
        try:
            content_length = int(content_length_header)
        except (TypeError, ValueError):
            self._send_error(400, "Invalid Content-Length header")
            return

        try:
            post_data = self.rfile.read(content_length)
        except OSError as exc:
            self._send_error(400, f"Failed to read request body: {exc}")
            return

        try:
            json_payload = json.loads(post_data.decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            self._send_error(400, f"Invalid JSON payload: {exc}")
            return

        if parsed_path.path == '/settings':
            # Runtime settings update
            updated = {}
            if 'ollama_url' in json_payload:
                url = str(json_payload['ollama_url']).strip()
                if url:
                    server_state['ollama_url'] = url
                    updated['ollama_url'] = url
            if 'ollama_model' in json_payload:
                model = str(json_payload['ollama_model']).strip()
                if model:
                    server_state['ollama_model'] = model
                    updated['ollama_model'] = model
            if not updated:
                self._send_error(400, "No recognized settings in payload")
                return
            logger.info(f"Settings updated: {updated}")
            self._send_json(200, {"status": "ok", **server_state})
            return

        instruction = json_payload.get('instruction')
        if not isinstance(instruction, str) or not instruction.strip():
            self._send_error(400, "Field 'instruction' must be a non-empty string")
            return

        # Optional per-request model override
        req_model = json_payload.get('model')
        model_override = str(req_model).strip() if isinstance(req_model, str) and req_model.strip() else None

        logger.info(f"Generating for request #{request_count}: {instruction[:50]}...")
        request_started = time.time()

        try:
            text, gen_err = generate_text(instruction.strip(), model_override=model_override)
            processing_time = time.time() - request_started
            logger.info(f"Request #{request_count} completed in {processing_time:.2f}s")
            if gen_err:
                self._send_json(502, {"response": f"Error: {gen_err}"})
            else:
                self._send_json(200, {"response": text})
        except Exception as e:
            logger.error(f"Error processing request #{request_count}: {e}")
            self._send_json(500, {"response": f"Error processing request: {str(e)}"})
    
    def do_GET(self):
        """Handle GET requests - return server status or settings/models."""
        parsed_path = urlparse(self.path)
        if parsed_path.path not in ('/', '/status', '/health', '/settings', '/models'):
            self._send_error(404, "Not found")
            return
        
        uptime = time.time() - start_time
        status = {
            "status": "running",
            "uptime_seconds": round(uptime, 2),
            "requests_processed": request_count,
            "ollama_url": server_state["ollama_url"],
            "ollama_model": server_state["ollama_model"],
            "version": "1.0.0"
        }
        
        if parsed_path.path == '/health':
            self._send_json(200, status)
        elif parsed_path.path == '/settings':
            self._send_json(200, server_state | {"status": "ok"})
        elif parsed_path.path == '/models':
            models = list_ollama_models()
            self._send_json(200, {"models": models})
        else:
            body = f"""Cluely-Lite Agent Server
Status: Running
Uptime: {uptime:.1f} seconds
Requests: {request_count}
Ollama: {server_state['ollama_model']} at {server_state['ollama_url']}

Use POST /command with JSON {{"instruction":"<text>","snapshot":[...]}}
"""
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body.encode('utf-8'))

    def _send_json(self, status_code, payload):
        data = json.dumps(payload, indent=2).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_error(self, status_code, message):
        self._send_json(status_code, {"error": message})

    def log_message(self, format, *args):
        # Custom logging to avoid duplicate messages
        pass


class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def generate_text(prompt, model_override=None):
    """Send the raw user prompt to the local model and return full text."""
    model = model_override or server_state["ollama_model"]
    url = server_state["ollama_url"]
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 1024,
            "num_ctx": 2048
        }
    }
    data = json.dumps(payload).encode('utf-8')
    req = request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    try:
        with request.urlopen(req, timeout=120) as resp:
            body = resp.read()
    except (urllib_error.URLError, urllib_error.HTTPError, TimeoutError, socket.timeout) as exc:
        return None, f"Ollama connection error: {exc}"
    try:
        response_payload = json.loads(body.decode('utf-8'))
    except json.JSONDecodeError as exc:
        return None, f"Ollama response decode error: {exc}"
    raw = response_payload.get('response')
    if not isinstance(raw, str):
        return None, "Ollama returned invalid response format"
    return raw, None


def plan_action(instruction, snapshot, model_override=None):
    """Plan an action based on instruction and screen snapshot."""
    prompt = build_prompt(instruction, snapshot)
    tool, tool_error = query_ollama(prompt, model_override=model_override)
    
    if tool is None:
        logger.warning(f"Ollama query failed: {tool_error}")
        # Try a lightweight heuristic tool before echo fallback
        heuristic = heuristic_tool(instruction, snapshot)
        if heuristic is not None:
            return {"response": heuristic.get("text") or "Action planned", "tool": heuristic}
        fallback = fallback_tool(instruction, tool_error)
        return fallback

    # Normalize tool target to prefer visible titles over opaque ids
    tool = normalize_tool_with_snapshot(tool, snapshot, instruction)
    # Provide a concise natural-language summary for UI transcript
    action = tool.get("action") or ""
    target = tool.get("target") or ""
    if action == "answer":
        response_text = tool.get("text") or "(no response)"
    else:
        response_text = f"Planned: {action} {target}".strip()
    return {"response": response_text, "tool": tool}


def normalize_tool_with_snapshot(tool, snapshot, instruction):
    """If the tool refers to an element by id or numeric string, map it to a visible title.
    This helps the macOS action layer locate elements by their human-readable labels.
    """
    try:
        action = (tool.get("action") or "").lower()
        target = tool.get("target")
        if action in {"click", "focus", "type"} and target:
            # If target matches a node id, substitute its title if present
            for node in snapshot:
                if str(node.get("id")) == str(target):
                    title = str(node.get("title", "")).strip()
                    if title:
                        tool["target"] = title
                    break
            # If target not a visible title, try to infer best title from instruction words
            visible_titles = [str(n.get("title", "")).strip() for n in snapshot if str(n.get("title", "")).strip()]
            tgt = str(tool.get("target") or "").strip()
            if tgt and tgt not in visible_titles:
                # Simple heuristic: choose title with highest token overlap with instruction
                low_ins = (instruction or "").lower()
                tokens = {t for t in [
                    *low_ins.replace("\n", " ").split()
                ] if t.isalpha() and len(t) >= 3}
                best = None
                best_score = 0
                for title in visible_titles:
                    lt = title.lower()
                    score = sum(1 for w in tokens if w in lt)
                    if score > best_score:
                        best_score = score
                        best = title
                if best and best_score > 0:
                    tool["target"] = best
    except Exception:
        pass
    return tool


def fallback_tool(instruction, detail=None):
    """Create a fallback tool when Ollama is unavailable."""
    text = f"Echo: {instruction}"
    if detail:
        text = f"Echo: {instruction} (AI offline: {detail})"
    return {
        "response": "Fallback response generated",
        "tool": {
            "action": "answer",
            "target": None,
            "text": text
        }
    }


def heuristic_tool(instruction, snapshot):
    """Very small rule-based planner for offline/basic commands.
    Attempts to extract a sensible tool from the instruction alone.
    """
    ins = instruction.strip()
    low = ins.lower()

    def first_title_matching(term):
        t = term.lower()
        for node in snapshot:
            title = str(node.get("title", "")).lower()
            if t and title and (t in title or title in t):
                return node.get("title")
        return term

    # Click patterns
    if low.startswith(("click ", "press ")):
        target = ins.split(" ", 1)[1].strip()
        target = target.strip("\"'")
        return {"action": "click", "target": first_title_matching(target), "text": ""}

    # Focus patterns
    if low.startswith("focus "):
        target = ins.split(" ", 1)[1].strip()
        target = target.strip("\"'")
        return {"action": "focus", "target": first_title_matching(target), "text": ""}

    # Type patterns
    if low.startswith(("type ", "enter ", "input ")):
        # Extract quoted text if present
        import re
        m = re.search(r'"([^"]+)"|\'([^\']+)\'', ins)
        text_value = m.group(1) if m and m.group(1) else (m.group(2) if m else None)
        # Try to infer target after into/in
        target = None
        m2 = re.search(r"(?:into|in)\s+(.+)$", low)
        if m2:
            target = ins[m2.start(1):].strip()
        return {"action": "type", "target": first_title_matching(target or ""), "text": text_value or ins.split(" ", 1)[1].strip()}

    # Simple Q&A
    if any(q in low for q in ["what's on my screen", "what is on my screen", "help", "how do i"]):
        return {"action": "answer", "target": None, "text": "I can click, type, focus, or answer based on the visible UI. Try: 'Click Save', 'Type \"Hello\" into Search', or 'Focus password'."}

    return None


def build_prompt(instruction, snapshot):
    """Build a prompt for the AI model."""
    # Truncate snapshot to avoid token limits
    truncated_snapshot = snapshot[:120]
    snapshot_text = json.dumps(truncated_snapshot, ensure_ascii=False, indent=2)
    if len(snapshot_text) > 60000:
        snapshot_text = snapshot_text[:60000] + "\n... (truncated)"
    
    schema = textwrap.dedent("""
        Respond with a single JSON object matching this schema, using DOUBLE QUOTES for all keys/values and NO extra text:
        {
            "action": "answer|click|type|focus",
            "target": "string (element identifier)",
            "text": "string (optional, for type actions)"
        }
        
        Available actions:
        - answer: Provide a direct, helpful response without taking UI action
        - click: Click on an element (use target text or identifier)
        - type: Type text into an element (use target and text)
        - focus: Move the focus/caret to an element (use target)
    """).strip()
    
    guidance = textwrap.dedent("""
        Guidelines:
        - If the requested action seems unsafe or destructive, choose action "answer" and explain that confirmation is needed.
        - Always use the element TITLE as the "target" (not internal ids). Prefer exact titles from the snapshot.
        - When snapshot is empty, still select the best action based on the instruction.
        - Output ONLY the JSON object. No code fences, prose, or markdown.
        - For "answer", set "target" to null and put the reply in "text".
    """).strip()
    
    return f"""You are Cluely-Lite, a focused local desktop agent.

Instruction: {instruction}

Current screen elements (may be empty if snapshot unavailable):
{snapshot_text}

{schema}

{guidance}

Decide on the best action and return only the JSON object."""


def query_ollama(prompt, model_override=None):
    """Query the Ollama API for action planning."""
    model = model_override or server_state["ollama_model"]
    url = server_state["ollama_url"]
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.2,  # Low for consistency on small models
            "top_p": 0.8,
            "max_tokens": 400,
            "num_ctx": 2048
        },
        "format": "json"
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with request.urlopen(req, timeout=120) as resp:
            body = resp.read()
    except (urllib_error.URLError, urllib_error.HTTPError, TimeoutError, socket.timeout) as exc:
        return None, f"Ollama connection error: {exc}"

    try:
        response_payload = json.loads(body.decode('utf-8'))
    except json.JSONDecodeError as exc:
        return None, f"Ollama response decode error: {exc}"

    raw = response_payload.get('response')
    if not isinstance(raw, str):
        return None, "Ollama returned invalid response format"

    tool = parse_tool_json(raw)
    if tool is None:
        return None, "Failed to parse valid tool JSON from Ollama response"

    return tool, None


def parse_tool_json(text):
    """Parse and validate tool JSON from AI response."""
    # Try multiple parsing strategies
    candidates = [text.strip()]
    
    # Extract JSON from text if it's embedded
    if '{' in text and '}' in text:
        start = text.find('{')
        end = text.rfind('}') + 1
        if start < end:
            candidates.append(text[start:end])
    
    # Try with single quotes converted to double quotes
    candidates.append(text.replace("'", '"'))
    
    # Try to find JSON objects in the text
    import re
    json_matches = re.findall(r'\{[^{}]*\}', text)
    candidates.extend(json_matches)

    for candidate in candidates:
        try:
            obj = json.loads(candidate)
            if validate_tool(obj):
                return obj
        except json.JSONDecodeError:
            continue
    
    return None


def validate_tool(obj):
    """Validate that the tool object has the correct structure."""
    if not isinstance(obj, dict):
        return False
    
    action = obj.get('action')
    if not isinstance(action, str):
        return False
    
    action = action.lower().strip()
    if action not in ALLOWED_ACTIONS:
        return False
    
    # Normalize the action
    obj['action'] = action
    
    # Ensure target and text are strings or None
    if 'target' in obj and obj['target'] is not None:
        obj['target'] = str(obj['target'])
    else:
        obj['target'] = None
        
    if 'text' in obj and obj['text'] is not None:
        obj['text'] = str(obj['text'])
    else:
        obj['text'] = ''
    
    return True


def check_ollama_availability():
    """Check if Ollama is running and accessible."""
    try:
        req = request.Request(server_state["ollama_url"].replace('/api/generate', '/api/tags'))
        with request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except:
        return False


def list_ollama_models():
    """Return a list of model names available in the local Ollama daemon."""
    try:
        req = request.Request(server_state["ollama_url"].replace('/api/generate', '/api/tags'))
        with request.urlopen(req, timeout=5) as resp:
            body = json.loads(resp.read().decode('utf-8'))
            models = [m.get('name') for m in body.get('models', []) if m.get('name')]
            return models
    except Exception as e:
        logger.debug(f"Failed to list models: {e}")
        return []


def main():
    """Start the HTTP server."""
    host = '127.0.0.1'
    port = 8765
    
    # Check Ollama availability
    if check_ollama_availability():
        logger.info(f"✅ Ollama is running at {server_state['ollama_url']}")
    else:
        logger.warning(f"⚠️  Ollama not detected at {server_state['ollama_url']}")
        logger.warning("   Server will run in fallback mode")
    
    try:
        with ThreadedTCPServer((host, port), CommandHandler) as httpd:
            logger.info(f"🚀 Cluely-Lite Agent Server starting on {host}:{port}")
            logger.info(f"📊 Model: {server_state['ollama_model']}")
            logger.info(f"🔗 Ollama: {server_state['ollama_url']}")
            logger.info("📝 Use POST /command with JSON {\"instruction\":\"<text>\"}")
            logger.info("🛑 Press Ctrl+C to stop")
            
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                logger.info("\n🛑 Shutting down server...")
                
    except OSError as e:
        if e.errno == 48:  # Address already in use
            logger.error(f"❌ Port {port} is already in use. Try a different port or kill the existing process.")
        else:
            logger.error(f"❌ Failed to start server: {e}")
        exit(1)


if __name__ == '__main__':
    main()
