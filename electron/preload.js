const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('cluely', {
  generate: (prompt) => ipcRenderer.invoke('llm:generate', prompt),
  ax: {
    snapshot: () => ipcRenderer.invoke('ax:snapshot'),
    click: (target) => ipcRenderer.invoke('ax:click', target),
    type: (text, target) => ipcRenderer.invoke('ax:type', text, target),
    focus: (target) => ipcRenderer.invoke('ax:focus', target),
  },
  resize: (w, h) => ipcRenderer.send('ui:resize', { w, h })
})
