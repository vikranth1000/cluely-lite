/**
 * Cluely-Lite Electron App
 * Professional desktop automation assistant
 */
import { app, BrowserWindow, globalShortcut, ipcMain, nativeImage, dialog } from 'electron'
import path from 'path'
import { fileURLToPath } from 'url'
import { spawn } from 'child_process'
import os from 'os'
import fs from 'fs'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

class CluelyApp {
  constructor() {
    this.mainWindow = null
    this.isQuitting = false
    this.config = this.loadConfig()
  }

  loadConfig() {
    const configPath = path.join(__dirname, '..', '..', 'config.json')
    try {
      if (fs.existsSync(configPath)) {
        return JSON.parse(fs.readFileSync(configPath, 'utf8'))
      }
    } catch (error) {
      console.warn('Failed to load config:', error.message)
    }
    return {
      electron: {
        width: 420,
        height: 120,
        minWidth: 320,
        minHeight: 100,
        maxWidth: 800,
        maxHeight: 600
      }
    }
  }

  async initialize() {
    // Ensure single instance
    const gotLock = app.requestSingleInstanceLock()
    if (!gotLock) {
      app.quit()
      return
    }

    app.on('second-instance', () => {
      if (this.mainWindow) {
        if (this.mainWindow.isMinimized()) this.mainWindow.restore()
        this.mainWindow.show()
        this.mainWindow.focus()
      }
    })

    // App event handlers
    app.whenReady().then(() => this.onReady())
    app.on('window-all-closed', () => this.onWindowAllClosed())
    app.on('activate', () => this.onActivate())
    app.on('before-quit', () => this.onBeforeQuit())

    // Setup IPC handlers
    this.setupIpcHandlers()
  }

  async onReady() {
    try {
      // Set app icon
      await this.setAppIcon()
      
      // Create main window
      this.createMainWindow()
      
      // Register global shortcuts
      this.registerGlobalShortcuts()
      
      console.log('✅ Cluely-Lite initialized successfully')
    } catch (error) {
      console.error('❌ Failed to initialize app:', error)
      app.quit()
    }
  }

  async setAppIcon() {
    if (process.platform === 'darwin') {
      try {
        const iconPath = path.join(__dirname, '..', 'build', 'icon.png')
        if (fs.existsSync(iconPath)) {
          const icon = nativeImage.createFromPath(iconPath)
          if (!icon.isEmpty()) {
            app.dock.setIcon(icon)
          }
        }
      } catch (error) {
        console.warn('Failed to set app icon:', error.message)
      }
    }
  }

