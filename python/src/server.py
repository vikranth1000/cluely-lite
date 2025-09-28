#!/usr/bin/env python3
"""
Cluely-Lite Local AI Agent Server
A local HTTP server that provides AI-powered desktop automation using Ollama.
"""

import json
import http.server
import socketserver
import os
import logging
import time
from urllib.parse import urlparse
from urllib import request, error as urllib_error
import socket

# Configuration (defaults favor small, efficient local models)
DEFAULT_OLLAMA_URL = os.environ.get("CLUELY_OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
DEFAULT_OLLAMA_MODEL = os.environ.get("CLUELY_OLLAMA_MODEL", "qwen2.5:3b")

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

Use POST /command with JSON {{"instruction":"<text>"}}
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


"""
Note: removed legacy action-planning helpers to keep this server focused on
prompt→response. Actions (click/focus/type) are performed by Electron via the
Swift axhelper. This reduces latency and simplifies the backend.
"""


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
