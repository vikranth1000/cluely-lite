"""
Professional Cluely-Lite Server
A high-performance, secure local AI assistant server using FastAPI
"""
import asyncio
import time
import uuid
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer
import structlog

from .config import config
from .logger import setup_logging, get_logger, get_struct_logger
from .models import (
    CommandRequest, CommandResponse, ErrorResponse, HealthResponse,
    SettingsResponse, SettingsUpdateRequest, ModelsResponse
)

# Setup logging
setup_logging()
logger = get_logger(__name__)
struct_logger = get_struct_logger(__name__)

# Global state
app_state = {
    "start_time": time.time(),
    "request_count": 0,
    "ollama_url": config.ollama.url,
    "ollama_model": config.ollama.model,
    "http_client": None
}

# Rate limiting storage (in production, use Redis)
rate_limit_storage: Dict[str, List[float]] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("🚀 Starting Cluely-Lite Server")
    
    # Create HTTP client
    app_state["http_client"] = httpx.AsyncClient(
        timeout=httpx.Timeout(config.ollama.timeout),
        limits=httpx.Limits(max_connections=10, max_keepalive_connections=5)
    )
    
    # Test Ollama connection
    try:
        await test_ollama_connection()
        logger.info("✅ Ollama connection verified")
    except Exception as e:
        logger.warning(f"⚠️  Ollama connection failed: {e}")
        logger.warning("   Server will run in fallback mode")
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down Cluely-Lite Server")
    if app_state["http_client"]:
        await app_state["http_client"].aclose()


# Create FastAPI app
app = FastAPI(
    title="Cluely-Lite Server",
    description="Local AI assistant server for desktop automation",
    version="2.0.0",
    lifespan=lifespan
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    # Accept localhost and 127.0.0.1 on any port during local development
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    # Include testclient host and common local variants
    allowed_hosts=[
        "localhost",
        "127.0.0.1",
        "*.local",
        "testserver",
        "localhost:8765",
        "127.0.0.1:8765",
    ],
)

