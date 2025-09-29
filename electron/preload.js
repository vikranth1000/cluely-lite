import { contextBridge, ipcRenderer } from 'electron'

const utils = {
  formatTime(seconds) {
    if (typeof seconds !== 'number' || Number.isNaN(seconds)) return ''
    return `${seconds.toFixed(2)}s`
  },
}

contextBridge.exposeInMainWorld('cluely', {
  generate: (prompt) => ipcRenderer.invoke('llm:generate', prompt),
  // Stubbed AX API to keep UI intact; no-ops in local-only stack
  ax: {
    async snapshot() {
      return { success: false, error: 'AX helper not available in local-only stack' }
    },
    async click() {
      return { success: false, error: 'AX helper not available in local-only stack' }
    },
    async type() {
      return { success: false, error: 'AX helper not available in local-only stack' }
    },
    async focus() {
      return { success: false, error: 'AX helper not available in local-only stack' }
    },
  },
  utils,
})
