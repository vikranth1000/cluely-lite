class CluelyPill {
  constructor() {
    this.state = {
      isProcessing: false,
      incognito: false,
      isListening: false,
      conversationStarted: false,
    }

    this.elements = this.cacheElements()
    this.bindEvents()
    this.mount()
  }

  cacheElements() {
    return {
      pill: document.getElementById('pill'),
      prompt: document.getElementById('prompt-input'),
      listenBtn: document.getElementById('listen-btn'),
      incognitoBtn: document.getElementById('incognito-btn'),
      menuBtn: document.getElementById('menu-btn'),
      toastContainer: document.getElementById('toast-container'),
      outputs: document.getElementById('outputs'),
    }
  }

  bindEvents() {
    this.elements.prompt.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault()
        this.handleSubmit()
      }
    })

    this.elements.prompt.addEventListener('input', () => {
      this.hideProcessing()
    })

    this.elements.listenBtn.addEventListener('click', () => {
      this.toggleListening()
    })

    this.elements.menuBtn.addEventListener('click', () => {
      this.showToast('Quick actions coming soon', 'info')
    })

    this.elements.incognitoBtn.addEventListener('click', async () => {
      this.state.incognito = !this.state.incognito
      this.elements.incognitoBtn.classList.toggle('is-incognito', this.state.incognito)
      this.elements.incognitoBtn.setAttribute('aria-pressed', String(this.state.incognito))
      await window.cluely.setIncognito(this.state.incognito)
      this.showToast(this.state.incognito ? 'Incognito enabled' : 'Incognito disabled', 'info')
    })

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        this.elements.prompt.blur()
      }
    })
  }

  async mount() {
    // Debug: Check if bridge is available
    console.log('=== CLUELY MOUNT DEBUG ===')
    console.log('window.cluely exists:', !!window.cluely)
    console.log('window.cluely.generate type:', typeof window.cluely?.generate)
    console.log('window.cluely.probe type:', typeof window.cluely?.probe)
    console.log('=========================')
    
    try {
      await window.cluely.setPassive(false)
    } catch (error) {
      console.warn('Passive mode failed:', error)
    }

    this.ensureOutputsContainer()
    try {
      const probe = await window.cluely.probe()
      console.log('Probe result:', probe)
      if (!probe?.ok) {
        this.showToast('⚠️ Ollama not reachable. Start "ollama serve"', 'error', 4500)
      } else {
        this.showToast('✓ Ready', 'success', 2000)
      }
    } catch (e) {
      console.error('Probe error:', e)
      this.showToast('⚠️ Ollama probe failed', 'error', 4000)
    }
    this.elements.prompt.focus({ preventScroll: true })
  }

  async handleSubmit() {
    const prompt = this.elements.prompt.value.trim()
    if (!prompt || this.state.isProcessing) return

    this.state.isProcessing = true
    this.showProcessing()

    // Add user message to chat immediately
    this.addUserMessage(prompt)
    this.elements.prompt.value = ''

    try {
      // Call the bridge API directly
      const result = await window.cluely.generate(prompt)
      
      console.log('Generate result:', result) // Debug log
      
      if (!result) {
        throw new Error('No response from AI service')
      }
      
      if (!result.success) {
        throw new Error(result.error || 'Request failed')
      }
      
      const text = typeof result.response === 'string' ? result.response.trim() : ''
      this.addAIMessage(text || '(empty response)')
    } catch (error) {
      console.error('Generation failed:', error)
      const errorMsg = error?.message || 'Generation failed'
      this.addAIMessage(`Error: ${errorMsg}`)
      this.showToast(`Failed: ${errorMsg}`, 'error', 3000)
    } finally {
      this.state.isProcessing = false
      this.hideProcessing()
    }
  }

  showProcessing() {
    this.elements.pill.classList.add('is-processing')
  }

  hideProcessing() {
    this.elements.pill.classList.remove('is-processing')
  }

  toggleListening() {
    this.state.isListening = !this.state.isListening
    this.elements.listenBtn.classList.toggle('is-active', this.state.isListening)
    this.elements.listenBtn.setAttribute('aria-pressed', String(this.state.isListening))
    const status = this.state.isListening ? 'Listening…' : 'Voice capture stopped'
    this.showToast(status, this.state.isListening ? 'info' : 'info')
  }

  showToast(message, variant = 'info', duration = 2800) {
    if (!message) return
    const toast = document.createElement('div')
    toast.className = `toast ${variant}`
    toast.textContent = message
    this.elements.toastContainer.appendChild(toast)
    requestAnimationFrame(() => toast.classList.add('show'))
    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 250)
    }, duration)
  }

  ensureConversationContainer() {
    if (!this.state.conversationStarted) {
      this.ensureOutputsContainer()
      this.elements.outputs.innerHTML = '' // Clear any old tabs
      
      const conversationTab = document.createElement('div')
      conversationTab.id = 'conversation-tab'
      conversationTab.className = 'conversation-tab'
      
      const header = document.createElement('div')
      header.className = 'conversation-header'
      
      const title = document.createElement('span')
      title.textContent = 'Conversation'
      
      const clearBtn = document.createElement('button')
      clearBtn.className = 'clear-conversation-btn'
      clearBtn.textContent = 'Clear'
      clearBtn.setAttribute('aria-label', 'Clear conversation')
      clearBtn.addEventListener('click', () => this.clearConversation())
      
      header.appendChild(title)
      header.appendChild(clearBtn)
      
      const messagesContainer = document.createElement('div')
      messagesContainer.id = 'messages-container'
      messagesContainer.className = 'messages-container'
      
      conversationTab.appendChild(header)
      conversationTab.appendChild(messagesContainer)
      this.elements.outputs.appendChild(conversationTab)
      
      requestAnimationFrame(() => {
        requestAnimationFrame(() => conversationTab.classList.add('show'))
      })
      
      this.state.conversationStarted = true
    }
  }

  addUserMessage(text) {
    this.ensureConversationContainer()
    const messagesContainer = document.getElementById('messages-container')
    
    const messageDiv = document.createElement('div')
    messageDiv.className = 'message user-message'
    
    const bubble = document.createElement('div')
    bubble.className = 'message-bubble'
    bubble.textContent = text
    
    messageDiv.appendChild(bubble)
    messagesContainer.appendChild(messageDiv)
    
    // Animate and scroll
    requestAnimationFrame(() => {
      messageDiv.classList.add('show')
      messagesContainer.scrollTop = messagesContainer.scrollHeight
    })
  }

  addAIMessage(text) {
    this.ensureConversationContainer()
    const messagesContainer = document.getElementById('messages-container')
    
    const messageDiv = document.createElement('div')
    messageDiv.className = 'message ai-message'
    
    const bubble = document.createElement('div')
    bubble.className = 'message-bubble'
    bubble.textContent = text
    
    messageDiv.appendChild(bubble)
    messagesContainer.appendChild(messageDiv)
    
    // Animate and scroll
    requestAnimationFrame(() => {
      messageDiv.classList.add('show')
      messagesContainer.scrollTop = messagesContainer.scrollHeight
    })
  }

  clearConversation() {
    const messagesContainer = document.getElementById('messages-container')
    if (messagesContainer) {
      messagesContainer.innerHTML = ''
    }
    this.showToast('Conversation cleared', 'info', 2000)
  }

  ensureOutputsContainer() {
    if (this.elements.outputs) return
    const div = document.createElement('div')
    div.id = 'outputs'
    div.className = 'outputs'
    div.setAttribute('aria-live', 'polite')
    document.getElementById('app').appendChild(div)
    this.elements.outputs = div
  }
}

window.addEventListener('DOMContentLoaded', () => {
  new CluelyPill()
})
