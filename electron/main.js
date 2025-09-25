import { app, BrowserWindow, globalShortcut, ipcMain } from 'electron'
import path from 'path'
import { fileURLToPath } from 'url'
import { spawn } from 'child_process'
import os from 'os'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

let win

function createWindow() {
  win = new BrowserWindow({
    width: 420,
    height: 120,
    frame: false,
    transparent: true,
    resizable: false,
    alwaysOnTop: true,
    titleBarStyle: 'hiddenInset',
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'))
}

app.whenReady().then(() => {
  createWindow()

  // Global shortcut: Cmd+\ to toggle
  globalShortcut.register('CommandOrControl+\\', () => {
    if (!win) return
    if (win.isVisible()) {
      win.hide()
    } else {
      win.show()
      win.focus()
    }
  })

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

// LLM: forward raw prompt to Python server
ipcMain.handle('llm:generate', async (_event, prompt) => {
  try {
    const res = await fetch('http://127.0.0.1:8765/command', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ instruction: prompt })
    })
    const data = await res.json()
    return { ok: true, text: data.response ?? '' }
  } catch (e) {
    return { ok: false, error: String(e) }
  }
})

// AX helper via Swift CLI (optional)
function axHelperPath() {
  // Prefer packaged resource
  const packaged = path.join(process.resourcesPath || __dirname, 'axhelper')
  if (process.platform === 'darwin') {
    try { require('fs').accessSync(packaged); return packaged } catch {}
  }
  // Fallback to repo build
  return path.join(__dirname, '..', 'axhelper', '.build', 'release', 'axhelper')
}

function runAxHelper(args) {
  return new Promise((resolve) => {
    const exe = axHelperPath()
    const p = spawn(exe, args, { stdio: ['ignore', 'pipe', 'pipe'] })
    let out = ''
    let err = ''
    p.stdout.on('data', (d) => (out += d.toString()))
    p.stderr.on('data', (d) => (err += d.toString()))
    p.on('close', (code) => resolve({ code, out, err }))
  })
}

ipcMain.handle('ax:snapshot', async () => {
  const r = await runAxHelper(['snapshot'])
  if (r.code === 0) return { ok: true, json: safeParse(r.out) }
  return { ok: false, error: r.err || r.out }
})

ipcMain.handle('ax:click', async (_e, target) => {
  const r = await runAxHelper(['click', target])
  return { ok: r.code === 0, out: r.out, err: r.err }
})

ipcMain.handle('ax:type', async (_e, text, target) => {
  const r = await runAxHelper(['type', text, target])
  return { ok: r.code === 0, out: r.out, err: r.err }
})

ipcMain.handle('ax:focus', async (_e, target) => {
  const r = await runAxHelper(['focus', target])
  return { ok: r.code === 0, out: r.out, err: r.err }
})

function safeParse(s) {
  try { return JSON.parse(s) } catch { return null }
}

// no explicit expand/collapse IPC in this version
