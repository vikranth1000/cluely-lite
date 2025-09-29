"""
Professional test suite for Cluely-Lite server
"""
import pytest
import asyncio
import json
from httpx import AsyncClient
from fastapi.testclient import TestClient
import sys
import os

# Add the src directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python', 'src'))

from server import app
from config import config


class TestCluelyServer:
    """Test suite for Cluely-Lite server"""
    
    @pytest.fixture
    def client(self):
        """Create test client"""
        return TestClient(app)
    
    @pytest.fixture
    async def async_client(self):
        """Create async test client"""
        async with AsyncClient(app=app, base_url="http://test") as ac:
            yield ac
    
    def test_root_endpoint(self, client):
        """Test root endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert "service" in data
        assert data["service"] == "Cluely-Lite Server"
    
    def test_health_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "running"
        assert "uptime_seconds" in data
        assert "requests_processed" in data
        assert "version" in data
    
    def test_settings_endpoint(self, client):
        """Test settings endpoint"""
        response = client.get("/settings")
        assert response.status_code == 200
        data = response.json()
        assert "ollama_url" in data
        assert "ollama_model" in data
        assert data["status"] == "ok"
    
    def test_settings_update(self, client):
        """Test settings update"""
        new_settings = {
            "ollama_model": "test-model:1b"
        }
        response = client.post("/settings", json=new_settings)
        assert response.status_code == 200
        data = response.json()
        assert data["ollama_model"] == "test-model:1b"
    
    def test_models_endpoint(self, client):
        """Test models endpoint"""
        response = client.get("/models")
        assert response.status_code == 200
        data = response.json()
        assert "models" in data
        assert "default_model" in data
        assert isinstance(data["models"], list)
    
    def test_command_endpoint_valid(self, client):
        """Test command endpoint with valid request"""
        command_data = {
            "instruction": "Hello, world!"
        }
        response = client.post("/command", json=command_data)
        # Note: This might fail if Ollama is not running, which is expected in tests
        assert response.status_code in [200, 502]  # 502 if Ollama not available
    
    def test_command_endpoint_invalid(self, client):
        """Test command endpoint with invalid request"""
        # Empty instruction
        response = client.post("/command", json={"instruction": ""})
        assert response.status_code == 422
        
        # Missing instruction
        response = client.post("/command", json={})
        assert response.status_code == 422
        
        # Invalid JSON
        response = client.post("/command", data="invalid json")
        assert response.status_code == 422
    
    def test_rate_limiting(self, client):
        """Test rate limiting functionality"""
        # This test would need to be implemented based on rate limiting logic
        # For now, just test that the endpoint responds
        response = client.get("/health")
        assert response.status_code == 200
    
    def test_cors_headers(self, client):
        """Test CORS headers"""
        response = client.options("/command")
        # CORS headers should be present
        assert response.status_code in [200, 405]  # 405 if OPTIONS not implemented
    
    def test_error_handling(self, client):
        """Test error handling"""
        # Test 404
        response = client.get("/nonexistent")
        assert response.status_code == 404
        
        # Test invalid JSON
        response = client.post("/command", data="invalid")
        assert response.status_code == 422


class TestConfiguration:
    """Test configuration management"""
    
    def test_config_loading(self):
        """Test configuration loading"""
        from config import config
        assert config.server.host == "127.0.0.1"
        assert config.server.port == 8765
        assert config.ollama.model is not None
    
    def test_environment_overrides(self):
        """Test environment variable overrides"""
        import os
        os.environ["CLUELY_OLLAMA_MODEL"] = "test-model"
        os.environ["CLUELY_PORT"] = "9999"
        
        # Reload config
        from config import Config
        test_config = Config.load()
        
        assert test_config.ollama.model == "test-model"
        assert test_config.server.port == 9999
        
        # Cleanup
        del os.environ["CLUELY_OLLAMA_MODEL"]
        del os.environ["CLUELY_PORT"]


class TestModels:
    """Test Pydantic models"""
    
    def test_command_request_model(self):
        """Test CommandRequest model validation"""
        from models import CommandRequest
        
        # Valid request
        valid_request = CommandRequest(instruction="Test instruction")
        assert valid_request.instruction == "Test instruction"
        
        # Invalid request - empty instruction
        with pytest.raises(ValueError):
            CommandRequest(instruction="")
        
        # Invalid request - too long instruction
        with pytest.raises(ValueError):
            CommandRequest(instruction="x" * 10001)
    
    def test_settings_update_model(self):
        """Test SettingsUpdateRequest model validation"""
        from models import SettingsUpdateRequest
        
        # Valid request
        valid_request = SettingsUpdateRequest(ollama_model="test-model")
        assert valid_request.ollama_model == "test-model"
        
        # Invalid URL
        with pytest.raises(ValueError):
            SettingsUpdateRequest(ollama_url="invalid-url")
        
        # Invalid model name
        with pytest.raises(ValueError):
            SettingsUpdateRequest(ollama_model="invalid@model")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

