/**
 * Cluely-Lite Renderer Process
 * Professional UI controller with error handling and state management
 */
class CluelyApp {
  constructor() {
    this.state = {
      isProcessing: false,
      isConnected: false,
      lastResponse: null,
      windowSize: { width: 420, height: 120 },
      toolsVisible: false
    }
    
    this.elements = this.initializeElements()
    this.setupEventListeners()
    this.initializeApp()
  }

  initializeElements() {
    return {
      // Main elements
      app: document.getElementById('app'),
      pill: document.getElementById('pill'),
      input: document.getElementById('input'),
      send: document.getElementById('send'),
      sendIcon: document.getElementById('send-icon'),
      loadingSpinner: document.getElementById('loading-spinner'),
      
      // Tools
      tools: document.getElementById('tools'),
      btnSnap: document.getElementById('btn-snap'),
      btnClick: document.getElementById('btn-click'),
      btnFocus: document.getElementById('btn-focus'),
      btnType: document.getElementById('btn-type'),
      axTarget: document.getElementById('ax-target'),
      axText: document.getElementById('ax-text'),
      
      // Transcript
      transcript: document.getElementById('transcript'),
      output: document.getElementById('output'),
      close: document.getElementById('close'),
      copy: document.getElementById('copy'),
      modelInfo: document.getElementById('model-info'),
      processingTime: document.getElementById('processing-time'),
      
      // Status
      status: document.getElementById('status'),
      statusText: document.getElementById('status-text'),
      connectionStatus: document.getElementById('connection-status'),
      axStatus: document.getElementById('ax-status'),
      
      // Error handling
      errorToast: document.getElementById('error-toast'),
      errorMessage: document.getElementById('error-message'),
      errorClose: document.getElementById('error-close'),
      
      // Resize handles
      resizeRight: document.querySelector('.resize-right'),
      resizeBottom: document.getElementById('resize-bottom')
    }
  }

