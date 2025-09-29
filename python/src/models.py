"""
Pydantic models for Cluely-Lite API
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, validator
import re


class CommandRequest(BaseModel):
    """Request model for command endpoint"""
    instruction: str = Field(..., min_length=1, max_length=10000, description="The instruction to process")
    model: Optional[str] = Field(None, max_length=100, description="Optional model override")
    snapshot: Optional[List[Dict[str, Any]]] = Field(None, description="Optional UI snapshot data")
    
    @validator('instruction')
    def validate_instruction(cls, v):
        if not v or not v.strip():
            raise ValueError('Instruction cannot be empty')
        return v.strip()
    
    @validator('model')
    def validate_model(cls, v):
        if v and not re.match(r'^[a-zA-Z0-9._:-]+$', v):
            raise ValueError('Invalid model name format')
        return v


class CommandResponse(BaseModel):
    """Response model for command endpoint"""
    response: str = Field(..., description="The AI response")
    model_used: str = Field(..., description="The model that was used")
    processing_time: float = Field(..., description="Processing time in seconds")
    request_id: str = Field(..., description="Unique request identifier")


class ErrorResponse(BaseModel):
    """Error response model"""
    error: str = Field(..., description="Error message")
    error_code: str = Field(..., description="Error code")
    request_id: Optional[str] = Field(None, description="Request identifier if available")


class HealthResponse(BaseModel):
    """Health check response model"""
    status: str = Field(..., description="Service status")
    uptime_seconds: float = Field(..., description="Uptime in seconds")
    requests_processed: int = Field(..., description="Total requests processed")
    ollama_url: str = Field(..., description="Ollama URL")
    ollama_model: str = Field(..., description="Current Ollama model")
    version: str = Field(..., description="Service version")


class SettingsResponse(BaseModel):
    """Settings response model"""
    ollama_url: str = Field(..., description="Ollama URL")
    ollama_model: str = Field(..., description="Current Ollama model")
    status: str = Field(..., description="Response status")


class SettingsUpdateRequest(BaseModel):
    """Settings update request model"""
    ollama_url: Optional[str] = Field(None, max_length=500, description="New Ollama URL")
    ollama_model: Optional[str] = Field(None, max_length=100, description="New Ollama model")
    
    @validator('ollama_url')
    def validate_ollama_url(cls, v):
        if v and not re.match(r'^https?://', v):
            raise ValueError('Ollama URL must start with http:// or https://')
        return v
    
    @validator('ollama_model')
    def validate_ollama_model(cls, v):
        if v and not re.match(r'^[a-zA-Z0-9._:-]+$', v):
            raise ValueError('Invalid model name format')
        return v


class ModelsResponse(BaseModel):
    """Models list response model"""
    models: List[str] = Field(..., description="Available models")
    default_model: str = Field(..., description="Default model")


class SnapshotNode(BaseModel):
    """UI snapshot node model"""
    id: str = Field(..., description="Node ID")
    role: str = Field(..., description="UI element role")
    title: str = Field(..., description="Element title")
    enabled: bool = Field(..., description="Whether element is enabled")
    frame: Dict[str, float] = Field(..., description="Element frame coordinates")
    
    class Config:
        schema_extra = {
            "example": {
                "id": "button_1",
                "role": "AXButton",
                "title": "Save",
                "enabled": True,
                "frame": {"x": 100, "y": 100, "w": 80, "h": 30}
            }
        }
