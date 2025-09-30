import electron from 'electron'
const { app, BrowserWindow, ipcMain, globalShortcut, screen } = electron
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import fetch from 'node-fetch'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const WINDOW_CONFIG = {
  width: 560,
  height: 400,
  minWidth: 420,
  minHeight: 120,
  maxWidth: 900,
  maxHeight: 800,
}

const OLLAMA_CONFIG = {
  url: process.env.CLUELY_OLLAMA_URL || 'http://127.0.0.1:11434/api/generate',
  model: process.env.CLUELY_OLLAMA_MODEL || 'qwen2.5:3b',
  options: {
    temperature: Number(process.env.CLUELY_OLLAMA_TEMPERATURE || 0.7),
    top_p: Number(process.env.CLUELY_OLLAMA_TOP_P || 0.9),
    max_tokens: Number(process.env.CLUELY_OLLAMA_MAX_TOKENS || 512),
  },
}

const SERVER_CONFIG = {
  url: process.env.CLUELY_SERVER_URL || 'http://127.0.0.1:8765',
}

let mainWindow = null
let passiveMode = false
let incognitoMode = false

function applyOverlaySettings(win) {
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true, skipTransformProcessType: true })
  // Use highest reasonable level to remain above normal apps
  win.setAlwaysOnTop(true, 'screen-saver')
  win.setFullScreenable(false)
  win.setSkipTaskbar(true)
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: WINDOW_CONFIG.width,
    height: WINDOW_CONFIG.height,
    minWidth: WINDOW_CONFIG.minWidth,
    minHeight: WINDOW_CONFIG.minHeight,
    maxWidth: WINDOW_CONFIG.maxWidth,
    maxHeight: WINDOW_CONFIG.maxHeight,
    frame: false,
    transparent: true,
    hasShadow: false,
    backgroundColor: '#00000000',
    resizable: true,
    focusable: true,
    roundedCorners: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  })

  applyOverlaySettings(mainWindow)

  const rendererPath = path.join(__dirname, 'renderer', 'index.html')
  mainWindow.loadFile(rendererPath)

  try {
    const display = screen.getPrimaryDisplay()
    const work = display.workArea
    const x = Math.round(work.x + (work.width - WINDOW_CONFIG.width) / 2)
    const y = Math.max(work.y + 24, 16)
    mainWindow.setPosition(x, y)
  } catch (error) {
    console.warn('Could not position window:', error)
  }

  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  }

  setPassiveMode(false)
  applyIncognito(false)
  mainWindow.showInactive()
}

function setPassiveMode(on) {
  passiveMode = !!on
  if (!mainWindow) return
  mainWindow.setIgnoreMouseEvents(!!on)
}

function applyIncognito(on) {
  incognitoMode = !!on
  if (!mainWindow) return

  try {
    if (process.platform === 'darwin') {
      if (incognitoMode) {
        app.dock.hide()
      } else {
        app.dock.show()
      }
    } else {
      mainWindow.setSkipTaskbar(incognitoMode)
    }
    applyOverlaySettings(mainWindow)
  } catch (error) {
    console.warn('Incognito toggle failed:', error)
  }
}

async function generateWithOllama(prompt) {
  // Directly call Ollama for fastest turnaround
  const payload = {
    model: OLLAMA_CONFIG.model,
    prompt,
    stream: false,
    options: OLLAMA_CONFIG.options,
  }

  try {
    const controller = new AbortController()
    const to = setTimeout(() => controller.abort(), 15000)
    const response = await fetch(OLLAMA_CONFIG.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    })
    clearTimeout(to)

    if (!response.ok) {
      const text = await response.text().catch(() => '')
      // Fallback to server if available
      const fallback = await generateViaServer(prompt).catch(() => null)
      if (fallback) return fallback
      return { success: false, error: `Ollama error ${response.status}: ${text}` }
    }

    const data = await response.json()
    const text = data?.response || data?.message || ''
    return { success: true, response: text, raw: data }
  } catch (error) {
    const fallback = await generateViaServer(prompt).catch(() => null)
    if (fallback) return fallback
    return { success: false, error: error?.message || 'Request failed' }
  }
}

async function generateViaServer(prompt) {
  try {
    const controller = new AbortController()
    const to = setTimeout(() => controller.abort(), 12000)
    const response = await fetch(`${SERVER_CONFIG.url}/command`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ instruction: prompt }),
      signal: controller.signal,
    })
    clearTimeout(to)
    if (!response.ok) {
      const text = await response.text().catch(() => '')
      return { success: false, error: `Server error ${response.status}: ${text}` }
    }
    const data = await response.json()
    return { success: true, response: data?.response || '' }
  } catch (e) {
    return null
  }
}

async function probeOllama() {
  try {
    const controller = new AbortController()
    const to = setTimeout(() => controller.abort(), 4000)
    const url = OLLAMA_CONFIG.url.replace('/api/generate', '/api/tags')
    const res = await fetch(url, { method: 'GET', signal: controller.signal })
    clearTimeout(to)
    return { ok: res.ok }
  } catch (e) {
    return { ok: false, error: e?.message || 'Probe failed' }
  }
}

ipcMain.handle('llm:probe', async () => {
  return probeOllama()
})

app.whenReady().then(() => {
  createMainWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow()
    }
  })

  const registered = globalShortcut.register('CommandOrControl+\\', () => {
    if (!mainWindow) return
    if (mainWindow.isVisible()) {
      mainWindow.hide()
    } else {
      mainWindow.showInactive()
      applyOverlaySettings(mainWindow)
      setPassiveMode(false)
    }
  })

  if (!registered) {
    console.warn('Failed to register Cmd+\\ shortcut')
  }
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('will-quit', () => {
  globalShortcut.unregisterAll()
})

ipcMain.handle('llm:generate', async (_event, prompt) => {
  if (typeof prompt !== 'string' || !prompt.trim()) {
    return { success: false, error: 'Prompt must be a non-empty string' }
  }
  return generateWithOllama(prompt.trim())
})

ipcMain.handle('ui:set-passive', async (_event, on) => {
  setPassiveMode(false)
  return { success: true, passive: false }
})

ipcMain.handle('app:set-incognito', async (_event, on) => {
  applyIncognito(on)
  return { success: true, incognito: incognitoMode }
})

ipcMain.handle('app:toggle-visibility', () => {
  if (!mainWindow) return { success: false }
  if (mainWindow.isVisible()) {
    mainWindow.hide()
  } else {
    mainWindow.showInactive()
    applyOverlaySettings(mainWindow)
    setPassiveMode(false)
  }
  return { success: true, visible: mainWindow.isVisible() }
})