  setupEventListeners() {
    // Input handling
    this.elements.input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        this.handleSubmit()
      }
    })

    this.elements.input.addEventListener('input', this.debounce(() => {
      this.updateStatus('Ready')
    }, 300))

    // Send button
    this.elements.send.addEventListener('click', () => this.handleSubmit())

    // Tools
    this.elements.btnSnap.addEventListener('click', () => this.handleSnapshot())
    this.elements.btnClick.addEventListener('click', () => this.handleClick())
    this.elements.btnFocus.addEventListener('click', () => this.handleFocus())
    this.elements.btnType.addEventListener('click', () => this.handleType())

    // Transcript controls
    this.elements.close.addEventListener('click', () => this.hideTranscript())
    this.elements.copy.addEventListener('click', () => this.copyToClipboard())

    // Error handling
    this.elements.errorClose.addEventListener('click', () => this.hideError())

    // Resize handling
    this.setupResizeHandlers()

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideTranscript()
        this.hideError()
      }
      if (e.key === 'Enter' && e.ctrlKey) {
        this.toggleTools()
      }
    })

    // Window events
    window.addEventListener('resize', () => {
      this.updateWindowSize()
    })
  }

  async initializeApp() {
    try {
      // Check server connection
      await this.checkServerConnection()
      
      // Check AX helper
      await this.checkAxHelper()
      
      // Show status
      this.showStatus()
      this.updateStatus('Ready')
      
      // Focus input
      this.elements.input.focus()
      
      console.log('✅ Cluely-Lite initialized successfully')
    } catch (error) {
      console.error('❌ Initialization failed:', error)
      this.showError('Failed to initialize app. Please check the server.')
    }
  }

  async checkServerConnection() {
    try {
      const response = await fetch('http://127.0.0.1:8765/health')
      if (response.ok) {
        this.state.isConnected = true
        this.elements.connectionStatus.textContent = '🟢'
        this.elements.connectionStatus.title = 'Server Connected'
        return true
      }
    } catch (error) {
      console.warn('Server connection check failed:', error)
    }
    
    this.state.isConnected = false
    this.elements.connectionStatus.textContent = '🔴'
    this.elements.connectionStatus.title = 'Server Disconnected'
    return false
  }

  async checkAxHelper() {
    try {
      const result = await window.cluely.ax.snapshot()
      if (result.success) {
        this.elements.axStatus.textContent = '✅'
        this.elements.axStatus.title = 'AX Helper Ready'
        return true
      }
    } catch (error) {
      console.warn('AX helper check failed:', error)
    }
    
    this.elements.axStatus.textContent = '❓'
    this.elements.axStatus.title = 'AX Helper Unknown'
    return false
  }

  async handleSubmit() {
    const text = this.elements.input.value.trim()
    if (!text || this.state.isProcessing) return

    this.state.isProcessing = true
    this.updateUI()
    this.updateStatus('Processing...')

    try {
      const result = await window.cluely.generate(text)
      
      if (result.success) {
        this.state.lastResponse = result
        this.showResponse(result)
        this.elements.input.value = ''
        this.updateStatus('Ready')
      } else {
        throw new Error(result.error || 'Unknown error occurred')
      }
    } catch (error) {
      console.error('Generation error:', error)
      this.showError(`Failed to generate response: ${error.message}`)
      this.updateStatus('Error')
    } finally {
      this.state.isProcessing = false
      this.updateUI()
    }
  }

  showResponse(result) {
    this.elements.output.textContent = result.response || '(empty response)'
    
    // Update metadata
    if (result.model) {
      this.elements.modelInfo.textContent = result.model
    }
    
    if (result.processingTime) {
      this.elements.processingTime.textContent = window.cluely.utils.formatTime(result.processingTime)
    }
    
    // Show transcript
    this.elements.transcript.classList.remove('hidden')
    this.elements.transcript.classList.add('slide-up')
    
    // Auto-hide after delay if no interaction
    setTimeout(() => {
      if (!this.elements.transcript.matches(':hover')) {
        // Keep transcript visible for now, user can close manually
      }
    }, 5000)
  }

  hideTranscript() {
    this.elements.transcript.classList.add('hidden')
    this.elements.transcript.classList.remove('slide-up')
  }

  async handleSnapshot() {
    this.updateStatus('Taking snapshot...')
    
    try {
      const result = await window.cluely.ax.snapshot()
      
      if (result.success) {
        this.elements.output.textContent = JSON.stringify(result.data, null, 2)
        this.elements.transcript.classList.remove('hidden')
        this.elements.transcript.classList.add('slide-up')
        this.updateStatus('Snapshot complete')
      } else {
        throw new Error(result.error || 'Snapshot failed')
      }
    } catch (error) {
      console.error('Snapshot error:', error)
      this.showError(`Snapshot failed: ${error.message}`)
      this.updateStatus('Snapshot failed')
    }
  }

  async handleClick() {
    const target = this.elements.axTarget.value.trim()
    if (!target) {
      this.showError('Please enter a target element')
      return
    }

    this.updateStatus(`Clicking "${target}"...`)
    
    try {
      const result = await window.cluely.ax.click(target)
      
      if (result.success) {
        this.updateStatus(`Clicked: ${target}`)
        this.showToast(`Clicked: ${target}`, 'success')
      } else {
        throw new Error(result.error || 'Click failed')
      }
    } catch (error) {
      console.error('Click error:', error)
      this.showError(`Click failed: ${error.message}`)
      this.updateStatus('Click failed')
    }
  }

  async handleFocus() {
    const target = this.elements.axTarget.value.trim()
    if (!target) {
      this.showError('Please enter a target element')
      return
    }

    this.updateStatus(`Focusing "${target}"...`)
    
    try {
      const result = await window.cluely.ax.focus(target)
      
      if (result.success) {
        this.updateStatus(`Focused: ${target}`)
        this.showToast(`Focused: ${target}`, 'success')
      } else {
        throw new Error(result.error || 'Focus failed')
      }
    } catch (error) {
      console.error('Focus error:', error)
      this.showError(`Focus failed: ${error.message}`)
      this.updateStatus('Focus failed')
    }
  }

  async handleType() {
    const target = this.elements.axTarget.value.trim()
    const text = this.elements.axText.value
    
    if (!target) {
      this.showError('Please enter a target element')
      return
    }

    this.updateStatus(`Typing into "${target}"...`)
    
    try {
      const result = await window.cluely.ax.type(text, target)
      
      if (result.success) {
        this.updateStatus(`Typed into: ${target}`)
        this.showToast(`Typed into: ${target}`, 'success')
        this.elements.axText.value = ''
      } else {
        throw new Error(result.error || 'Type failed')
      }
    } catch (error) {
      console.error('Type error:', error)
      this.showError(`Type failed: ${error.message}`)
      this.updateStatus('Type failed')
    }
  }

  async copyToClipboard() {
    try {
      await navigator.clipboard.writeText(this.elements.output.textContent)
      this.showToast('Copied to clipboard', 'success')
    } catch (error) {
      console.error('Copy failed:', error)
      this.showError('Failed to copy to clipboard')
    }
  }

  toggleTools() {
    this.state.toolsVisible = !this.state.toolsVisible
    this.elements.tools.classList.toggle('hidden', !this.state.toolsVisible)
  }

  showStatus() {
    this.elements.status.classList.remove('hidden')
  }

  hideStatus() {
    this.elements.status.classList.add('hidden')
  }

  updateStatus(message) {
    this.elements.statusText.textContent = message
  }

  showError(message) {
    this.elements.errorMessage.textContent = message
    this.elements.errorToast.classList.remove('hidden')
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.hideError()
    }, 5000)
  }

  hideError() {
    this.elements.errorToast.classList.add('hidden')
  }

  showToast(message, type = 'info') {
    // Simple toast implementation
    const toast = document.createElement('div')
    toast.className = `toast toast-${type}`
    toast.textContent = message
    toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: ${type === 'success' ? '#4caf50' : '#2196f3'};
      color: white;
      padding: 12px 16px;
      border-radius: 8px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
      z-index: 1002;
      animation: slideIn 0.3s ease;
    `
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  updateUI() {
    // Update send button state
    this.elements.send.disabled = this.state.isProcessing
    this.elements.sendIcon.classList.toggle('hidden', this.state.isProcessing)
    this.elements.loadingSpinner.classList.toggle('hidden', !this.state.isProcessing)
    
    // Update input state
    this.elements.input.disabled = this.state.isProcessing
  }

  updateWindowSize() {
    this.state.windowSize = {
      width: window.outerWidth,
      height: window.outerHeight
    }
  }

  setupResizeHandlers() {
    // Width resize
    let startX, startW
    this.elements.resizeRight.addEventListener('mousedown', (e) => {
      e.preventDefault()
      startX = e.screenX
      startW = window.outerWidth
      
      const onMouseMove = (e) => {
        const delta = e.screenX - startX
        const newWidth = Math.max(320, startW + delta)
        window.resizeTo(newWidth, window.outerHeight)
      }
      
      const onMouseUp = () => {
        document.removeEventListener('mousemove', onMouseMove)
        document.removeEventListener('mouseup', onMouseUp)
      }
      
      document.addEventListener('mousemove', onMouseMove)
      document.addEventListener('mouseup', onMouseUp)
    })

    // Height resize
    let startY, startH
    this.elements.resizeBottom.addEventListener('mousedown', (e) => {
      e.preventDefault()
      startY = e.screenY
      startH = window.outerHeight
      
      const onMouseMove = (e) => {
        const delta = e.screenY - startY
        const newHeight = Math.max(100, startH + delta)
        window.resizeTo(window.outerWidth, newHeight)
        
        // Update resize handle position
        this.elements.resizeBottom.style.top = (newHeight - 18) + 'px'
      }
      
      const onMouseUp = () => {
        document.removeEventListener('mousemove', onMouseMove)
        document.removeEventListener('mouseup', onMouseUp)
      }
      
      document.addEventListener('mousemove', onMouseMove)
      document.addEventListener('mouseup', onMouseUp)
    })
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  new CluelyApp()
})
