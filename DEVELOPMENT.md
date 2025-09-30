# Development Guide

## 🛠️ **Development Setup**

### Prerequisites
- macOS 14.0+
- Python 3.9+
- Node.js 18+
- Xcode Command Line Tools
- Git

### Initial Setup
```bash
git clone <repository-url>
cd cluely-lite
./setup.sh
```

### Development Environment
```bash
# Install development dependencies
pip install pytest pytest-asyncio httpx
npm install --save-dev

# Run tests
python -m pytest tests/ -v

# Start development servers
cd python/src && python server.py &
cd electron && npm run dev
```

## 🏗️ **Architecture Overview**

### Project Structure
```
cluely-lite/
├── python/                 # FastAPI backend
│   ├── src/
│   │   ├── server.py      # Main FastAPI app
│   │   ├── config.py      # Configuration management
│   │   ├── models.py      # Pydantic models
│   │   └── logger.py      # Logging setup
│   └── requirements.txt   # Python dependencies
├── electron/              # Electron frontend
│   ├── main.js           # Main process
│   ├── preload.js        # Preload script
│   ├── renderer/
│   │   ├── index.html    # UI template
│   │   ├── app.js        # UI controller
│   │   └── styles.css    # Styles
│   └── package.json      # Electron config
├── axhelper/             # Swift CLI (optional)
├── tests/                # Test suite
└── config.json          # Global configuration
```

## 🔧 **Development Workflow**

### 1. **Backend Development (Python)**
```bash
cd python/src
python server.py
```

**Key Files:**
- `server.py` - Main FastAPI application
- `config.py` - Configuration management
- `models.py` - Pydantic data models
- `logger.py` - Logging configuration

**Testing:**
```bash
cd python
python -m pytest tests/ -v
```

### 2. **Frontend Development (Electron)**
```bash
cd electron
npm run dev
```

**Key Files:**
- `main.js` - Electron main process
- `preload.js` - Secure API bridge
- `renderer/app.js` - UI controller
- `renderer/styles.css` - Styles

**Development Mode:**
- DevTools enabled
- Hot reload
- Debug logging

### 3. **Swift Helper Development**
```bash
cd axhelper
swift build -c release
```

**Key Files:**
- `Sources/AXHelper/main.swift` - AX automation logic

## 🧪 **Testing**

### Test Structure
```
tests/
├── test_server.py        # Server tests
├── test_models.py        # Model validation tests
├── test_integration.py   # Integration tests
└── conftest.py          # Test configuration
```

### Running Tests
```bash
# All tests
python -m pytest tests/ -v

# Specific test file
python -m pytest tests/test_server.py -v

# With coverage
python -m pytest tests/ --cov=python/src --cov-report=html
```

### Test Categories
- **Unit Tests**: Individual component testing
- **Integration Tests**: Component interaction testing
- **API Tests**: HTTP endpoint testing
- **UI Tests**: Electron interface testing

## 📝 **Code Standards**

### Python
- **Style**: PEP 8
- **Type Hints**: Required for all functions
- **Documentation**: Docstrings for all public functions
- **Testing**: Pytest with async support

### JavaScript/TypeScript
- **Style**: ESLint + Prettier
- **Type Safety**: JSDoc comments
- **Testing**: Jest (if needed)

### Swift
- **Style**: Swift API Design Guidelines
- **Documentation**: Swift DocC comments
- **Testing**: XCTest (if needed)

## 🚀 **Build Process**

### Development Build
```bash
# Python
cd python && pip install -r requirements.txt

# Swift
cd axhelper && swift build -c release

# Electron
cd electron && npm install
```

### Production Build
```bash
# Build all components
./setup.sh

# Create distribution
cd electron && npm run dist
```

## 🔍 **Debugging**

### Python Server
```bash
# Debug mode
CLUELY_LOG_LEVEL=DEBUG python server.py

# Check logs
tail -f logs/cluely-lite.log
```

### Electron App
```bash
# Development mode with DevTools
NODE_ENV=development npm start

# Debug logging
DEBUG=* npm start
```

### Swift Helper
```bash
# Debug build
swift build

# Run with debug output
./axhelper/.build/debug/axhelper snapshot
```

## 📊 **Performance Monitoring**

### Metrics
- **Response Time**: API endpoint performance
- **Memory Usage**: Application memory consumption
- **CPU Usage**: Processing overhead
- **Error Rate**: Failure tracking

### Logging
- **Structured Logging**: JSON format
- **Log Levels**: DEBUG, INFO, WARNING, ERROR
- **Rotation**: Automatic log rotation
- **Centralized**: Single log file

## 🔒 **Security**

### Backend Security
- **Input Validation**: Pydantic models
- **Rate Limiting**: Request throttling
- **CORS**: Cross-origin protection
- **Error Handling**: Secure error messages

### Frontend Security
- **CSP**: Content Security Policy
- **Context Isolation**: Secure IPC
- **No Node Integration**: Sandboxed renderer
- **HTTPS**: Secure communication

## 🚀 **Deployment**

### Local Distribution
```bash
# Build distribution
cd electron && npm run dist

# Output: dist/Cluely-Lite-2.0.0.dmg
```

### CI/CD Pipeline
1. **Test**: Run full test suite
2. **Build**: Compile all components
3. **Package**: Create distribution
4. **Sign**: Code signing (if configured)
5. **Deploy**: Release distribution

## 📚 **Documentation**

### API Documentation
- **OpenAPI**: Auto-generated from FastAPI
- **Interactive**: Swagger UI at `/docs`
- **Examples**: Request/response samples

### User Documentation
- **README.md**: Quick start guide
- **DEVELOPMENT.md**: This file
- **API.md**: API reference
- **TROUBLESHOOTING.md**: Common issues

## 🤝 **Contributing**

### Pull Request Process
1. **Fork**: Create feature branch
2. **Develop**: Implement changes
3. **Test**: Add/update tests
4. **Document**: Update documentation
5. **Submit**: Create pull request

### Code Review
- **Automated**: CI/CD checks
- **Manual**: Peer review
- **Standards**: Code style compliance
- **Testing**: Test coverage requirements

## 🐛 **Troubleshooting**

### Common Issues
- **Port Conflicts**: Check port availability
- **Dependencies**: Verify all packages installed
- **Permissions**: Check accessibility permissions
- **Ollama**: Ensure Ollama is running

### Debug Tools
- **Logs**: Check application logs
- **DevTools**: Electron DevTools
- **Network**: Monitor API calls
- **Console**: Check error messages

## 📈 **Performance Optimization**

### Backend
- **Async/Await**: Non-blocking operations
- **Connection Pooling**: HTTP client optimization
- **Caching**: Response caching
- **Compression**: Response compression

### Frontend
- **Lazy Loading**: Defer non-critical resources
- **Debouncing**: Input throttling
- **Memory Management**: Proper cleanup
- **Rendering**: Efficient DOM updates

---

**Happy coding! 🚀**