  createMainWindow() {
    const { electron: config } = this.config
    
    this.mainWindow = new BrowserWindow({
      width: config.width,
      height: config.height,
      minWidth: config.minWidth,
      minHeight: config.minHeight,
      maxWidth: config.maxWidth,
      maxHeight: config.maxHeight,
      frame: false,
      transparent: true,
      resizable: true,
      alwaysOnTop: true,
      titleBarStyle: 'hiddenInset',
      hasShadow: false,
      webPreferences: {
        preload: path.join(__dirname, 'preload.js'),
        nodeIntegration: false,
        contextIsolation: true,
        enableRemoteModule: false,
        webSecurity: true
      }
    })

    // Set window properties
    this.mainWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })
    
    // Load the UI
    this.mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'))

    // Event handlers
    this.mainWindow.on('closed', () => {
      this.mainWindow = null
    })

    this.mainWindow.on('unresponsive', () => {
      console.error('Window became unresponsive')
      dialog.showErrorBox('App Unresponsive', 'The app has become unresponsive. Please restart.')
    })

    this.mainWindow.webContents.on('render-process-gone', (event, details) => {
      console.error('Renderer process gone:', details)
      dialog.showErrorBox('Renderer Crashed', 'The renderer process has crashed. Please restart the app.')
    })

    // Development tools
    if (process.env.NODE_ENV === 'development') {
      this.mainWindow.webContents.openDevTools()
    }
  }

  registerGlobalShortcuts() {
    try {
      // Register Cmd+\ shortcut
      const success = globalShortcut.register('CommandOrControl+\\', () => {
        this.toggleWindow()
      })

      if (!success) {
        console.error('Failed to register global shortcut CommandOrControl+\\')
      } else {
        console.log('✅ Global shortcut registered: Cmd+\\')
      }
    } catch (error) {
      console.error('Error registering global shortcut:', error)
    }
  }

  toggleWindow() {
    if (!this.mainWindow) return

    if (this.mainWindow.isVisible()) {
      this.mainWindow.hide()
    } else {
      this.mainWindow.show()
      this.mainWindow.focus()
    }
  }

  onWindowAllClosed() {
    if (process.platform !== 'darwin') {
      app.quit()
    }
  }

  onActivate() {
    if (BrowserWindow.getAllWindows().length === 0) {
      this.createMainWindow()
    }
  }

  onBeforeQuit() {
    this.isQuitting = true
  }

  setupIpcHandlers() {
    // LLM generation
    ipcMain.handle('llm:generate', async (event, prompt) => {
      try {
        const response = await fetch('http://127.0.0.1:8765/command', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ instruction: prompt })
        })
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        const data = await response.json()
        return { 
          success: true, 
          response: data.response || '',
          model: data.model_used || 'unknown',
          processingTime: data.processing_time || 0
        }
      } catch (error) {
        console.error('LLM generation error:', error)
        return { 
          success: false, 
          error: error.message || 'Unknown error occurred'
        }
      }
    })

    // AX helper functions
    ipcMain.handle('ax:snapshot', async () => {
      try {
        const result = await this.runAxHelper(['snapshot'])
        if (result.code === 0) {
          return { success: true, data: this.safeParse(result.out) }
        }
        return { success: false, error: result.err || result.out || 'Unknown error' }
      } catch (error) {
        return { success: false, error: error.message }
      }
    })

    ipcMain.handle('ax:click', async (event, target) => {
      try {
        const result = await this.runAxHelper(['click', target])
        return { 
          success: result.code === 0, 
          output: result.out, 
          error: result.err 
        }
      } catch (error) {
        return { success: false, error: error.message }
      }
    })

    ipcMain.handle('ax:type', async (event, text, target) => {
      try {
        const result = await this.runAxHelper(['type', text, target])
        return { 
          success: result.code === 0, 
          output: result.out, 
          error: result.err 
        }
      } catch (error) {
        return { success: false, error: error.message }
      }
    })

    ipcMain.handle('ax:focus', async (event, target) => {
      try {
        const result = await this.runAxHelper(['focus', target])
        return { 
          success: result.code === 0, 
          output: result.out, 
          error: result.err 
        }
      } catch (error) {
        return { success: false, error: error.message }
      }
    })

    // App control
    ipcMain.handle('app:quit', () => {
      app.quit()
    })

    ipcMain.handle('app:minimize', () => {
      if (this.mainWindow) {
        this.mainWindow.minimize()
      }
    })

    ipcMain.handle('app:maximize', () => {
      if (this.mainWindow) {
        if (this.mainWindow.isMaximized()) {
          this.mainWindow.unmaximize()
        } else {
          this.mainWindow.maximize()
        }
      }
    })
  }

  getAxHelperPath() {
    // Prefer packaged resource
    const packaged = path.join(process.resourcesPath || __dirname, 'axhelper')
    if (process.platform === 'darwin' && fs.existsSync(packaged)) {
      return packaged
    }
    
    // Fallback to repo build
    return path.join(__dirname, '..', '..', 'axhelper', '.build', 'release', 'axhelper')
  }

  runAxHelper(args) {
    return new Promise((resolve) => {
      const exe = this.getAxHelperPath()
      
      if (!fs.existsSync(exe)) {
        resolve({ code: 1, out: '', err: 'AX helper not found. Please build it first.' })
        return
      }

      const process = spawn(exe, args, { 
        stdio: ['ignore', 'pipe', 'pipe'],
        timeout: 10000 // 10 second timeout
      })
      
      let out = ''
      let err = ''
      
      process.stdout.on('data', (data) => {
        out += data.toString()
      })
      
      process.stderr.on('data', (data) => {
        err += data.toString()
      })
      
      process.on('close', (code) => {
        resolve({ code, out, err })
      })
      
      process.on('error', (error) => {
        resolve({ code: 1, out: '', err: error.message })
      })
    })
  }

  safeParse(str) {
    try {
      return JSON.parse(str)
    } catch {
      return null
    }
  }
}

// Create and initialize app
const cluelyApp = new CluelyApp()
cluelyApp.initialize().catch(console.error)
