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

# Configuration
OLLAMA_URL = os.environ.get("CLUELY_OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
OLLAMA_MODEL = os.environ.get("CLUELY_OLLAMA_MODEL", "phi4:mini")
ALLOWED_ACTIONS = {"answer", "click", "type", "focus"}

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global state
request_count = 0
start_time = time.time()


class CommandHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        """Handle POST requests to /command endpoint."""
        global request_count
        request_count += 1
        
        parsed_path = urlparse(self.path)
        if parsed_path.path != '/command':
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

        instruction = json_payload.get('instruction')
        if not isinstance(instruction, str) or not instruction.strip():
            self._send_error(400, "Field 'instruction' must be a non-empty string")
            return
        snapshot = json_payload.get('snapshot')
        if snapshot is not None and not isinstance(snapshot, list):
            self._send_error(400, "Field 'snapshot' must be an array if provided")
            return

        logger.info(f"Processing request #{request_count}: {instruction[:50]}...")
        request_started = time.time()
        
        try:
            plan = plan_action(instruction.strip(), snapshot or [])
            processing_time = time.time() - request_started
            logger.info(f"Request #{request_count} completed in {processing_time:.2f}s")
            self._send_json(200, plan)
        except Exception as e:
            logger.error(f"Error processing request #{request_count}: {e}")
            error_response = {
                "response": f"Error processing request: {str(e)}",
                "tool": {
                    "action": "answer",
                    "target": None,
                    "text": f"Error: {str(e)}"
                }
            }
            self._send_json(500, error_response)
    
    def do_GET(self):
        """Handle GET requests - return server status."""
        parsed_path = urlparse(self.path)
        if parsed_path.path not in ('/', '/status', '/health'):
            self._send_error(404, "Not found")
            return
        
        uptime = time.time() - start_time
        status = {
            "status": "running",
            "uptime_seconds": round(uptime, 2),
            "requests_processed": request_count,
            "ollama_url": OLLAMA_URL,
            "ollama_model": OLLAMA_MODEL,
            "version": "1.0.0"
        }
        
        if parsed_path.path == '/health':
            self._send_json(200, status)
        else:
            body = f"""Cluely-Lite Agent Server
Status: Running
Uptime: {uptime:.1f} seconds
Requests: {request_count}
Ollama: {OLLAMA_MODEL} at {OLLAMA_URL}

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


def plan_action(instruction, snapshot):
    """Plan an action based on instruction and screen snapshot."""
    prompt = build_prompt(instruction, snapshot)
    tool, tool_error = query_ollama(prompt)
    
    if tool is None:
        logger.warning(f"Ollama query failed: {tool_error}")
        fallback = fallback_tool(instruction, tool_error)
        return fallback

    response_text = tool.get("text") or "Action planned"
    return {"response": response_text, "tool": tool}


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


def build_prompt(instruction, snapshot):
    """Build a prompt for the AI model."""
    # Truncate snapshot to avoid token limits
    truncated_snapshot = snapshot[:120]
    snapshot_text = json.dumps(truncated_snapshot, ensure_ascii=False, indent=2)
    if len(snapshot_text) > 60000:
        snapshot_text = snapshot_text[:60000] + "\n... (truncated)"
    
    schema = textwrap.dedent("""
        Respond with a single JSON object matching this schema:
        {
            "action": "answer|click|type|focus",
            "target": "string (element identifier)",
            "text": "string (optional, for type actions)"
        }
        
        Available actions:
        - answer: Provide a text response without UI interaction
        - click: Click on an element (use target to identify element)
        - type: Type text into an element (use target and text)
        - focus: Focus on an element (use target)
    """).strip()
    
    return f"""You are Cluely-Lite, a local AI assistant for desktop automation.

Instruction: {instruction}

Current screen elements:
{snapshot_text}

{schema}

Analyze the instruction and current screen state, then return the appropriate action as JSON. Be precise with element targeting."""


def query_ollama(prompt):
    """Query the Ollama API for action planning."""
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.1,  # Low temperature for consistent output
            "top_p": 0.9,
            "max_tokens": 1000
        }
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = request.Request(OLLAMA_URL, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with request.urlopen(req, timeout=45) as resp:
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
        req = request.Request(OLLAMA_URL.replace('/api/generate', '/api/tags'))
        with request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except:
        return False


def main():
    """Start the HTTP server."""
    host = '127.0.0.1'
    port = 8765
    
    # Check Ollama availability
    if check_ollama_availability():
        logger.info(f"✅ Ollama is running at {OLLAMA_URL}")
    else:
        logger.warning(f"⚠️  Ollama not detected at {OLLAMA_URL}")
        logger.warning("   Server will run in fallback mode")
    
    try:
        with ThreadedTCPServer((host, port), CommandHandler) as httpd:
            logger.info(f"🚀 Cluely-Lite Agent Server starting on {host}:{port}")
            logger.info(f"📊 Model: {OLLAMA_MODEL}")
            logger.info(f"🔗 Ollama: {OLLAMA_URL}")
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