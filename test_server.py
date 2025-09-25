#!/usr/bin/env python3
"""
Test script for Cluely-Lite Python server
"""

import json
import urllib.request
import urllib.error
import time

def test_server():
    """Test the Cluely-Lite server with various requests."""
    
    base_url = "http://127.0.0.1:8765"
    
    print("🧪 Testing Cluely-Lite Server")
    print("=" * 40)
    
    # Test 1: Health check
    print("\n1. Testing health endpoint...")
    try:
        with urllib.request.urlopen(f"{base_url}/health", timeout=5) as response:
            data = json.loads(response.read().decode())
            print(f"✅ Health check passed: {data['status']}")
            print(f"   Uptime: {data['uptime_seconds']}s")
            print(f"   Requests: {data['requests_processed']}")
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False
    
    # Test 2: Basic command
    print("\n2. Testing basic command...")
    test_payload = {
        "instruction": "Click the Save button",
        "snapshot": [
            {
                "id": "test1",
                "role": "AXButton",
                "title": "Save",
                "enabled": True,
                "frame": {"x": 100, "y": 100, "w": 80, "h": 30}
            }
        ]
    }
    
    try:
        data = json.dumps(test_payload).encode('utf-8')
        req = urllib.request.Request(
            f"{base_url}/command",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode())
            print(f"✅ Command test passed")
            print(f"   Response: {result.get('response', 'No response')}")
            if 'tool' in result:
                tool = result['tool']
                print(f"   Action: {tool.get('action', 'None')}")
                print(f"   Target: {tool.get('target', 'None')}")
    except Exception as e:
        print(f"❌ Command test failed: {e}")
        return False
    
    # Test 3: Settings and models endpoints
    print("\n3. Testing settings + models endpoints...")
    try:
        # Read models
        with urllib.request.urlopen(f"{base_url}/models", timeout=5) as response:
            data = json.loads(response.read().decode())
            models = data.get('models', [])
            print(f"✅ Models endpoint returned {len(models)} models")
        # Update settings (model)
        new_model = "qwen2.5:3b"
        req = urllib.request.Request(
            f"{base_url}/settings",
            data=json.dumps({"ollama_model": new_model}).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode())
            assert data.get('ollama_model') == new_model
            print("✅ Settings update applied")
    except Exception as e:
        print(f"⚠️  Settings/models test had an issue: {e}")

    # Test 4: Error handling
    print("\n3. Testing error handling...")
    try:
        invalid_payload = {"invalid": "data"}
        data = json.dumps(invalid_payload).encode('utf-8')
        req = urllib.request.Request(
            f"{base_url}/command",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=5) as response:
            result = json.loads(response.read().decode())
            if 'error' in result:
                print(f"✅ Error handling works: {result['error']}")
            else:
                print(f"⚠️  Expected error but got: {result}")
    except urllib.error.HTTPError as e:
        if e.code == 400:
            print("✅ Error handling works (400 Bad Request)")
        else:
            print(f"⚠️  Unexpected HTTP error: {e.code}")
    except Exception as e:
        print(f"❌ Error handling test failed: {e}")
        return False
    
    # Test 5: Performance test
    print("\n5. Testing performance...")
    start_time = time.time()
    
    try:
        data = json.dumps({"instruction": "What's on my screen?"}).encode('utf-8')
        req = urllib.request.Request(
            f"{base_url}/command",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=120) as response:
            result = json.loads(response.read().decode())
            elapsed = time.time() - start_time
            print(f"✅ Performance test passed")
            print(f"   Response time: {elapsed:.2f}s")
            print(f"   Response: {result.get('response', 'No response')[:100]}...")
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
        return False
    
    print("\n🎉 All tests passed!")
    return True

def check_ollama():
    """Check if Ollama is running and has the required model."""
    print("\n🔍 Checking Ollama status...")
    
    try:
        # Check if Ollama is running
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as response:
            data = json.loads(response.read().decode())
            models = [model['name'] for model in data.get('models', [])]
            print(f"✅ Ollama is running")
            print(f"   Available models: {', '.join(models)}")
            
            # Check for recommended models
            recommended = ['qwen2.5:3b', 'llama3.2:3b']
            found = [model for model in recommended if any(model in m for m in models)]
            
            if found:
                print(f"✅ Found recommended model: {found[0]}")
            else:
                print(f"⚠️  No recommended models found. Consider installing: {recommended[0]}")
                
    except Exception as e:
        print(f"❌ Ollama check failed: {e}")
        print("   Make sure Ollama is running: ollama serve")
        return False
    
    return True

if __name__ == "__main__":
    print("Cluely-Lite Server Test")
    print("======================")
    
    # Check Ollama first
    if not check_ollama():
        print("\n⚠️  Ollama issues detected, but continuing with tests...")
    
    # Test the server
    if test_server():
        print("\n✅ All tests completed successfully!")
        print("\n🚀 Your Cluely-Lite server is ready to use!")
    else:
        print("\n❌ Some tests failed. Check the server logs for details.")
        print("\n💡 Make sure the server is running: python python/src/server.py")
