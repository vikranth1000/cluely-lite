class CluelyPill {
  constructor() {
    this.state = {
      isProcessing: false,
      incognito: false,
      isListening: false,
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
      this.addOutputTab(text || '(empty response)')
      this.elements.prompt.value = ''
    } catch (error) {
      console.error('Generation failed:', error)
      const errorMsg = error?.message || 'Generation failed'
      this.addOutputTab(`Error: ${errorMsg}`)
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

  addOutputTab(content) {
    this.ensureOutputsContainer()
    const tab = document.createElement('div')
    tab.className = 'output-tab'
    const close = document.createElement('button')
    close.className = 'close-btn'
    close.setAttribute('aria-label', 'Close output')
    close.textContent = '×'
    close.addEventListener('click', () => {
      tab.classList.remove('show')
      setTimeout(() => tab.remove(), 250)
    })

    const pre = document.createElement('pre')
    pre.textContent = content

    tab.appendChild(close)
    tab.appendChild(pre)
    this.elements.outputs.appendChild(tab)

    // Animate entry like toast
    requestAnimationFrame(() => {
      requestAnimationFrame(() => tab.classList.add('show'))
    })
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
