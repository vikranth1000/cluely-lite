"""
Configuration management for Cluely-Lite server
"""
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field


class ServerConfig(BaseModel):
    host: str = "127.0.0.1"
    port: int = 8765
    timeout: int = 120
    max_requests_per_minute: int = 60


class OllamaConfig(BaseModel):
    url: str = "http://127.0.0.1:11434/api/generate"
    model: str = "qwen2.5:3b"
    timeout: int = 120
    max_tokens: int = 1024
    temperature: float = 0.7
    top_p: float = 0.9
    num_ctx: int = 2048


class ElectronConfig(BaseModel):
    width: int = 420
    height: int = 120
    min_width: int = 320
    min_height: int = 100
    max_width: int = 800
    max_height: int = 600


class LoggingConfig(BaseModel):
    level: str = "INFO"
    file: str = "logs/cluely-lite.log"
    max_size: str = "10MB"
    backup_count: int = 5


class SecurityConfig(BaseModel):
    rate_limit: bool = True
    cors_origins: list[str] = ["http://localhost:*", "http://127.0.0.1:*"]
    max_content_length: str = "1MB"


class Config(BaseModel):
    server: ServerConfig = Field(default_factory=ServerConfig)
    ollama: OllamaConfig = Field(default_factory=OllamaConfig)
    electron: ElectronConfig = Field(default_factory=ElectronConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    security: SecurityConfig = Field(default_factory=SecurityConfig)

    @classmethod
    def load(cls, config_path: Optional[str] = None) -> "Config":
        """Load configuration from file or environment variables"""
        if config_path is None:
            # Resolve to repository root config.json from python/src/
            config_path = str(Path(__file__).resolve().parents[2] / "config.json")
        
        config_data = {}
        
        # Load from file if exists
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                config_data = json.load(f)
        
        # Override with environment variables
        env_overrides = {
            "server.host": os.getenv("CLUELY_HOST"),
            "server.port": os.getenv("CLUELY_PORT"),
            "ollama.url": os.getenv("CLUELY_OLLAMA_URL"),
            "ollama.model": os.getenv("CLUELY_OLLAMA_MODEL"),
            "logging.level": os.getenv("CLUELY_LOG_LEVEL"),
        }
        
        for key, value in env_overrides.items():
            if value is not None:
                keys = key.split(".")
                if len(keys) == 2:
                    if keys[0] not in config_data:
                        config_data[keys[0]] = {}
                    if keys[1] in ["port", "timeout", "max_requests_per_minute", "max_tokens", "num_ctx", "backup_count"]:
                        config_data[keys[0]][keys[1]] = int(value)
                    elif keys[1] in ["temperature", "top_p"]:
                        config_data[keys[0]][keys[1]] = float(value)
                    else:
                        config_data[keys[0]][keys[1]] = value
        
        return cls(**config_data)


# Global config instance
config = Config.load()