# Security
security = HTTPBearer(auto_error=False)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """Rate limiting middleware"""
    if not config.security.rate_limit:
        return await call_next(request)
    
    client_ip = request.client.host
    current_time = time.time()
    
    # Clean old entries
    if client_ip in rate_limit_storage:
        rate_limit_storage[client_ip] = [
            req_time for req_time in rate_limit_storage[client_ip]
            if current_time - req_time < 60  # Keep last minute
        ]
    else:
        rate_limit_storage[client_ip] = []
    
    # Check rate limit
    if len(rate_limit_storage[client_ip]) >= config.server.max_requests_per_minute:
        return JSONResponse(
            status_code=429,
            content={"error": "Rate limit exceeded", "error_code": "RATE_LIMIT"}
        )
    
    # Add current request
    rate_limit_storage[client_ip].append(current_time)
    
    response = await call_next(request)
    return response


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Request logging middleware"""
    start_time = time.time()
    request_id = str(uuid.uuid4())
    
    # Log request
    struct_logger.info(
        "Request started",
        request_id=request_id,
        method=request.method,
        url=str(request.url),
        client_ip=request.client.host
    )
    
    response = await call_next(request)
    
    # Log response
    process_time = time.time() - start_time
    struct_logger.info(
        "Request completed",
        request_id=request_id,
        status_code=response.status_code,
        process_time=process_time
    )
    
    return response


@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint with basic info"""
    return {
        "service": "Cluely-Lite Server",
        "version": "2.0.0",
        "status": "running",
        "docs": "/docs"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    uptime = time.time() - app_state["start_time"]
    
    return HealthResponse(
        status="running",
        uptime_seconds=round(uptime, 2),
        requests_processed=app_state["request_count"],
        ollama_url=app_state["ollama_url"],
        ollama_model=app_state["ollama_model"],
        version="2.0.0"
    )


@app.get("/settings", response_model=SettingsResponse)
async def get_settings():
    """Get current settings"""
    return SettingsResponse(
        ollama_url=app_state["ollama_url"],
        ollama_model=app_state["ollama_model"],
        status="ok"
    )


@app.post("/settings", response_model=SettingsResponse)
async def update_settings(settings: SettingsUpdateRequest):
    """Update settings"""
    updated = {}
    
    if settings.ollama_url is not None:
        app_state["ollama_url"] = settings.ollama_url
        updated["ollama_url"] = settings.ollama_url
    
    if settings.ollama_model is not None:
        app_state["ollama_model"] = settings.ollama_model
        updated["ollama_model"] = settings.ollama_model
    
    if not updated:
        raise HTTPException(status_code=400, detail="No valid settings provided")
    
    logger.info(f"Settings updated: {updated}")
    
    return SettingsResponse(
        ollama_url=app_state["ollama_url"],
        ollama_model=app_state["ollama_model"],
        status="ok"
    )


@app.get("/models", response_model=ModelsResponse)
async def get_models():
    """Get available Ollama models"""
    try:
        models = await list_ollama_models()
        return ModelsResponse(
            models=models,
            default_model=app_state["ollama_model"]
        )
    except Exception as e:
        logger.error(f"Failed to list models: {e}")
        return ModelsResponse(models=[], default_model=app_state["ollama_model"])


@app.post("/command", response_model=CommandResponse)
async def process_command(request: CommandRequest):
    """Process AI command"""
    request_id = str(uuid.uuid4())
    app_state["request_count"] += 1
    
    logger.info(f"Processing command #{app_state['request_count']}: {request.instruction[:50]}...")
    
    start_time = time.time()
    
    try:
        # Use request model or default
        model = request.model or app_state["ollama_model"]
        
        # Generate response
        response_text = await generate_text(
            request.instruction,
            model=model,
            request_id=request_id
        )
        
        processing_time = time.time() - start_time
        
        logger.info(f"Command #{app_state['request_count']} completed in {processing_time:.2f}s")
        
        return CommandResponse(
            response=response_text,
            model_used=model,
            processing_time=processing_time,
            request_id=request_id
        )
        
    except Exception as e:
        logger.error(f"Error processing command #{app_state['request_count']}: {e}")
        msg = str(e)
        # Treat upstream Ollama failures as Bad Gateway to match expectations/tests
        status = 502 if "Ollama" in msg else 500
        raise HTTPException(status_code=status, detail=f"Error processing command: {msg}")


async def generate_text(prompt: str, model: str, request_id: str) -> str:
    """Generate text using Ollama"""
    url = app_state["ollama_url"]
    
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": config.ollama.temperature,
            "top_p": config.ollama.top_p,
            "max_tokens": config.ollama.max_tokens,
            "num_ctx": config.ollama.num_ctx
        }
    }
    
    try:
        response = await app_state["http_client"].post(url, json=payload)
        response.raise_for_status()
        
        data = response.json()
        result = data.get("response", "")
        
        if not isinstance(result, str):
            raise ValueError("Invalid response format from Ollama")
        
        return result
        
    except httpx.TimeoutException:
        raise Exception("Ollama request timed out")
    except httpx.HTTPStatusError as e:
        raise Exception(f"Ollama HTTP error: {e.response.status_code}")
    except Exception as e:
        raise Exception(f"Ollama connection error: {str(e)}")


async def test_ollama_connection():
    """Test Ollama connection"""
    try:
        response = await app_state["http_client"].get(
            app_state["ollama_url"].replace("/api/generate", "/api/tags")
        )
        response.raise_for_status()
    except Exception as e:
        raise Exception(f"Ollama connection test failed: {str(e)}")


async def list_ollama_models() -> List[str]:
    """List available Ollama models"""
    try:
        response = await app_state["http_client"].get(
            app_state["ollama_url"].replace("/api/generate", "/api/tags")
        )
        response.raise_for_status()
        
        data = response.json()
        models = [model.get("name", "") for model in data.get("models", [])]
        return [model for model in models if model]
        
    except Exception as e:
        logger.error(f"Failed to list models: {e}")
        return []


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "server:app",
        host=config.server.host,
        port=config.server.port,
        reload=False,
        log_level=config.logging.level.lower()
    )
