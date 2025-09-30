const { contextBridge, ipcRenderer } = require('electron')

const utils = {
  formatTime(seconds) {
    if (typeof seconds !== 'number' || Number.isNaN(seconds)) return ''
    return `${seconds.toFixed(2)}s`
  },
}

contextBridge.exposeInMainWorld('cluely', {
  generate: (prompt) => ipcRenderer.invoke('llm:generate', prompt),
  probe: () => ipcRenderer.invoke('llm:probe'),
  setPassive: (on) => ipcRenderer.invoke('ui:set-passive', on),
  setIncognito: (on) => ipcRenderer.invoke('app:set-incognito', on),
  toggleVisibility: () => ipcRenderer.invoke('app:toggle-visibility'),
  utils,
})

console.log('Preload script loaded - cluely bridge exposed')