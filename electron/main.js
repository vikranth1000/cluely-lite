// Import the professional app class
import { app, BrowserWindow, ipcMain } from 'electron'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Window defaults (aligned with config.json electron section)
const WINDOW_CONFIG = {
  width: 420,
  height: 120,
  minWidth: 320,
  minHeight: 100,
  maxWidth: 800,
  maxHeight: 600,
}

// Server defaults (aligned with config.json server section)
const SERVER_CONFIG = {
  host: '127.0.0.1',
  port: 8765,
}

let mainWindow = null

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
    backgroundColor: '#00000000',
    resizable: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  })

  // Load renderer
  const rendererPath = path.join(__dirname, 'renderer', 'index.html')
  mainWindow.loadFile(rendererPath)

  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  }
}

app.whenReady().then(() => {
  createMainWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

// IPC: LLM generate -> proxy to FastAPI server
ipcMain.handle('llm:generate', async (_event, prompt) => {
  try {
    if (typeof prompt !== 'string' || prompt.trim().length === 0) {
      return { success: false, error: 'Empty prompt' }
    }

    const url = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.port}/command`
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ instruction: prompt }),
    })

    if (!response.ok) {
      const text = await response.text().catch(() => '')
      return { success: false, error: `Server error ${response.status}: ${text}` }
    }

    const data = await response.json()
    return {
      success: true,
      response: data.response,
      model: data.model_used,
      processingTime: data.processing_time,
      requestId: data.request_id,
    }
  } catch (error) {
    return { success: false, error: error?.message || 'Request failed' }
  }
})
