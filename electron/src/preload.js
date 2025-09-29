/**
 * Preload script for Cluely-Lite
 * Exposes secure APIs to the renderer process
 */
const { contextBridge, ipcRenderer } = require('electron')

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('cluely', {
  // LLM API
  generate: (prompt) => ipcRenderer.invoke('llm:generate', prompt),
  
  // AX Helper API
  ax: {
    snapshot: () => ipcRenderer.invoke('ax:snapshot'),
    click: (target) => ipcRenderer.invoke('ax:click', target),
    type: (text, target) => ipcRenderer.invoke('ax:type', text, target),
    focus: (target) => ipcRenderer.invoke('ax:focus', target),
  },
  
  // App Control API
  app: {
    quit: () => ipcRenderer.invoke('app:quit'),
    minimize: () => ipcRenderer.invoke('app:minimize'),
    maximize: () => ipcRenderer.invoke('app:maximize'),
  },
  
  // Utility functions
  utils: {
    formatTime: (seconds) => {
      if (seconds < 60) return `${seconds.toFixed(1)}s`
      const minutes = Math.floor(seconds / 60)
      const remainingSeconds = seconds % 60
      return `${minutes}m ${remainingSeconds.toFixed(1)}s`
    },
    
    formatBytes: (bytes) => {
      if (bytes === 0) return '0 Bytes'
      const k = 1024
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    },
    
    debounce: (func, wait) => {
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
})

// Expose version info
contextBridge.exposeInMainWorld('appInfo', {
  version: '2.0.0',
  platform: process.platform,
  arch: process.arch
})
